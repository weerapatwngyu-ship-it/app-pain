import 'dart:typed_data';

import '../../../core/supabase/supabase_refs.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/user.dart';

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<AppUser> fetchCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    // A database trigger creates both rows at sign-up, so a missing profile
    // here means the schema was never applied to this project.
    final profile = await db.from('profiles').select().eq('id', userId).maybeSingle();
    if (profile == null) {
      throw StateError(
        'ไม่พบโปรไฟล์ผู้ใช้ — ตรวจสอบว่ารัน supabase/schema.sql ใน Supabase แล้ว',
      );
    }

    final patient =
        await db.from('patients').select('id').eq('owner_user_id', userId).maybeSingle();

    return AppUser.fromProfile(profile, patientId: patient?['id'] as String?);
  }

  @override
  Future<AppUser> updateProfile({String? name, String? email}) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    await db.from('profiles').update({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    }).eq('id', userId);

    return fetchCurrentUser();
  }

  @override
  Future<AppUser> uploadAvatar({required List<int> fileBytes, required String fileName}) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('ยังไม่ได้เข้าสู่ระบบ');

    // Storage policy only permits writes inside a folder named for the
    // user's own id, so the path prefix is load-bearing.
    final path = '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}-$fileName';
    await db.storage.from(avatarsBucket).uploadBinary(path, _asBytes(fileBytes));
    final publicUrl = db.storage.from(avatarsBucket).getPublicUrl(path);

    await db.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
    return fetchCurrentUser();
  }
}

Uint8List _asBytes(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
