import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a thrown object into something a patient can act on.
///
/// Screens were showing `'บันทึกไม่สำเร็จ: $e'`, which puts a Dart exception —
/// often an English Postgres message with a constraint name in it — in front of
/// someone who wanted to record a dose. It tells them nothing they can do and
/// reads as though the app broke in a way that is their problem.
///
/// The original is still printed to the log, because the developer does need
/// the constraint name.
String friendlyError(Object error, {String? whileDoing}) {
  debugPrint('friendlyError${whileDoing == null ? '' : ' ($whileDoing)'}: $error');

  final prefix = whileDoing == null ? '' : '$whileDoing';

  String withPrefix(String message) =>
      prefix.isEmpty ? message : '$prefix — $message';

  if (error is SocketException || error is HttpException) {
    return withPrefix('เชื่อมต่ออินเทอร์เน็ตไม่ได้ ลองใหม่อีกครั้ง');
  }

  if (error is AuthException) {
    switch (error.message) {
      case 'Invalid login credentials':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'User already registered':
        return 'อีเมลนี้สมัครไว้แล้ว — ลองเข้าสู่ระบบแทน';
      case 'Email not confirmed':
        return 'ยังไม่ได้ยืนยันอีเมล — เปิดอีเมลแล้วกดลิงก์ยืนยันก่อน';
      case 'Invalid API key':
        return 'แอปเชื่อมต่อระบบไม่ได้ — กรุณาแจ้งผู้ดูแลระบบ';
    }
    return withPrefix('เข้าสู่ระบบไม่สำเร็จ');
  }

  if (error is PostgrestException) {
    // 42501 and the RLS wording both mean the same thing to a user: the
    // server refused, and no amount of retrying will change that.
    final message = error.message.toLowerCase();
    if (error.code == '42501' || message.contains('row-level security')) {
      return withPrefix('ไม่มีสิทธิ์แก้ไขรายการนี้');
    }
    if (message.contains('duplicate key')) {
      return withPrefix('มีรายการนี้อยู่แล้ว');
    }
    if (message.contains('violates check constraint')) {
      return withPrefix('ข้อมูลที่กรอกไม่ถูกต้อง');
    }
    return withPrefix('บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
  }

  if (error is StorageException) {
    return withPrefix('อัปโหลดไฟล์ไม่สำเร็จ ลองใหม่อีกครั้ง');
  }

  return withPrefix('เกิดข้อผิดพลาด ลองใหม่อีกครั้ง');
}
