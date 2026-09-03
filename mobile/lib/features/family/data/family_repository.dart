import '../../../core/i18n/app_locale.dart';
import '../../../core/supabase/supabase_refs.dart';

/// Someone who has asked for, or holds, access to the signed-in patient's
/// own record.
class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.name,
    required this.status,
    this.email,
    this.requestedAt,
  });

  final String userId;
  final String name;
  final String? email;

  /// 'pending' | 'active'. Revoked links are not returned at all — a list of
  /// people who used to have access is a different question from who has it.
  final String status;

  final DateTime? requestedAt;

  bool get isPending => status == 'pending';

  factory FamilyMember.fromRow(Map<String, dynamic> row) => FamilyMember(
        userId: row['user_id'] as String,
        name: (row['name'] as String? ?? '').trim().isEmpty
            ? t('สมาชิกครอบครัว', 'Family member')
            : row['name'] as String,
        email: row['email'] as String?,
        status: row['status'] as String? ?? 'pending',
        requestedAt: row['requested_at'] == null
            ? null
            : DateTime.parse(row['requested_at'] as String).toLocal(),
      );
}

/// A record the signed-in user may look after, because a patient approved
/// them.
class FamilyPatient {
  const FamilyPatient({
    required this.patientId,
    required this.name,
    required this.status,
  });

  final String patientId;
  final String name;
  final String status;

  bool get isPending => status == 'pending';

  factory FamilyPatient.fromRow(Map<String, dynamic> row) => FamilyPatient(
        patientId: row['patient_id'] as String,
        name: row['name'] as String? ?? '',
        status: row['status'] as String? ?? 'pending',
      );
}

/// What happened when a code was entered.
enum JoinFamilyResult { pending, alreadyActive, ownCode, notFound }

/// Family access: one code per patient, and the links it produces.
///
/// Every call here is an RPC rather than a table read or write. `patient_links`
/// accepts writes only from the record's owner, and the person entering a code
/// is by definition not them — so joining has to go through a definer function.
/// The listing calls go the same way for a different reason: naming a member
/// means reading their `profiles` row, which is readable only by its own owner.
class FamilyRepository {
  /// The caller's own code, created on first use.
  Future<String> myCode() async {
    final code = await db.rpc('my_family_code');
    return code as String;
  }

  /// People who asked for or hold access to the caller's record.
  Future<List<FamilyMember>> members() async {
    final rows = await db.rpc('family_members') as List<dynamic>;
    return rows
        .map((row) => FamilyMember.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Records the caller may look after.
  Future<List<FamilyPatient>> patientsICareFor() async {
    final rows = await db.rpc('my_family_patients') as List<dynamic>;
    return rows
        .map((row) => FamilyPatient.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Asks to join the family behind [code]. Approval is still the patient's.
  Future<JoinFamilyResult> requestAccess(String code) async {
    final result = await db.rpc('request_family_access', params: {'code': code});
    return switch (result as String?) {
      'pending' => JoinFamilyResult.pending,
      'already_active' => JoinFamilyResult.alreadyActive,
      'own_code' => JoinFamilyResult.ownCode,
      _ => JoinFamilyResult.notFound,
    };
  }

  Future<void> approve(String userId) => _setStatus(userId, 'active');

  /// Removing access rather than deleting the row, so the same person can be
  /// approved again later without the patient hunting for their code.
  Future<void> revoke(String userId) => _setStatus(userId, 'revoked');

  Future<void> _setStatus(String userId, String status) async {
    final ok = await db.rpc('set_family_member_status',
        params: {'member': userId, 'new_status': status});
    if (ok != true) {
      throw StateError(t(
        'ทำรายการไม่สำเร็จ — ไม่มีสิทธิ์แก้สมาชิกคนนี้',
        'That did not work — you do not have permission to change this member',
      ));
    }
  }

  /// Lets a family member step away without asking the patient to do it.
  Future<void> leave(String patientId) async {
    await db.rpc('leave_family', params: {'target_patient': patientId});
  }
}
