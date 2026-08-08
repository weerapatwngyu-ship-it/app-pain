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
}
