import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/symptom_category.dart';
import '../domain/entities/symptom_log.dart';
import '../domain/usecases/record_symptom_usecase.dart';

class SymptomLogScreen extends StatefulWidget {
  const SymptomLogScreen({
    super.key,
    required this.patientId,
    required this.recordSymptomUseCase,
  });

  final String patientId;
  final RecordSymptomUseCase recordSymptomUseCase;

  @override
  State<SymptomLogScreen> createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends State<SymptomLogScreen> {
  String? _category;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_category == null) {
      setState(() => _error = 'กรุณาเลือกหมวดอาการก่อนบันทึก');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.recordSymptomUseCase(
        SymptomLog(patientId: widget.patientId, category: _category),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกอาการแล้ว')),
        );
        setState(() => _category = null);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บันทึกอาการวันนี้')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('หมวดอาการ*', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptomCategories.map((c) {
                final selected = _category == c.key;
                return ChoiceChip(
                  label: Text(c.label),
                  avatar: Icon(
                    c.icon,
                    size: 18,
                    color: selected ? Colors.white : OnboardingColors.teal,
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _category = c.key;
                    _error = null;
                  }),
                  selectedColor: OnboardingColors.teal,
                  labelStyle: TextStyle(color: selected ? Colors.white : OnboardingColors.text),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}
