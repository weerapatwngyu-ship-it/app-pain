import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/symptom_category.dart';
import '../domain/entities/symptom_log.dart';
import '../domain/symptom_repository.dart';

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

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category != null ? symptomCategoryLabel(widget.category) : 'บันทึกอาการทั้งหมด';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
            return const Center(child: Text('ยังไม่มีบันทึกอาการในหมวดนี้'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(color: OnboardingColors.border),
            itemBuilder: (context, index) {
              final log = logs[index];
              final category = symptomCategories.firstWhere(
                (c) => c.key == log.category,
                orElse: () => symptomCategories.last,
              );
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: OnboardingColors.teal,
                  child: Icon(category.icon, color: Colors.white, size: 20),
                ),
                title: Text(symptomCategoryLabel(log.category)),
                subtitle: log.recordedAt != null ? Text(_formatDate(log.recordedAt!)) : null,
              );
            },
          );
        },
      ),
    );
  }
}
