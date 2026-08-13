import '../../../core/supabase/supabase_refs.dart';
import '../../doctors/domain/entities/doctor.dart';

/// One account as an admin sees it while deciding who to approve as a doctor.
class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.doctorId,
    this.doctorName,
  });

  final String id;
  final String name;
  final String email;
  final String role;

  /// Set when this account already has a doctor listing attached.
  final String? doctorId;
  final String? doctorName;

  bool get isDoctor => doctorId != null;

  /// Linked to a listing but still not a provider — the state that leaves a
  /// doctor stuck in the patient shell, unable to reach their inbox.
  bool get roleNeedsRepair => isDoctor && role != 'provider';

  factory AccountSummary.fromRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? doctor,
  }) {
    return AccountSummary(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      email: row['email'] as String? ?? '',
      role: row['role'] as String? ?? 'patient',
      doctorId: doctor?['id'] as String?,
      doctorName: doctor?['name'] as String?,
    );
  }
}

/// Everything here depends on the caller being an admin — RLS enforces it, so
/// a non-admin sees an empty list rather than an error.
class AdminRepository {
  /// Two queries joined in Dart rather than one embedded select: PostgREST can
  /// only embed across a foreign key it can see, and doctors.user_id points at
  /// auth.users, not public.profiles — asking for `profiles(..., doctors(...))`
  /// fails with PGRST200 "could not find a relationship".
  Future<List<AccountSummary>> accounts() async {
    final profiles = await db
        .from('profiles')
        .select('id, name, email, role')
        .order('created_at', ascending: false);

    final doctors = await db.from('doctors').select('id, name, user_id');
    final byUser = <String, Map<String, dynamic>>{
      for (final d in doctors)
        if (d['user_id'] != null) d['user_id'] as String: d,
    };

    return profiles
        .map<AccountSummary>(
          (row) => AccountSummary.fromRow(row, doctor: byUser[row['id'] as String]),
        )
        .toList();
  }

  /// Every listing, including ones with no account behind them yet.
  Future<List<Doctor>> doctors() async {
    final rows = await db.from('doctors').select().order('name');
    return rows.map<Doctor>(Doctor.fromRow).toList();
  }

  /// Writes an account's role and proves the write landed.
  ///
  /// PostgREST reports no error for an UPDATE that matches nothing, so a plain
  /// `.update(...).eq(...)` here looked successful even when RLS refused it.
  /// That is exactly how a doctor could end up published and linked while
  /// still carrying role 'patient': the app then routed them to the patient
  /// shell and their inbox was unreachable, with nothing anywhere reporting a
  /// failure. Selecting the affected rows back turns that silence into an
  /// error the admin can actually see.
  Future<void> _setRole({required String userId, required String role}) async {
    final updated = await db
        .from('profiles')
        .update({'role': role})
        .eq('id', userId)
        .select('id');
    if (updated.isEmpty) {
      throw StateError(
        'เปลี่ยนสิทธิ์บัญชีไม่สำเร็จ — ตรวจสอบว่าคุณเข้าสู่ระบบด้วยบัญชีผู้ดูแล '
        'และรัน supabase/schema.sql เวอร์ชันล่าสุดแล้ว',
      );
    }
  }

  /// Re-applies the provider role to an account that already has a listing.
  /// Fixes doctors linked before the admin UPDATE policy existed, whose role
  /// write was silently dropped at the time.
  Future<void> repairDoctorRole({required String userId}) =>
      _setRole(userId: userId, role: 'provider');

  /// Publish a doctor without waiting for them to sign up. They appear to
  /// patients straight away; until an account is linked nobody can read the
  /// messages patients send, which is why the UI says so.
  Future<void> createDoctor({
    required String name,
    required String specialty,
    String? bio,
    String? userId,
    String? credential,
    String? workplace,
    List<String> languages = const [],
    List<String> conditions = const [],
    double? consultFee,
    int? consultMinutes,
  }) async {
    // Blank optional details are left out of the insert rather than written as
    // empty strings, so the profile can tell "not recorded" from "recorded as
    // nothing" and simply omit the line.
    await db.from('doctors').insert({
      'name': name,
      'specialty': specialty,
      if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
      if (userId != null) 'user_id': userId,
      if (credential != null) 'credential': credential,
      if (workplace != null) 'workplace': workplace,
      'languages': languages,
      'conditions': conditions,
      if (consultFee != null) 'consult_fee': consultFee,
      if (consultMinutes != null) 'consult_minutes': consultMinutes,
    });
    if (userId != null) {
      await _setRole(userId: userId, role: 'provider');
    }
  }

  /// Attach an account to a listing that was created without one, so that
  /// doctor can finally sign in and read their threads.
  Future<void> linkAccount({required String doctorId, required String userId}) async {
    await db.from('doctors').update({'user_id': userId}).eq('id', doctorId);
    await _setRole(userId: userId, role: 'provider');
  }

  Future<void> deleteDoctor({required String doctorId, String? userId}) async {
    await db.from('doctors').delete().eq('id', doctorId);
    if (userId != null) {
      await _setRole(userId: userId, role: 'patient');
    }
  }

  /// Approve an account as a doctor: give it the provider role and publish the
  /// listing patients will see and message. Both steps matter — the role
  /// decides which shell the app shows, the listing is what threads hang off.
  Future<void> approveDoctor({
    required String userId,
    required String name,
    required String specialty,
    String? bio,
  }) async {
    await db.from('doctors').insert({
      'user_id': userId,
      'name': name,
      'specialty': specialty,
      if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
    });
    await _setRole(userId: userId, role: 'provider');
  }

  /// Withdraw approval. Deleting the listing cascades its conversations away,
  /// so this is a real revocation rather than hiding the doctor.
  Future<void> revokeDoctor({required String userId, required String doctorId}) async {
    await db.from('doctors').delete().eq('id', doctorId);
    await _setRole(userId: userId, role: 'patient');
  }
}
