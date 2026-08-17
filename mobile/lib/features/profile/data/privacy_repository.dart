import '../../../core/supabase/supabase_refs.dart';

/// Someone who can currently read a patient's record.
class AccessGrant {
  const AccessGrant({
    required this.linkId,
    required this.userId,
    required this.role,
    required this.status,
    required this.grantedAt,
    this.name,
    this.specialty,
  });

  final String linkId;
  final String userId;

  /// 'provider' or 'caregiver'.
  final String role;

  /// 'active', 'pending' or 'revoked'.
  final String status;

  final DateTime grantedAt;

  /// From the doctors directory. Null for an account with no listing — a
  /// caregiver, say — since `profiles` is readable only by its owner and the
  /// patient genuinely cannot be shown a name that is not theirs to see.
  final String? name;
  final String? specialty;

  bool get isActive => status == 'active';
  bool get isProvider => role == 'provider';
}

/// The patient's own view of who holds access to their record, and the one
/// place that takes it away.
///
/// Every call here is scoped by RLS to the caller's own patient row — the
/// policies do the enforcing, not this class. `patient_links_write_owner`
/// lets the owner of a patient record change its links, which is exactly what
/// makes revoking possible from the app at all.
class PrivacyRepository {
  /// Who can read this record, most recently granted first.
  Future<List<AccessGrant>> accessList(String patientId) async {
    final links = await db
        .from('patient_links')
        .select('id, user_id, role, status, created_at')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);

    if (links.isEmpty) return const [];

    // Names come from the doctors directory, which every signed-in account may
    // read. Two queries rather than a join: patient_links.user_id and
    // doctors.user_id both point at auth.users, and PostgREST cannot infer a
    // relationship between two tables that only share a target.
    final ids = links.map((row) => row['user_id'] as String).toList();
    final doctors = await db
        .from('doctors')
        .select('user_id, name, specialty')
        .inFilter('user_id', ids);

    final byUser = <String, Map<String, dynamic>>{
      for (final row in doctors) row['user_id'] as String: row,
    };

    return links.map<AccessGrant>((row) {
      final doctor = byUser[row['user_id']];
      return AccessGrant(
        linkId: row['id'] as String,
        userId: row['user_id'] as String,
        role: row['role'] as String? ?? 'caregiver',
        status: row['status'] as String? ?? 'pending',
        grantedAt: DateTime.parse(row['created_at'] as String).toLocal(),
        name: doctor?['name'] as String?,
        specialty: doctor?['specialty'] as String?,
      );
    }).toList();
  }

  /// Withdraws access without deleting the record of it having existed.
  ///
  /// Revoked rather than removed on purpose: the row is the audit trail of who
  /// could see the record and when, and a deleted row cannot answer that
  /// later. It also keeps the unique (patient_id, user_id) slot filled, so a
  /// doctor cannot get access back by a route that inserts a fresh link.
  Future<void> revoke(String linkId) async {
    final updated = await db
        .from('patient_links')
        .update({'status': 'revoked'})
        .eq('id', linkId)
        .select();
    if (updated.isEmpty) {
      throw StateError('เพิกถอนสิทธิ์ไม่สำเร็จ');
    }
  }

  /// Gives access back, for a patient who changes their mind.
  Future<void> restore(String linkId) async {
    final updated = await db
        .from('patient_links')
        .update({'status': 'active'})
        .eq('id', linkId)
        .select();
    if (updated.isEmpty) {
      throw StateError('คืนสิทธิ์ไม่สำเร็จ');
    }
  }
}
