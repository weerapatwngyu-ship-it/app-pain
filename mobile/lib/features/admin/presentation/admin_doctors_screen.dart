import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/admin_repository.dart';

/// Where an admin turns an ordinary account into a doctor patients can see.
///
/// Approval is deliberately manual: nothing in the sign-up flow lets someone
/// declare themselves a doctor, because an unverified account giving medical
/// advice is worse than the inconvenience of approving one by one.
class AdminDoctorsScreen extends StatefulWidget {
  const AdminDoctorsScreen({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  late Future<List<AccountSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.accounts();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.accounts());
    await _future;
  }

  Future<void> _approve(AccountSummary account) async {
    final result = await showModalBottomSheet<_ApprovalInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ApproveSheet(account: account),
    );
    if (result == null) return;

    try {
      await widget.repository.approveDoctor(
        userId: account.id,
        name: result.name,
        specialty: result.specialty,
        bio: result.bio,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อนุมัติ ${result.name} เป็นแพทย์แล้ว')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('อนุมัติไม่สำเร็จ: $e')));
    }
  }

  Future<void> _revoke(AccountSummary account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกสถานะแพทย์'),
        content: Text(
          'ต้องการยกเลิกสถานะแพทย์ของ ${account.doctorName ?? account.name} ใช่ไหม?\n\n'
          'ประวัติการสนทนากับผู้ป่วยทั้งหมดจะถูกลบไปด้วย และกู้คืนไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.revokeDoctor(
        userId: account.id,
        doctorId: account.doctorId!,
      );
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('จัดการบัญชีแพทย์')),
      body: FutureBuilder<List<AccountSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('โหลดรายชื่อไม่สำเร็จ: ${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _reload, child: const Text('ลองอีกครั้ง')),
                  ],
                ),
              ),
            );
          }
          final accounts = snapshot.data ?? const <AccountSummary>[];
          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'ไม่เห็นบัญชีใดเลย — หน้านี้ใช้ได้เฉพาะบัญชีผู้ดูแลระบบ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OnboardingColors.textMuted),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: accounts.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: OnboardingColors.border, height: 1),
              itemBuilder: (context, index) {
                final account = accounts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        account.isDoctor ? OnboardingColors.teal : const Color(0xFFE1E1E1),
                    child: Icon(
                      account.isDoctor ? Icons.medical_services_outlined : Icons.person,
                      color: account.isDoctor ? Colors.white : OnboardingColors.textMuted,
                      size: 20,
                    ),
                  ),
                  title: Text(account.name.isEmpty ? account.email : account.name),
                  subtitle: Text(
                    account.isDoctor
                        ? 'แพทย์: ${account.doctorName}'
                        : '${account.email} · ${account.role}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: account.isDoctor
                      ? TextButton(
                          onPressed: () => _revoke(account),
                          child: const Text('ยกเลิก',
                              style: TextStyle(color: Color(0xFFC0392B))),
                        )
                      : TextButton(
                          onPressed: () => _approve(account),
                          child: const Text('อนุมัติเป็นแพทย์'),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ApprovalInput {
  const _ApprovalInput({required this.name, required this.specialty, this.bio});

  final String name;
  final String specialty;
  final String? bio;
}

class _ApproveSheet extends StatefulWidget {
  const _ApproveSheet({required this.account});

  final AccountSummary account;

  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.account.name);
  final _specialtyController = TextEditingController();
  final _bioController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final specialty = _specialtyController.text.trim();
    if (name.isEmpty || specialty.isEmpty) {
      setState(() => _error = 'กรอกชื่อและความเชี่ยวชาญให้ครบ');
      return;
    }
    Navigator.of(context).pop(
      _ApprovalInput(name: name, specialty: specialty, bio: _bioController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'อนุมัติเป็นแพทย์',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.account.email,
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: _decoration('ชื่อที่แสดงกับผู้ป่วย เช่น นพ.สมชาย ใจดี'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialtyController,
            decoration: _decoration('ความเชี่ยวชาญ เช่น อายุรกรรม, ผิวหนัง'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: _decoration('ประวัติโดยย่อ (ไม่บังคับ)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          const Text(
            'ตรวจสอบว่าเป็นบุคลากรทางการแพทย์จริงก่อนอนุมัติ — เมื่ออนุมัติแล้ว '
            'บัญชีนี้จะให้คำแนะนำกับผู้ป่วยได้',
            style: TextStyle(fontSize: 12, color: Color(0xFFB26A00), height: 1.4),
          ),
          const SizedBox(height: 16),
          OnboardingPrimaryButton(label: 'อนุมัติ', onPressed: _submit),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OnboardingColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OnboardingColors.border),
        ),
      );
}
