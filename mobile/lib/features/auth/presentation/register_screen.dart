import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/user.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authRepository,
    required this.onRegistered,
  });

  final AuthRepository authRepository;
  final ValueChanged<AppUser> onRegistered;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.patient;
  bool _loading = false;
  String? _error;

  static const _roleLabels = {
    UserRole.patient: 'ผู้ป่วย',
    UserRole.caregiver: 'ผู้ดูแล',
    UserRole.provider: 'บุคลากรทางการแพทย์',
    UserRole.admin: 'ผู้ดูแลระบบ',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.authRepository.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _role,
      );
      widget.onRegistered(session.user);
    } on ApiException catch (e) {
      setState(() => _error = e.statusCode == 409
          ? 'อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว'
          : 'สมัครสมาชิกไม่สำเร็จ: ${_readableApiMessage(e)}');
    } on SocketException catch (_) {
      setState(() => _error =
          'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ — ตรวจสอบว่า backend กำลังรันอยู่ และตั้งค่า MEDTRACK_API_BASE_URL ถูกต้อง');
    } catch (e) {
      setState(() => _error = 'สมัครสมาชิกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The backend returns a JSON body like `{"message": "...", ...}` on
  /// error (see NestJS's default exception filter) — fall back to the
  /// raw body if it isn't JSON so nothing is silently swallowed.
  static String _readableApiMessage(ApiException e) {
    try {
      final decoded = jsonDecode(e.message);
      if (decoded is Map && decoded['message'] != null) {
        final message = decoded['message'];
        return message is List ? message.join(', ') : message.toString();
      }
    } catch (_) {
      // Not JSON — fall through to the raw body below.
    }
    return e.message.isEmpty ? 'HTTP ${e.statusCode}' : e.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'ชื่อ'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'กรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'อีเมล'),
                validator: (value) =>
                    (value == null || !value.contains('@')) ? 'กรอกอีเมลให้ถูกต้อง' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                validator: (value) =>
                    (value == null || value.length < 8) ? 'รหัสผ่านอย่างน้อย 8 ตัวอักษร' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'บทบาท'),
                items: UserRole.values
                    .map((role) => DropdownMenuItem(value: role, child: Text(_roleLabels[role]!)))
                    .toList(),
                onChanged: (value) => setState(() => _role = value ?? _role),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('สมัครสมาชิก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
