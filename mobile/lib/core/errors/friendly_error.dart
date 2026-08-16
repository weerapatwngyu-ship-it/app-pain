import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/i18n/app_locale.dart';

/// Turns a thrown object into something a patient can act on.
///
/// Screens were showing `'บันทึกไม่สำเร็จ: $e'`, which puts a Dart exception —
/// often an English Postgres message with a constraint name in it — in front of
/// someone who wanted to record a dose. It tells them nothing they can do and
/// reads as though the app broke in a way that is their problem.
///
/// The original is still printed to the log, because the developer does need
/// the constraint name.
/// [deniedMessage] replaces the wording used when the backend refuses on
/// permissions. "ไม่มีสิทธิ์แก้ไขรายการนี้" is true but leaves the user with
/// nothing to do; a screen that knows *why* it would be refused can say so.
String friendlyError(Object error, {String? whileDoing, String? deniedMessage}) {
  debugPrint('friendlyError${whileDoing == null ? '' : ' ($whileDoing)'}: $error');

  final prefix = whileDoing ?? '';

  String withPrefix(String message) =>
      prefix.isEmpty ? message : '$prefix — $message';

  if (error is SocketException || error is HttpException) {
    return withPrefix(t('เชื่อมต่ออินเทอร์เน็ตไม่ได้ ลองใหม่อีกครั้ง', 'No internet connection. Try again.'));
  }

  if (error is AuthException) {
    switch (error.message) {
      case 'Invalid login credentials':
        return t('อีเมลหรือรหัสผ่านไม่ถูกต้อง', 'Wrong email or password');
      case 'User already registered':
        return t('อีเมลนี้สมัครไว้แล้ว — ลองเข้าสู่ระบบแทน', 'That email is already registered — try signing in');
      case 'Email not confirmed':
        return t('ยังไม่ได้ยืนยันอีเมล — เปิดอีเมลแล้วกดลิงก์ยืนยันก่อน', 'Email not confirmed — open the email and follow the link first');
      case 'Invalid API key':
        return t('แอปเชื่อมต่อระบบไม่ได้ — กรุณาแจ้งผู้ดูแลระบบ', 'The app cannot reach the server — please tell an administrator');
    }
    return withPrefix(t('เข้าสู่ระบบไม่สำเร็จ', 'Could not sign in'));
  }

  if (error is PostgrestException) {
    // 42501 and the RLS wording both mean the same thing to a user: the
    // server refused, and no amount of retrying will change that.
    final message = error.message.toLowerCase();
    if (error.code == '42501' || message.contains('row-level security')) {
      return withPrefix(deniedMessage ?? t('ไม่มีสิทธิ์แก้ไขรายการนี้', 'You do not have permission to change this'));
    }
    if (message.contains('duplicate key')) {
      return withPrefix(t('มีรายการนี้อยู่แล้ว', 'That already exists'));
    }
    if (message.contains('violates check constraint')) {
      return withPrefix(t('ข้อมูลที่กรอกไม่ถูกต้อง', 'Some of the details are not valid'));
    }
    return withPrefix(t('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง', 'Could not save. Try again.'));
  }

  if (error is StorageException) {
    return withPrefix(t('อัปโหลดไฟล์ไม่สำเร็จ ลองใหม่อีกครั้ง', 'Upload failed. Try again.'));
  }

  return withPrefix(t('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง', 'Something went wrong. Try again.'));
}
