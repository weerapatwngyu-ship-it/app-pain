import 'dart:typed_data';

import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/doctor.dart';

class DoctorRepository {
  Future<List<Doctor>> fetchAll() async {
    final rows = await db.from('doctors').select().order('created_at', ascending: false);
    return rows.map<Doctor>(Doctor.fromRow).toList();
  }

  /// How many patients have consulted a doctor.
  ///
  /// Read through a database function rather than counting rows here: the
  /// conversations behind the number are readable only by the people in them,
  /// which is exactly right, and would make a client-side count return the
  /// caller's own threads instead of the doctor's total.
  Future<int> consultCount(String doctorId) async {
    final value = await db.rpc(
      'doctor_consult_count',
      params: {'target_doctor_id': doctorId},
    );
    return (value as num?)?.toInt() ?? 0;
  }

  Future<Doctor> fetchOne(String id) async {
    final row = await db.from('doctors').select().eq('id', id).single();
    return Doctor.fromRow(row);
  }

  /// The listing the signed-in account is the doctor for, or null when the
  /// account is not a doctor. This — not profiles.role — is what decides
  /// whether the app can show a doctor their threads, since the threads hang
  /// off the listing.
  Future<Doctor?> fetchForCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await db.from('doctors').select().eq('user_id', userId).maybeSingle();
    return row == null ? null : Doctor.fromRow(row);
  }

  /// Admin-only (RLS enforces it): publish a doctor, optionally tied to the
  /// account that will sign in as them.
  Future<Doctor> create({
    required String name,
    required String specialty,
    String? bio,
    String? userId,
  }) async {
    final row = await db
        .from('doctors')
        .insert({
          'name': name,
          'specialty': specialty,
          if (bio != null && bio.isNotEmpty) 'bio': bio,
          if (userId != null) 'user_id': userId,
        })
        .select()
        .single();
    return Doctor.fromRow(row);
  }

  /// Admin-only: revoke a listing. Conversations cascade with it, so this is
  /// removal rather than deactivation.
  Future<void> delete(String id) async {
    await db.from('doctors').delete().eq('id', id);
  }

  Future<Doctor> update(
    String id, {
    required String name,
    required String specialty,
    String? bio,
  }) async {
    final row = await db
        .from('doctors')
        .update({'name': name, 'specialty': specialty, 'bio': bio})
        .eq('id', id)
        .select()
        .single();
    return Doctor.fromRow(row);
  }

  Future<Doctor> uploadPhoto(
    String id, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    // Storage policy scopes writes to a folder named for the uploader.
    final path = '$userId/doctor-$id-${DateTime.now().millisecondsSinceEpoch}-$fileName';
    final bytes = fileBytes is Uint8List ? fileBytes : Uint8List.fromList(fileBytes);
    await db.storage.from(avatarsBucket).uploadBinary(path, bytes);
    final publicUrl = db.storage.from(avatarsBucket).getPublicUrl(path);

    final row = await db
        .from('doctors')
        .update({'photo_url': publicUrl})
        .eq('id', id)
        .select()
        .single();
    return Doctor.fromRow(row);
  }
}
