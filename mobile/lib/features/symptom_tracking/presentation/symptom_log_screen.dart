import 'package:flutter/material.dart';

import '../../../shared/widgets/pain_score_slider.dart';
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
  int _painScore = 0;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.recordSymptomUseCase(
        SymptomLog(patientId: widget.patientId, painScore: _painScore),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกอาการแล้ว')),
        );
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
            PainScoreSlider(
              value: _painScore,
              onChanged: (v) => setState(() => _painScore = v),
            ),
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
