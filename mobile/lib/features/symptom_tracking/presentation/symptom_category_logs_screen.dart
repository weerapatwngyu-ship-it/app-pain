import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/symptom_category.dart';
import '../domain/entities/symptom_log.dart';
import '../domain/symptom_repository.dart';
import '../domain/usecases/record_symptom_usecase.dart';
import 'symptom_log_screen.dart';

class SymptomCategoryLogsScreen extends StatefulWidget {
  const SymptomCategoryLogsScreen({
    super.key,
    required this.patientId,
    required this.repository,
    this.category,
  });

  final String patientId;
  final SymptomRepository repository;

  /// Null shows every logged symptom regardless of category ("ดูทั้งหมด").
  final String? category;

  @override
  State<SymptomCategoryLogsScreen> createState() => _SymptomCategoryLogsScreenState();
}

class _SymptomCategoryLogsScreenState extends State<SymptomCategoryLogsScreen> {
  late Future<List<SymptomLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = widget.repository.fetchLogs(widget.patientId, category: widget.category);
  }

  void _reload() {
    setState(() {
      _logsFuture =
          widget.repository.fetchLogs(widget.patientId, category: widget.category);
    });
  }

  /// Opens the recording form, then refreshes on return.
  ///
  /// The screen already holds the repository the form needs, so this costs no
  /// extra wiring — and without it this was a page you could only reverse out
  /// of, which is a poor answer to "you have no entries yet".
  Future<void> _record() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SymptomLogScreen(
          patientId: widget.patientId,
          recordSymptomUseCase: RecordSymptomUseCase(widget.repository),
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category != null ? symptomCategoryLabel(widget.category) : 'บันทึกอาการทั้งหมด';
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      appBar: AppBar(title: Text(title), backgroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _record,
        backgroundColor: OnboardingColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('บันทึกอาการ'),
      ),
      body: FutureBuilder<List<SymptomLog>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('โหลดข้อมูลไม่สำเร็จ'));
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_note,
                        size: 44, color: OnboardingColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'ยังไม่มีบันทึกในหมวดนี้',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'บันทึกไว้เรื่อย ๆ จะเห็นว่าอาการดีขึ้นหรือแย่ลง\nและเล่าให้แพทย์ฟังได้ตรงขึ้น',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: OnboardingColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _record,
                      icon: const Icon(Icons.add),
                      label: const Text('บันทึกอาการ'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final category = symptomCategoryFor(log.category);
              final note = log.customFields?['note'] as String?;
              final score = log.painScore;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OnboardingColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: OnboardingColors.teal,
                      radius: 20,
                      child: Icon(category.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (log.recordedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(log.recordedAt!),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: OnboardingColors.textMuted),
                            ),
                          ],
                          if (note != null && note.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(note,
                                style:
                                    const TextStyle(fontSize: 13, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    if (score != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
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
            },
          );
        },
      ),
    );
  }
}
