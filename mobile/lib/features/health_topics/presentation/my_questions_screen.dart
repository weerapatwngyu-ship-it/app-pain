import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/health_question_repository.dart';
import '../domain/entities/health_question.dart';
import 'health_topic_detail_screen.dart' show QuestionCard;

/// Every question the patient has asked, across all topics.
class MyQuestionsScreen extends StatefulWidget {
  const MyQuestionsScreen({
    super.key,
    required this.patientId,
    required this.repository,
  });

  final String patientId;
  final HealthQuestionRepository repository;

  @override
  State<MyQuestionsScreen> createState() => _MyQuestionsScreenState();
}

class _MyQuestionsScreenState extends State<MyQuestionsScreen> {
  late Future<List<HealthQuestion>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchForPatient(widget.patientId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.repository.fetchForPatient(widget.patientId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: 'คำถามของฉัน',
              ),
            ),
            Expanded(
              child: FutureBuilder<List<HealthQuestion>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'โหลดคำถามไม่สำเร็จ: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _reload,
                              child: const Text('ลองอีกครั้ง'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final questions = snapshot.data ?? const <HealthQuestion>[];
                  if (questions.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'ยังไม่เคยฝากคำถามถึงแพทย์\nเลือกหมวดในคลินิกออนไลน์เพื่อเริ่มถาม',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: OnboardingColors.textMuted),
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: questions
                          .map((q) => QuestionCard(question: q, showTopic: true))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
