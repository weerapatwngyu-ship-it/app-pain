import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/symptom_providers.dart';
import '../widgets/pain_scale_selector.dart';

class LogSymptomScreen extends ConsumerStatefulWidget {
  const LogSymptomScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<LogSymptomScreen> createState() => _LogSymptomScreenState();
}

class _LogSymptomScreenState extends ConsumerState<LogSymptomScreen> {
  int _painScore = 0;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(symptomFormControllerProvider);

    ref.listen(symptomFormControllerProvider, (previous, next) {
      if (!next.isLoading && next.hasValue && previous?.isLoading == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกอาการเรียบร้อย')),
        );
        Navigator.of(context).maybePop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('บันทึกอาการวันนี้')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PainScaleSelector(
              value: _painScore,
              onChanged: (value) => setState(() => _painScore = value),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'บันทึกเพิ่มเติม (ถ้ามี)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: formState.isLoading
                  ? null
                  : () => ref.read(symptomFormControllerProvider.notifier).submit(
                        patientId: widget.patientId,
                        painScore: _painScore,
                        notes: _notesController.text.isEmpty ? null : _notesController.text,
                      ),
              child: formState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
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
