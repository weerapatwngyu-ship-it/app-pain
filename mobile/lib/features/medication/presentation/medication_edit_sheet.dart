import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../../core/i18n/app_locale.dart';

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
  MedicationEditSheet({
    super.key,
    this.allergies = const [],
    this.title = t('เพิ่มยา', 'Add medication'),
  });

  final List<String> allergies;

  /// Heading on the sheet. A doctor prescribing needs to see whose record
  /// they are writing to; getting that wrong writes a drug onto the wrong
  /// patient.
  final String title;

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
  bool _showTimeError = false;

  /// The times most doses actually land on. Offered as one tap each, because
  /// the alternative is opening a clock dialog four times to enter a schedule
  /// that is almost always one of these.
  /// A getter, not a const map: the labels are translated, so they have to be
  /// rebuilt after a language change rather than frozen at load.
  static Map<String, TimeOfDay> get _quickTimes => {
    t('เช้า', 'Morning'): const TimeOfDay(hour: 8, minute: 0),
    t('กลางวัน', 'Midday'): const TimeOfDay(hour: 12, minute: 0),
    t('เย็น', 'Evening'): const TimeOfDay(hour: 18, minute: 0),
    t('ก่อนนอน', 'Bedtime'): const TimeOfDay(hour: 21, minute: 0),
  };

  bool _hasTime(TimeOfDay t) =>
      _times.any((x) => x.hour == t.hour && x.minute == t.minute);

  void _toggleTime(TimeOfDay t) {
    setState(() {
      if (_hasTime(t)) {
        _times.removeWhere((x) => x.hour == t.hour && x.minute == t.minute);
      } else {
        _times.add(t);
        _times.sort((a, b) =>
            (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
      }
      if (_times.isNotEmpty) _showTimeError = false;
    });
  }

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
      helpText: isStart ? t('วันที่เริ่มกิน', 'Start date') : t('วันที่หยุด', 'Stop date'),
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
      helpText: t('เวลาที่ต้องกิน', 'Times to take it'),
    );
    if (picked == null || _hasTime(picked)) return;
    // Shared with the preset chips so sorting and clearing the "pick a time"
    // error happen in one place rather than two that can drift.
    _toggleTime(picked);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _timeText(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  static String _dateText(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    // A medication with no time never reaches the schedule and never fires a
    // reminder, so saving one produces a row that quietly does nothing.
    setState(() => _showTimeError = _times.isEmpty);
    if (!formOk || _times.isEmpty) return;

    final typed = _frequencyController.text.trim();
    Navigator.of(context).pop(
      MedicationDraft(
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: typed.isEmpty ? t('วันละ ${_times.length} ครั้ง', '${_times.length} times a day') : typed,
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
        fillColor: const Color(0xFFF7F7F7),
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
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Label(t('ชื่อยา*', 'Medication name*')),
              TextFormField(
                controller: _nameController,
                decoration: _decoration(t('เช่น พาราเซตามอล', 'e.g. paracetamol')),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? t('กรอกชื่อยา', 'Enter the medication name') : null,
              ),
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE79A9A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFC0392B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'คุณเคยระบุว่าแพ้ ${matches.join(', ')} '
                          t('— ตรวจสอบกับแพทย์หรือเภสัชกรก่อนใช้ยานี้', '— check with a doctor or pharmacist before using this'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFC0392B),
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
              _Label(t('ขนาด/ปริมาณ*', 'Dose / amount*')),
              TextFormField(
                controller: _dosageController,
                decoration: _decoration(t('เช่น 500 mg หรือ 1 เม็ด', 'e.g. 500 mg or 1 tablet')),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? t('กรอกขนาดยา', 'Enter the dose') : null,
              ),
              const SizedBox(height: 16),
              _Label(t('ความถี่', 'How often')),
              Text(
                t('เว้นว่างได้ — ระบบจะเติมให้จากจำนวนเวลาที่เลือก', 'Optional — filled in from the number of times you choose'),
                style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _frequencyController,
                decoration: _decoration(_times.isEmpty
                    ? t('เช่น วันละ 3 ครั้ง หลังอาหาร', 'e.g. 3 times a day after meals')
                    : t('วันละ ${_times.length} ครั้ง', '${_times.length} times a day')),
              ),
              const SizedBox(height: 16),
              _Label(t('เวลาที่ต้องกิน*', 'Times to take it*')),
              Text(
                t('เลือกอย่างน้อย 1 เวลา ระบบจะเตือนและขึ้นในตารางวันนี้ตามนี้', 'Pick at least one time. Reminders and the daily schedule follow it.'),
                style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _quickTimes.entries)
                    FilterChip(
                      selected: _hasTime(entry.value),
                      onSelected: (_) => _toggleTime(entry.value),
                      showCheckmark: false,
                      label: Text('${entry.key}  ${_timeText(entry.value)}'),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _hasTime(entry.value)
                            ? Colors.white
                            : OnboardingColors.text,
                      ),
                      selectedColor: OnboardingColors.teal,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _hasTime(entry.value)
                            ? OnboardingColors.teal
                            : OnboardingColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Anything the four presets do not cover.
                  for (final time in _times)
                    if (!_quickTimes.values.any(
                        (q) => q.hour == time.hour && q.minute == time.minute))
                      Chip(
                        label: Text(_timeText(time)),
                        onDeleted: () => setState(() => _times.remove(time)),
                      ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(t('เวลาอื่น', 'Another time')),
                    onPressed: _addTime,
                  ),
                ],
              ),
              if (_showTimeError) ...[
                const SizedBox(height: 8),
                Text(
                  t('เลือกเวลาอย่างน้อย 1 เวลา มิฉะนั้นยานี้จะไม่ขึ้นในตารางและไม่มีการเตือน', 'Pick at least one time, or this medication never appears on the schedule and never reminds'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(t('เริ่มกิน', 'Start')),
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
                        _Label(t('หยุดกิน (ถ้ามี)', 'Stop (optional)')),
                        OutlinedButton(
                          onPressed: () => _pickDate(isStart: false),
                          child: Text(
                            _endDate == null ? t('ไม่กำหนด', 'Not set') : _dateText(_endDate!),
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
                    child: Text(t('ล้างวันหยุด', 'Clear stop date')),
                  ),
                ),
              const SizedBox(height: 20),
              OnboardingPrimaryButton(label: t('บันทึก', 'Save'), onPressed: _submit),
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
