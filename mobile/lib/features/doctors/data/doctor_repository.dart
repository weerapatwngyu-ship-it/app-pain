import 'dart:typed_data';

import '../../../core/supabase/supabase_refs.dart';
import '../domain/entities/doctor.dart';

class DoctorRepository {
  Future<List<Doctor>> fetchAll() async {
    final rows = await db.from('doctors').select().order('created_at', ascending: false);
    return rows.map<Doctor>(Doctor.fromRow).toList();
  }

  Future<Doctor> fetchOne(String id) async {
    final row = await db.from('doctors').select().eq('id', id).single();
    return Doctor.fromRow(row);
  }

  Future<Doctor> create({required String name, required String specialty, String? bio}) async {
    final row = await db
        .from('doctors')
        .insert({
          'name': name,
          'specialty': specialty,
          if (bio != null && bio.isNotEmpty) 'bio': bio,
        })
        .select()
        .single();
    return Doctor.fromRow(row);
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
