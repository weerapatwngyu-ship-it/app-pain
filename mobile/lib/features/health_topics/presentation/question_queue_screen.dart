import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/health_question_repository.dart';
import '../domain/entities/health_question.dart';
import '../domain/entities/health_topic.dart';
import '../../../shared/theme/app_palette.dart';

/// The doctor's side of "คลินิกออนไลน์": questions patients left, and the
/// form to answer them.
///
/// Until this existed the feature was one-way — patients could post a question
/// and nothing in the app could ever answer it.
class QuestionQueueScreen extends StatefulWidget {
  const QuestionQueueScreen({super.key, required this.repository});

  final HealthQuestionRepository repository;

  @override
  State<QuestionQueueScreen> createState() => _QuestionQueueScreenState();
}

class _QuestionQueueScreenState extends State<QuestionQueueScreen> {
  late Future<List<QueuedQuestion>> _future;
  bool _pendingOnly = true;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.queue(pendingOnly: _pendingOnly);
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.queue(pendingOnly: _pendingOnly));
    await _future;
  }

  Future<void> _answer(QueuedQuestion item) async {
    final controller = TextEditingController(text: item.question.answer ?? '');
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ตอบคำถามของ ${item.patientName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppPalette.heading),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(item.question.question,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'พิมพ์คำตอบ...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'คำตอบนี้จะแสดงให้ผู้ป่วยเห็น และแก้ไม่ได้หลังส่ง',
              style: TextStyle(fontSize: 11, color: OnboardingColors.textMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: OnboardingColors.teal),
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  Navigator.of(context).pop(value);
                },
                child: const Text('ส่งคำตอบ'),
              ),
            ),
          ],
        ),
      ),
    );
    if (text == null) return;

    try {
      await widget.repository.answer(questionId: item.question.id, answer: text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ตอบคำถามของ ${item.patientName} แล้ว')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.tint,
      appBar: AppBar(title: const Text('คำถามจากผู้ป่วย')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('รอตอบ'),
                  selected: _pendingOnly,
                  onSelected: (_) {
                    setState(() => _pendingOnly = true);
                    _reload();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('ทั้งหมด'),
                  selected: !_pendingOnly,
                  onSelected: (_) {
                    setState(() => _pendingOnly = false);
                    _reload();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<QueuedQuestion>>(
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
                          Text('โหลดคำถามไม่สำเร็จ: ${snapshot.error}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton(
                              onPressed: _reload, child: const Text('ลองอีกครั้ง')),
                        ],
                      ),
                    ),
                  );
                }
                final items = snapshot.data ?? const <QueuedQuestion>[];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _pendingOnly
                            ? 'ไม่มีคำถามที่รอตอบ'
                            : 'ยังไม่มีคำถามจากผู้ป่วย',
                        style: const TextStyle(color: OnboardingColors.textMuted),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _QuestionCard(item: items[index], onAnswer: () => _answer(items[index])),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item, required this.onAnswer});

  final QueuedQuestion item;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final q = item.question;
    final answered = q.status == QuestionStatus.answered;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: answered ? AppPalette.soft : AppPalette.warningSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  q.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: answered ? OnboardingColors.teal : AppPalette.warning,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  healthTopicLabel(q.topicKey),
                  style: const TextStyle(
                      fontSize: 12, color: OnboardingColors.textMuted),
                ),
              ),
              Text(
                '${q.createdAt.day}/${q.createdAt.month}',
                style: const TextStyle(
                    fontSize: 11, color: OnboardingColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.patientName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(q.question, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (q.answer != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(q.answer!,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ],
          if (!answered) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onAnswer,
                child: const Text('ตอบคำถาม'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
