import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/patient_profile_repository.dart';
import '../../../core/errors/friendly_error.dart';

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
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  final List<String> _allergies = [];
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
        _bloodType = profile.bloodType;
        _weightController.text = _numberText(profile.weightKg);
        _heightController.text = _numberText(profile.heightCm);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
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

  void _addAllergy() {
    final name = _allergyController.text.trim();
    if (name.isEmpty) return;
    // Case-insensitive, so "Penicillin" cannot sit next to "penicillin" and
    // read as two different allergies.
    final already = _allergies.any(
      (existing) => existing.toLowerCase() == name.toLowerCase(),
    );
    setState(() {
      if (!already) _allergies.add(name);
      _allergyController.clear();
    });
  }

  Future<void> _save() async {
    final weight = _parseMeasurement(_weightController.text, max: 500);
    final height = _parseMeasurement(_heightController.text, max: 300);
    if (weight == _invalid || height == _invalid) {
      setState(() => _error = 'น้ำหนักหรือส่วนสูงไม่ถูกต้อง');
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
        bloodType: _bloodType,
        weightKg: weight,
        heightCm: height,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลสุขภาพแล้ว')),
      );
      Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      setState(() => _error = 'บันทึกไม่สำเร็จ: ${e.message}');
    } on SocketException catch (_) {
      setState(() => _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
    } catch (e) {
      setState(() => _error = friendlyError(e, whileDoing: 'บันทึกไม่สำเร็จ'));
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
      appBar: AppBar(title: const Text('ข้อมูลสุขภาพ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      children: [
                        const _Label('โรคประจำตัว'),
                        TextField(
                          controller: _conditionController,
                          maxLines: 3,
                          minLines: 2,
                          decoration: _decoration('เช่น เบาหวาน ความดันโลหิตสูง'),
                        ),
                        const SizedBox(height: 24),
                        const _Label('ยาที่แพ้'),
                        const Text(
                          'ใส่ทีละชื่อ เพื่อให้ระบบนำไปตรวจสอบกับยาที่ใช้ได้',
                          style: TextStyle(
                            fontSize: 12,
                            color: OnboardingColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _allergyController,
                                decoration: _decoration('เช่น เพนิซิลลิน'),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _addAllergy(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _addAllergy,
                              icon: const Icon(Icons.add),
                              tooltip: 'เพิ่ม',
                            ),
                          ],
                        ),
                        if (_allergies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'ยังไม่ได้ระบุ — ถ้าไม่แพ้ยาใดเลย ปล่อยว่างไว้ได้',
                              style: TextStyle(
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
                                for (final allergy in _allergies)
                                  Chip(
                                    label: Text(allergy),
                                    backgroundColor: const Color(0xFFFDECEC),
                                    side: const BorderSide(color: Color(0xFFF3B9B9)),
                                    onDeleted: () =>
                                        setState(() => _allergies.remove(allergy)),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        const _Label('กรุ๊ปเลือด'),
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
                              child: const Text('ล้างกรุ๊ปเลือด'),
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
                                  const _Label('น้ำหนัก (กก.)'),
                                  TextField(
                                    controller: _weightController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [_decimalOnly],
                                    decoration: _decoration('เช่น 65'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _Label('ส่วนสูง (ซม.)'),
                                  TextField(
                                    controller: _heightController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [_decimalOnly],
                                    decoration: _decoration('เช่น 170'),
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
                      label: 'บันทึก',
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
