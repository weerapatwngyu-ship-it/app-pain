import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/symptom_category.dart';
import '../domain/entities/symptom_log.dart';
import '../domain/symptom_repository.dart';
import '../domain/usecases/record_symptom_usecase.dart';
import '../../../core/i18n/app_locale.dart';

/// Recording how the patient feels today.
///
/// The form used to collect a category and nothing else, so every log read
/// "stomach, today" — enough to count entries, not enough to show whether
/// anything is getting better. The table has carried a 0–10 score and a free
/// field since the beginning; this fills them in.
class SymptomLogScreen extends StatefulWidget {
  const SymptomLogScreen({
    super.key,
    required this.patientId,
    required this.recordSymptomUseCase,
    required this.repository,
  });

  final String patientId;
  final RecordSymptomUseCase recordSymptomUseCase;

  /// Read back so the screen can show what has already been recorded today —
  /// without it, saving clears the form and looks like nothing happened.
  final SymptomRepository repository;

  @override
  State<SymptomLogScreen> createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends State<SymptomLogScreen> {
  final _noteController = TextEditingController();

  String? _category;
  double _score = 3;
  bool _saving = false;
  String? _error;

  late Future<List<SymptomLog>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = widget.repository.fetchLogs(widget.patientId);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Words for the number, because "6" means little on its own and a patient
  /// choosing between 5 and 6 is really choosing between two descriptions.
  static String _scoreLabel(int score) {
    if (score == 0) return t('ไม่มีอาการ', 'None');
    if (score <= 3) return t('เล็กน้อย', 'Mild');
    if (score <= 6) return t('ปานกลาง', 'Moderate');
    if (score <= 8) return t('มาก', 'Severe');
    return t('รุนแรงที่สุด', 'Worst');
  }

  static Color _scoreColor(int score) {
    if (score == 0) return OnboardingColors.teal;
    if (score <= 3) return OnboardingColors.teal;
    if (score <= 6) return const Color(0xFFB26A00);
    return const Color(0xFFC0392B);
  }

  Future<void> _save() async {
    if (_category == null) {
      setState(() => _error = t('กรุณาเลือกหมวดอาการก่อนบันทึก', 'Choose a symptom type before saving'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = _noteController.text.trim();
      await widget.recordSymptomUseCase(
        SymptomLog(
          patientId: widget.patientId,
          category: _category,
          painScore: _score.round(),
          customFields: note.isEmpty ? null : {'note': note},
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('บันทึกอาการแล้ว', 'Symptom recorded'))),
      );
      setState(() {
        _category = null;
        _score = 3;
        _noteController.clear();
        _recentFuture = widget.repository.fetchLogs(widget.patientId);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = t('บันทึกไม่สำเร็จ ลองอีกครั้ง', 'Could not save, try again'));
      debugPrint('recordSymptom failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = _score.round();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      appBar: AppBar(
        title: Text(t('บันทึกอาการวันนี้', "Log today's symptoms")),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Card(
            title: t('วันนี้มีอาการอะไร', 'What are you feeling today?'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptomCategories.map((category) {
                final selected = _category == category.key;
                return ChoiceChip(
                  label: Text(category.label),
                  avatar: Icon(
                    category.icon,
                    size: 18,
                    color: selected ? Colors.white : OnboardingColors.teal,
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _category = category.key;
                    _error = null;
                  }),
                  selectedColor: OnboardingColors.teal,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? OnboardingColors.teal
                        : OnboardingColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : OnboardingColors.text,
                  ),
                );
              }).toList(),
            ),
          ),
          _Card(
            title: t('รุนแรงแค่ไหน', 'How bad is it?'),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score),
                      ),
                    ),
                    const Text(' / 10',
                        style: TextStyle(
                            fontSize: 15, color: OnboardingColors.textMuted)),
                    const SizedBox(width: 12),
                    Text(
                      _scoreLabel(score),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _score,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '$score',
                  activeColor: _scoreColor(score),
                  onChanged: (value) => setState(() => _score = value),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('ไม่มีอาการ', 'None'),
                        style: const TextStyle(
                            fontSize: 12, color: OnboardingColors.textMuted)),
                    Text(t('รุนแรงที่สุด', 'Worst'),
                        style: const TextStyle(
                            fontSize: 12, color: OnboardingColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          _Card(
            title: t('อยากบันทึกเพิ่มไหม', 'Anything to add?'),
            subtitle: t('ไม่บังคับ — เช่น เป็นตอนไหน กินอะไรมาก่อน', 'Optional — when it started, what you ate'),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: t('เช่น ปวดหลังอาหารเที่ยง', 'e.g. pain after lunch'),
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: OnboardingColors.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(t('บันทึกอาการ', 'Log symptom')),
          ),
          const SizedBox(height: 24),
          Text(
            t('บันทึกล่าสุด', 'Recent entries'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<SymptomLog>>(
            future: _recentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final logs = snapshot.data ?? const <SymptomLog>[];
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    t('ยังไม่มีบันทึก — บันทึกครั้งแรกได้จากด้านบน', 'No entries yet — add your first one above'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: OnboardingColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final log in logs.take(5)) _LogRow(log: log),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A white block with a heading. Used instead of loose headings so each
/// question on this form reads as its own step.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OnboardingColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(
                  fontSize: 12.5, color: OnboardingColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});

  final SymptomLog log;

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final category = symptomCategoryFor(log.category);
    final recorded = log.recordedAt;
    final note = log.customFields?['note'] as String?;
    final score = log.painScore;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnboardingColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(category.icon, color: OnboardingColors.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (recorded != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_two(recorded.day)}/${_two(recorded.month)} '
                    '${_two(recorded.hour)}:${_two(recorded.minute)}',
                    style: const TextStyle(
                        fontSize: 12, color: OnboardingColors.textMuted),
                  ),
                ],
                if (note != null && note.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(note,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),
          if (score != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$score/10',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: OnboardingColors.teal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
