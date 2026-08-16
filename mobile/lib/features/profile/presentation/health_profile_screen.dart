import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/patient_profile_repository.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

/// The patient's own health details: conditions, drug allergies, blood type
/// and measurements.
///
/// Allergies are entered one drug at a time rather than as a sentence. It is
/// more work to type, and it is the only form on this screen where that is
/// worth it: an allergy is the one entry here meant to be checked against a
/// prescription later, and three drug names inside one line of prose cannot
/// be compared to anything.
class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({
    super.key,
    required this.patientId,
    required this.repository,
  });

  final String patientId;
  final PatientProfileRepository repository;

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _conditionController = TextEditingController();
  final _allergyController = TextEditingController();
  final _foodAllergyController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  final List<String> _allergies = [];
  final List<String> _foodAllergies = [];
  String? _bloodType;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _conditionController.dispose();
    _allergyController.dispose();
    _foodAllergyController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.repository.fetch(widget.patientId);
      if (!mounted) return;
      setState(() {
        _conditionController.text = profile.primaryCondition ?? '';
        _allergies
          ..clear()
          ..addAll(profile.drugAllergies);
        _foodAllergies
          ..clear()
          ..addAll(profile.foodAllergies);
        _bloodType = profile.bloodType;
        _weightController.text = _numberText(profile.weightKg);
        _heightController.text = _numberText(profile.heightCm);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t('โหลดข้อมูลไม่สำเร็จ: $e', 'Could not load: $e');
        _loading = false;
      });
    }
  }

  /// Drops a trailing `.0` so a whole number reads as one.
  static String _numberText(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  void _addTo(List<String> list, TextEditingController controller) {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    // Case-insensitive, so "Penicillin" cannot sit next to "penicillin" and
    // read as two different allergies.
    final already = list.any(
      (existing) => existing.toLowerCase() == name.toLowerCase(),
    );
    setState(() {
      if (!already) list.add(name);
      controller.clear();
    });
  }

  Future<void> _save() async {
    final weight = _parseMeasurement(_weightController.text, max: 500);
    final height = _parseMeasurement(_heightController.text, max: 300);
    if (weight == _invalid || height == _invalid) {
      setState(() => _error = t('น้ำหนักหรือส่วนสูงไม่ถูกต้อง', 'Weight or height is not valid'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final condition = _conditionController.text.trim();
      await widget.repository.updateHealth(
        widget.patientId,
        primaryCondition: condition.isEmpty ? null : condition,
        drugAllergies: _allergies,
        foodAllergies: _foodAllergies,
        bloodType: _bloodType,
        weightKg: weight,
        heightCm: height,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('บันทึกข้อมูลสุขภาพแล้ว', 'Health information saved'))),
      );
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      setState(() => _error = t('บันทึกไม่สำเร็จ: ${e.message}', 'Could not save: ${e.message}'));
    } on SocketException catch (_) {
      setState(() => _error = t('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', 'Cannot reach the server'));
    } catch (e) {
      setState(() => _error = friendlyError(e, whileDoing: t('บันทึกไม่สำเร็จ', 'Could not save')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Sentinel for "typed, but not a usable number" — distinct from null,
  /// which means the field was left blank on purpose.
  static const double _invalid = -1;

  static double? _parseMeasurement(String raw, {required double max}) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0 || value > max) return _invalid;
    return value;
  }

  /// A "type one, press +, it becomes a chip" list.
  ///
  /// Shared by the two allergy fields rather than written twice: they behave
  /// identically and only differ in wording and colour, and a fix to one that
  /// missed the other would be a bug nobody notices until a prescription is
  /// checked against half a list.
  Widget _allergyField({
    required String label,
    required String help,
    required String hint,
    required String emptyNote,
    required TextEditingController controller,
    required List<String> values,
    required Color chipColor,
    required Color chipBorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        Text(
          help,
          style: const TextStyle(
            fontSize: 12,
            color: OnboardingColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: _decoration(hint),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTo(values, controller),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _addTo(values, controller),
              icon: const Icon(Icons.add),
              tooltip: t('เพิ่ม', 'Add'),
            ),
          ],
        ),
        if (values.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              emptyNote,
              style: const TextStyle(
                fontSize: 12,
                color: OnboardingColors.textMuted,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in values)
                  Chip(
                    label: Text(value),
                    backgroundColor: chipColor,
                    side: BorderSide(color: chipBorder),
                    onDeleted: () => setState(() => values.remove(value)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(t('ข้อมูลสุขภาพ', 'Health information'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      children: [
                        _Label(t('โรคประจำตัว', 'Ongoing conditions')),
                        TextField(
                          controller: _conditionController,
                          maxLines: 3,
                          minLines: 2,
                          decoration: _decoration(t('เช่น เบาหวาน ความดันโลหิตสูง', 'e.g. diabetes, high blood pressure')),
                        ),
                        const SizedBox(height: 24),
                        _allergyField(
                          label: t('ยาที่แพ้', 'Drug allergies'),
                          help: t('ใส่ทีละชื่อ เพื่อให้ระบบนำไปตรวจสอบกับยาที่ใช้ได้', 'One per entry, so the app can check it against your medication'),
                          hint: t('เช่น เพนิซิลลิน', 'e.g. penicillin'),
                          emptyNote: t('ยังไม่ได้ระบุ — ถ้าไม่แพ้ยาใดเลย ปล่อยว่างไว้ได้', 'Not recorded — leave empty if you have no drug allergies'),
                          controller: _allergyController,
                          values: _allergies,
                          chipColor: const Color(0xFFFDECEC),
                          chipBorder: const Color(0xFFF3B9B9),
                        ),
                        const SizedBox(height: 24),
                        _allergyField(
                          label: t('อาหารที่แพ้', 'Food allergies'),
                          help: t('ใส่ทีละอย่าง แพทย์จะเห็นในประวัติของคุณ', 'One per entry. Your doctor sees these on your record.'),
                          hint: t('เช่น กุ้ง ถั่วลิสง', 'e.g. shrimp, peanuts'),
                          emptyNote: t('ยังไม่ได้ระบุ — ถ้าไม่แพ้อาหารใดเลย ปล่อยว่างไว้ได้', 'Not recorded — leave empty if you have no food allergies'),
                          controller: _foodAllergyController,
                          values: _foodAllergies,
                          chipColor: const Color(0xFFFFF4E5),
                          chipBorder: const Color(0xFFF0D6A8),
                        ),
                        const SizedBox(height: 24),
                        _Label(t('กรุ๊ปเลือด', 'Blood type')),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in _bloodTypes)
                              ChoiceChip(
                                label: Text(type),
                                selected: _bloodType == type,
                                onSelected: (selected) => setState(
                                  () => _bloodType = selected ? type : null,
                                ),
                              ),
                          ],
                        ),
                        if (_bloodType != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () => setState(() => _bloodType = null),
                              child: Text(t('ล้างกรุ๊ปเลือด', 'Clear blood type')),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label(t('น้ำหนัก (กก.)', 'Weight (kg)')),
                                  TextField(
                                    controller: _weightController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [_decimalOnly],
                                    decoration: _decoration(t('เช่น 65', 'e.g. 65')),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label(t('ส่วนสูง (ซม.)', 'Height (cm)')),
                                  TextField(
                                    controller: _heightController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [_decimalOnly],
                                    decoration: _decoration(t('เช่น 170', 'e.g. 170')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: OnboardingPrimaryButton(
                      label: t('บันทึก', 'Save'),
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Digits and at most one decimal point. Keeps a stray letter or second dot
/// out of the field rather than rejecting it after the fact on save.
final _decimalOnly =
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'));

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
