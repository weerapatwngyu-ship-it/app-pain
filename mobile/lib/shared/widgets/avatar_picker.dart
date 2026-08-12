import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/entities/user.dart';

/// Asks where the photo should come from, picks it, and uploads it as the
/// signed-in user's avatar.
///
/// Shared rather than written per screen: this is offered from the home
/// screen, the profile and the after-sign-up form, and a copy in each is three
/// places for the size limit or the error handling to drift apart.
///
/// Returns the updated user, or null when the user backed out at any step or
/// the upload failed — in which case the message has already been shown.
Future<AppUser?> pickAndUploadAvatar({
  required BuildContext context,
  required AuthRepository authRepository,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('ถ่ายรูป'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('เลือกจากคลังภาพ'),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  // Downscaled before upload rather than after. A modern phone camera produces
  // several megabytes per shot, and none of it survives being drawn into a
  // circle a few dozen pixels across — sending the original would spend the
  // user's data on detail no screen ever shows.
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
  } catch (_) {
    // Thrown when camera or photo access was refused.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดกล้องหรือคลังภาพไม่ได้ — ตรวจสอบการอนุญาตของแอป')),
      );
    }
    return null;
  }
  if (picked == null) return null;

  try {
    return await authRepository.uploadAvatar(
      fileBytes: await picked.readAsBytes(),
      fileName: picked.name,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
    return null;
  }
}
