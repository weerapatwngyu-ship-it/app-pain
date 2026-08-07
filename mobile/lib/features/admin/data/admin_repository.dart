import '../../../core/supabase/supabase_refs.dart';

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

  factory AccountSummary.fromRow(Map<String, dynamic> row) {
    // A one-element list because doctors.user_id is unique, so at most one
    // listing can point at this account.
    final doctors = (row['doctors'] as List<dynamic>?) ?? const [];
    final doctor = doctors.isEmpty ? null : doctors.first as Map<String, dynamic>;
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
  Future<List<AccountSummary>> accounts() async {
    final rows = await db
        .from('profiles')
        .select('id, name, email, role, doctors(id, name)')
        .order('created_at', ascending: false);
    return rows.map<AccountSummary>(AccountSummary.fromRow).toList();
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
    await db.from('profiles').update({'role': 'provider'}).eq('id', userId);
  }

  /// Withdraw approval. Deleting the listing cascades its conversations away,
  /// so this is a real revocation rather than hiding the doctor.
  Future<void> revokeDoctor({required String userId, required String doctorId}) async {
    await db.from('doctors').delete().eq('id', doctorId);
    await db.from('profiles').update({'role': 'patient'}).eq('id', userId);
  }
}
