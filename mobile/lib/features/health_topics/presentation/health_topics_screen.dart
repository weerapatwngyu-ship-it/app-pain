import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../doctors/data/doctor_repository.dart';
import '../data/health_question_repository.dart';
import '../domain/entities/health_topic.dart';
import 'health_topic_detail_screen.dart';
import 'my_questions_screen.dart';
import '../../../core/i18n/app_locale.dart';

/// The full catalogue, as a grid of topics to read about and ask questions on.
class HealthTopicsScreen extends StatelessWidget {
  const HealthTopicsScreen({
    super.key,
    required this.patientId,
    required this.questionRepository,
    required this.doctorRepository,
    required this.chatRepository,
  });

  final String? patientId;
  final HealthQuestionRepository questionRepository;
  final DoctorRepository doctorRepository;
  final ChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OnboardingHeader(
                      icon: Icons.arrow_back,
                      onIconTap: () => Navigator.of(context).pop(),
                      title: t('คลินิกออนไลน์', 'Online clinic'),
                    ),
                  ),
                  if (patientId != null)
                    OnboardingIconButton(
                      icon: Icons.forum_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyQuestionsScreen(
                            patientId: patientId!,
                            repository: questionRepository,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                t('เลือกหมวดที่ตรงกับอาการหรือเรื่องที่สงสัย เพื่ออ่านข้อมูลและฝากคำถามถึงแพทย์', 'Pick the topic that matches your symptom or question, to read about it and ask a doctor'),
                style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemCount: healthTopics.length,
                itemBuilder: (context, index) {
                  final topic = healthTopics[index];
                  return _TopicTile(
                    topic: topic,
                    onTap: () => openHealthTopic(
                      context,
                      topic: topic,
                      patientId: patientId,
                      questionRepository: questionRepository,
                      doctorRepository: doctorRepository,
                      chatRepository: chatRepository,
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

void openHealthTopic(
  BuildContext context, {
  required HealthTopic topic,
  required String? patientId,
  required HealthQuestionRepository questionRepository,
  required DoctorRepository doctorRepository,
  required ChatRepository chatRepository,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => HealthTopicDetailScreen(
        topic: topic,
        patientId: patientId,
        questionRepository: questionRepository,
        doctorRepository: doctorRepository,
        chatRepository: chatRepository,
      ),
    ),
  );
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.onTap});

  final HealthTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5F3),
              shape: BoxShape.circle,
            ),
            child: Icon(topic.icon, color: OnboardingColors.teal, size: 28),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              topic.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: OnboardingColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
