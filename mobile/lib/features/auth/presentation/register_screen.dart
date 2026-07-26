import 'package:flutter/material.dart';

import '../domain/auth_repository.dart';
import '../domain/entities/user.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authRepository,
    required this.onRegistered,
  });

  final AuthRepository authRepository;
  final VoidCallback onRegistered;

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
      await widget.authRepository.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _role,
      );
      widget.onRegistered();
    } catch (e) {
      setState(() => _error = 'สมัครสมาชิกไม่สำเร็จ อีเมลนี้อาจถูกใช้แล้ว');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
