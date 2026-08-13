import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../doctors/domain/entities/doctor.dart';
import '../data/admin_repository.dart';

/// Where an admin publishes doctors and decides which accounts are one.
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
  late Future<_AdminData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminData> _load() async {
    final doctors = await widget.repository.doctors();
    final accounts = await widget.repository.accounts();
    return _AdminData(doctors: doctors, accounts: accounts);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addDoctor(List<AccountSummary> accounts) async {
    // Only accounts with no listing yet can be linked — doctors.user_id is
    // unique, so offering a taken one would just fail at insert.
    final linkable = accounts.where((a) => !a.isDoctor).toList();

    final result = await showModalBottomSheet<_DoctorInput>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DoctorFormSheet(accounts: linkable),
    );
    if (result == null) return;

    try {
      await widget.repository.createDoctor(
        name: result.name,
        specialty: result.specialty,
        bio: result.bio,
        userId: result.userId,
        credential: result.credential,
        workplace: result.workplace,
        languages: result.languages,
        conditions: result.conditions,
        consultFee: result.consultFee,
        consultMinutes: result.consultMinutes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.userId == null
                ? 'เพิ่ม ${result.name} แล้ว — ผู้ป่วยเห็นในหน้าแรกทันที'
                : 'เพิ่ม ${result.name} และผูกบัญชีให้เรียบร้อยแล้ว',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เพิ่มแพทย์ไม่สำเร็จ: $e')));
    }
  }

  Future<void> _linkAccount(Doctor doctor, List<AccountSummary> accounts) async {
    final linkable = accounts.where((a) => !a.isDoctor).toList();
    if (linkable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีบัญชีที่ยังไม่ได้ผูกกับแพทย์คนอื่น')),
      );
      return;
    }

    final account = await showModalBottomSheet<AccountSummary>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AccountPickerSheet(
        accounts: linkable,
        title: 'ผูกบัญชีให้ ${doctor.name}',
      ),
    );
    if (account == null) return;

    try {
      await widget.repository.linkAccount(doctorId: doctor.id, userId: account.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ผูก ${account.email} กับ ${doctor.name} แล้ว')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผูกบัญชีไม่สำเร็จ: $e')));
    }
  }

  Future<void> _repairRole(AccountSummary account) async {
    try {
      await widget.repository.repairDoctorRole(userId: account.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ซ่อมสิทธิ์ ${account.doctorName ?? account.email} แล้ว — '
            'ให้บัญชีนี้ออกจากระบบแล้วเข้าใหม่',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ซ่อมสิทธิ์ไม่สำเร็จ: $e')));
    }
  }

  Future<void> _remove(Doctor doctor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบแพทย์ออกจากระบบ'),
        content: Text(
          'ต้องการลบ ${doctor.name} ใช่ไหม?\n\n'
          'ประวัติการสนทนากับผู้ป่วยทั้งหมดของแพทย์คนนี้จะถูกลบไปด้วย และกู้คืนไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยันลบ', style: TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository
          .deleteDoctor(doctorId: doctor.id, userId: doctor.userId);
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('จัดการบัญชีแพทย์')),
      body: FutureBuilder<_AdminData>(
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
                    Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _reload, child: const Text('ลองอีกครั้ง')),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const _SectionLabel('แพทย์ในระบบ'),
                if (data.doctors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'ยังไม่มีแพทย์ — กดปุ่ม "เพิ่มแพทย์" ด้านล่างเพื่อสร้าง\n'
                      'แพทย์ที่เพิ่มจะขึ้นในหน้าแรกของผู้ป่วยทันที',
                      style: TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
                    ),
                  )
                else
                  ...data.doctors.map(
                    (d) => _DoctorRow(
                      doctor: d,
                      onLink: () => _linkAccount(d, data.accounts),
                      onRemove: () => _remove(d),
                    ),
                  ),
                const SizedBox(height: 28),
                const _SectionLabel('บัญชีผู้ใช้ทั้งหมด'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'บัญชีที่ยังไม่เป็นแพทย์ สามารถผูกเข้ากับโปรไฟล์แพทย์ได้',
                    style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
                  ),
                ),
                ...data.accounts.map(
                  (a) => _AccountRow(account: a, onRepairRole: () => _repairRole(a)),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FutureBuilder<_AdminData>(
        future: _future,
        builder: (context, snapshot) {
          final accounts = snapshot.data?.accounts ?? const <AccountSummary>[];
          return FloatingActionButton.extended(
            onPressed: () => _addDoctor(accounts),
            backgroundColor: OnboardingColors.teal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มแพทย์'),
          );
        },
      ),
    );
  }
}

class _AdminData {
  const _AdminData({required this.doctors, required this.accounts});
  final List<Doctor> doctors;
  final List<AccountSummary> accounts;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _DoctorRow extends StatelessWidget {
  const _DoctorRow({
    required this.doctor,
    required this.onLink,
    required this.onRemove,
  });

  final Doctor doctor;
  final VoidCallback onLink;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: OnboardingColors.teal,
            child: Icon(Icons.medical_services_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(doctor.specialty,
                    style: const TextStyle(
                        fontSize: 12, color: OnboardingColors.textMuted)),
                const SizedBox(height: 4),
                if (doctor.hasAccount)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 13, color: OnboardingColors.teal),
                      SizedBox(width: 4),
                      Text('ผูกบัญชีแล้ว — เข้าสู่ระบบและอ่านข้อความได้',
                          style: TextStyle(fontSize: 11, color: OnboardingColors.teal)),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 13, color: Color(0xFFB26A00)),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text('ยังไม่มีบัญชี — อ่านข้อความจากผู้ป่วยไม่ได้',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB26A00))),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!doctor.hasAccount)
            IconButton(
              onPressed: onLink,
              icon: const Icon(Icons.link, size: 20),
              tooltip: 'ผูกบัญชี',
            ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFC0392B)),
            tooltip: 'ลบ',
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onRepairRole});

  final AccountSummary account;
  final VoidCallback onRepairRole;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.isDoctor
                ? 'แพทย์: ${account.doctorName}'
                : '${account.email} · ${account.role}',
            style: const TextStyle(fontSize: 12),
          ),
          if (account.roleNeedsRepair)
            const Text(
              'สิทธิ์ยังเป็นผู้ป่วย — บัญชีนี้จะเข้าหน้าหมอไม่ได้',
              style: TextStyle(fontSize: 11, color: Color(0xFFB26A00)),
            ),
        ],
      ),
      trailing: account.roleNeedsRepair
          ? TextButton(onPressed: onRepairRole, child: const Text('ซ่อมสิทธิ์'))
          : null,
    );
  }
}

// ---------------------------------------------------------------------------

class _DoctorInput {
  const _DoctorInput({
    required this.name,
    required this.specialty,
    this.bio,
    this.userId,
    this.credential,
    this.workplace,
    this.languages = const [],
    this.conditions = const [],
    this.consultFee,
    this.consultMinutes,
  });

  final String name;
  final String specialty;
  final String? bio;
  final String? userId;
  final String? credential;
  final String? workplace;
  final List<String> languages;
  final List<String> conditions;
  final double? consultFee;
  final int? consultMinutes;
}

class _DoctorFormSheet extends StatefulWidget {
  const _DoctorFormSheet({required this.accounts});

  final List<AccountSummary> accounts;

  @override
  State<_DoctorFormSheet> createState() => _DoctorFormSheetState();
}

class _DoctorFormSheetState extends State<_DoctorFormSheet> {
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _bioController = TextEditingController();
  final _credentialController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _feeController = TextEditingController();
  final _minutesController = TextEditingController();

  /// Offered as toggles rather than free text so the codes on the card stay
  /// consistent; anything unusual can still go in the profile text.
  static const _languageOptions = ['ไทย', 'อังกฤษ', 'จีน', 'ญี่ปุ่น'];
  final Set<String> _languages = {'ไทย'};

  AccountSummary? _linked;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _bioController.dispose();
    _credentialController.dispose();
    _workplaceController.dispose();
    _conditionsController.dispose();
    _feeController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  /// Empty for a blank field, so an unfilled detail stays absent in the
  /// database rather than being stored as an empty string that the card would
  /// then render as a blank line.
  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  void _submit() {
    final name = _nameController.text.trim();
    final specialty = _specialtyController.text.trim();
    if (name.isEmpty || specialty.isEmpty) {
      setState(() => _error = 'กรอกชื่อและความเชี่ยวชาญให้ครบ');
      return;
    }

    final feeText = _feeController.text.trim();
    final fee = feeText.isEmpty ? null : double.tryParse(feeText);
    if (feeText.isNotEmpty && (fee == null || fee < 0)) {
      setState(() => _error = 'ค่าปรึกษาไม่ถูกต้อง');
      return;
    }

    final minutesText = _minutesController.text.trim();
    final minutes = minutesText.isEmpty ? null : int.tryParse(minutesText);
    if (minutesText.isNotEmpty && (minutes == null || minutes <= 0)) {
      setState(() => _error = 'ระยะเวลาไม่ถูกต้อง');
      return;
    }

    Navigator.of(context).pop(_DoctorInput(
      name: name,
      specialty: specialty,
      bio: _bioController.text,
      userId: _linked?.id,
      credential: _optional(_credentialController),
      workplace: _optional(_workplaceController),
      languages: _languages.toList(),
      // One condition per line: the profile lists them as separate points, so
      // they are separated on the way in rather than split apart on the way out.
      conditions: _conditionsController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      consultFee: fee,
      consultMinutes: minutes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เพิ่มแพทย์',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'แพทย์ที่เพิ่มจะขึ้นในหน้าแรกของผู้ป่วยทันที',
              style: TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
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
            const SizedBox(height: 12),
            TextField(
              controller: _credentialController,
              decoration: _decoration('วุฒิ/ตำแหน่ง เช่น แพทย์เวชปฏิบัติทั่วไป'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workplaceController,
              decoration: _decoration('สถานที่ทำงาน เช่น คลินิกเวชกรรม...'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conditionsController,
              maxLines: 4,
              decoration:
                  _decoration('อาการที่รับปรึกษา — บรรทัดละ 1 ข้อ (ไม่บังคับ)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feeController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: _decoration('ค่าปรึกษา (บาท)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('เวลา (นาที)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ภาษาที่ให้บริการ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in _languageOptions)
                  FilterChip(
                    label: Text(language),
                    selected: _languages.contains(language),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _languages.add(language);
                      } else {
                        _languages.remove(language);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('ผูกกับบัญชีผู้ใช้ (ไม่บังคับ)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'ผูกแล้วแพทย์จะเข้าสู่ระบบด้วยบัญชีนั้นและอ่านข้อความจากผู้ป่วยได้ '
              'ถ้ายังไม่ผูก จะแสดงในรายชื่อแต่ยังตอบข้อความไม่ได้',
              style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
            ),
            const SizedBox(height: 10),
            // Chips rather than a dropdown: the account list here is short,
            // and this avoids DropdownButtonFormField, whose value parameter
            // was renamed between Flutter versions.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('ยังไม่ผูกบัญชี'),
                  selected: _linked == null,
                  onSelected: (_) => setState(() => _linked = null),
                ),
                ...widget.accounts.map(
                  (a) => ChoiceChip(
                    label: Text(a.email.isEmpty ? a.name : a.email),
                    selected: _linked?.id == a.id,
                    onSelected: (_) => setState(() => _linked = a),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            const Text(
              'ตรวจสอบว่าเป็นบุคลากรทางการแพทย์จริงก่อนเพิ่ม — เมื่อเพิ่มแล้ว '
              'บัญชีที่ผูกไว้จะให้คำแนะนำกับผู้ป่วยได้',
              style: TextStyle(fontSize: 12, color: Color(0xFFB26A00), height: 1.4),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(label: 'เพิ่มแพทย์', onPressed: _submit),
          ],
        ),
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

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({required this.accounts, required this.title});

  final List<AccountSummary> accounts;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: accounts
                    .map((a) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE1E1E1),
                            child: Icon(Icons.person,
                                size: 20, color: OnboardingColors.textMuted),
                          ),
                          title: Text(a.name.isEmpty ? a.email : a.name),
                          subtitle: Text(a.email,
                              style: const TextStyle(fontSize: 12)),
                          onTap: () => Navigator.of(context).pop(a),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
