import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../../shared/theme/app_palette.dart';

/// What the form collected, handed back to the caller to save.
class MedicationDraft {
  const MedicationDraft({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    required this.times,
    this.endDate,
  });

  final String name;
  final String dosage;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> times;
}

/// Form for adding a medication.
///
/// Takes the patient's recorded [allergies] so it can say something when the
/// name being typed matches one. That check is the reason allergies are stored
/// as separate entries rather than as a sentence — this is the moment it pays
/// for itself.
class MedicationEditSheet extends StatefulWidget {
  const MedicationEditSheet({super.key, this.allergies = const []});

  final List<String> allergies;

  @override
  State<MedicationEditSheet> createState() => _MedicationEditSheetState();
}

class _MedicationEditSheetState extends State<MedicationEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final List<TimeOfDay> _times = [];

  @override
  void initState() {
    super.initState();
    // Rebuilds as the name is typed so the allergy warning appears while the
    // user is still looking at the field, not after they press save.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  /// Recorded allergies that look like the medication being entered.
  ///
  /// Matched by substring in both directions, case-insensitively, because the
  /// two names rarely arrive identical — an allergy noted as "เพนิซิลลิน"
  /// should still catch "เพนิซิลลิน วี". This will occasionally warn when it
  /// need not; that is the right direction to be wrong in, and the warning
  /// informs rather than blocks.
  List<String> get _matchingAllergies {
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) return const [];
    return widget.allergies.where((allergy) {
      final a = allergy.trim().toLowerCase();
      if (a.isEmpty) return false;
      return name.contains(a) || a.contains(name);
    }).toList();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      helpText: isStart ? 'วันที่เริ่มกิน' : 'วันที่หยุด',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'เวลาที่ต้องกิน',
    );
    if (picked == null) return;
    final already = _times.any(
      (t) => t.hour == picked.hour && t.minute == picked.minute,
    );
    if (already) return;
    setState(() {
      _times.add(picked);
      _times.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
    });
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _timeText(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _dateText(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      MedicationDraft(
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: _frequencyController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        times: _times.map(_timeText).toList(),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: AppPalette.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final matches = _matchingAllergies;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'เพิ่มยา',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppPalette.heading),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _Label('ชื่อยา*'),
              TextFormField(
                controller: _nameController,
                decoration: _decoration('เช่น พาราเซตามอล'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรอกชื่อยา' : null,
              ),
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppPalette.dangerBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppPalette.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'คุณเคยระบุว่าแพ้ ${matches.join(', ')} '
                          '— ตรวจสอบกับแพทย์หรือเภสัชกรก่อนใช้ยานี้',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppPalette.danger,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _Label('ขนาด/ปริมาณ*'),
              TextFormField(
                controller: _dosageController,
                decoration: _decoration('เช่น 500 mg หรือ 1 เม็ด'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรอกขนาดยา' : null,
              ),
              const SizedBox(height: 16),
              const _Label('ความถี่*'),
              TextFormField(
                controller: _frequencyController,
                decoration: _decoration('เช่น วันละ 3 ครั้ง หลังอาหาร'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรอกความถี่' : null,
              ),
              const SizedBox(height: 16),
              const _Label('เวลาที่ต้องกิน'),
              const Text(
                'เวลาที่ใส่ไว้จะขึ้นในรายการ "วันนี้"',
                style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final time in _times)
                    Chip(
                      label: Text(_timeText(time)),
                      onDeleted: () => setState(() => _times.remove(time)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('เพิ่มเวลา'),
                    onPressed: _addTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('เริ่มกิน'),
                        OutlinedButton(
                          onPressed: () => _pickDate(isStart: true),
                          child: Text(_dateText(_startDate)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('หยุดกิน (ถ้ามี)'),
                        OutlinedButton(
                          onPressed: () => _pickDate(isStart: false),
                          child: Text(
                            _endDate == null ? 'ไม่กำหนด' : _dateText(_endDate!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_endDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _endDate = null),
                    child: const Text('ล้างวันหยุด'),
                  ),
                ),
              const SizedBox(height: 20),
              OnboardingPrimaryButton(label: 'บันทึก', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
