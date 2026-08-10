import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/health_question.dart';

class HealthQuestionRepository {
  /// Every question this patient has asked, newest first. RLS already limits
  /// the rows to patients the caller may see; the filter is for shaping.
  Future<List<HealthQuestion>> fetchForPatient(String patientId) async {
    final rows = await db
        .from('health_questions')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return rows.map<HealthQuestion>(HealthQuestion.fromRow).toList();
  }

  Future<List<HealthQuestion>> fetchForTopic(String patientId, String topicKey) async {
    final rows = await db
        .from('health_questions')
        .select()
        .eq('patient_id', patientId)
        .eq('topic_key', topicKey)
        .order('created_at', ascending: false);
    return rows.map<HealthQuestion>(HealthQuestion.fromRow).toList();
  }

  Future<HealthQuestion> ask({
    required String patientId,
    required String topicKey,
    required String question,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    // status/answer are left at their defaults on purpose — the insert policy
    // rejects a row that arrives already carrying an answer.
    final row = await db
        .from('health_questions')
        .insert({
          'patient_id': patientId,
          'asked_by': userId,
          'topic_key': topicKey,
          'question': question,
        })
        .select()
        .single();
    return HealthQuestion.fromRow(row);
  }

  /// The queue a doctor works through: every question, newest first, with the
  /// asking patient's name joined in. RLS returns nothing here unless the
  /// caller holds a doctor listing, so a patient calling this still sees only
  /// their own rows.
  Future<List<QueuedQuestion>> queue({bool pendingOnly = true}) async {
    // Spelled out both ways rather than reassigning one builder: the filter
    // and transform builders are different types, so holding them in a single
    // `var` depends on inference details that shift between postgrest
    // versions.
    final rows = pendingOnly
        ? await db
            .from('health_questions')
            .select('*, patients(name)')
            .eq('status', 'pending')
            .order('created_at', ascending: false)
        : await db
            .from('health_questions')
            .select('*, patients(name)')
            .order('created_at', ascending: false);
    return rows.map<QueuedQuestion>(QueuedQuestion.fromRow).toList();
  }

  /// Posts an answer. answered_by and answered_at are deliberately not sent:
  /// a trigger stamps them from the caller's own listing, so an answer cannot
  /// be signed with someone else's name.
  Future<void> answer({required String questionId, required String answer}) async {
    final updated = await db
        .from('health_questions')
        .update({'answer': answer, 'status': 'answered'})
        .eq('id', questionId)
        .select('id');
    if (updated.isEmpty) {
      throw StateError(
        'ตอบคำถามไม่สำเร็จ — บัญชีนี้อาจไม่ได้เป็นแพทย์ในระบบ '
        'หรือยังไม่ได้รัน supabase/schema.sql เวอร์ชันล่าสุด',
      );
    }
  }
}

/// A queued question plus who asked it. Separate from [HealthQuestion] because
/// only the doctor-facing queue carries a patient name — a patient reading
/// their own questions already knows whose they are.
class QueuedQuestion {
  const QueuedQuestion({required this.question, required this.patientName});

  final HealthQuestion question;
  final String patientName;

  factory QueuedQuestion.fromRow(Map<String, dynamic> row) {
    final patient = row['patients'] as Map<String, dynamic>?;
    return QueuedQuestion(
      question: HealthQuestion.fromRow(row),
      patientName: (patient?['name'] as String?) ?? 'ผู้ป่วย',
    );
  }
}
