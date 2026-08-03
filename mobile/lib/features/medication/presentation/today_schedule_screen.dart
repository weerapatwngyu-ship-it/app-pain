import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/user_avatar.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../symptom_tracking/domain/entities/symptom_category.dart';
import '../../symptom_tracking/domain/symptom_repository.dart';
import '../../symptom_tracking/presentation/symptom_category_logs_screen.dart';
import '../domain/entities/dose_log.dart';
import '../domain/entities/dose_schedule_item.dart';
import '../domain/medication_repository.dart';
import '../domain/usecases/log_dose_usecase.dart';

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({
    super.key,
    required this.user,
    required this.patientId,
    required this.medicationRepository,
    required this.logDoseUseCase,
    required this.symptomRepository,
    required this.authRepository,
    required this.mediaBaseUrl,
    required this.onUserUpdated,
  });

  final AppUser user;
  final String patientId;
  final MedicationRepository medicationRepository;
  final LogDoseUseCase logDoseUseCase;
  final SymptomRepository symptomRepository;
  final AuthRepository authRepository;
  final String mediaBaseUrl;
  final ValueChanged<AppUser> onUserUpdated;

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  late Future<List<DoseScheduleItem>> _scheduleFuture;
  late Future<Map<String, int>> _categoryCountsFuture;

  /// Doses logged (taken or skipped) during this app session — the backend
  /// doesn't return today's already-logged status alongside the schedule,
  /// so this tracks only what's been actioned since the screen loaded, not
  /// history from a prior session.
  final Set<String> _actionedScheduleIds = {};

  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = widget.medicationRepository.todaySchedule(widget.patientId);
    _categoryCountsFuture = widget.symptomRepository.categoryCounts(widget.patientId);
  }

  void _openCategory(String? category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SymptomCategoryLogsScreen(
          patientId: widget.patientId,
          repository: widget.symptomRepository,
          category: category,
        ),
      ),
    );
  }

  Future<void> _logDose(DoseScheduleItem item, DoseLogStatus status) async {
    await widget.logDoseUseCase(DoseLog(
      scheduleId: item.scheduleId,
      scheduledAt: DateTime.now(),
      actionedAt: DateTime.now(),
      status: status,
    ));
    if (!mounted) return;
    setState(() => _actionedScheduleIds.add(item.scheduleId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกแล้ว: ${item.medicationName}')),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final updatedUser = await widget.authRepository.uploadAvatar(
        fileBytes: bytes,
        fileName: picked.name,
      );
      widget.onUserUpdated(updatedUser);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ ลองใหม่อีกครั้ง')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'สวัสดีตอนดึก';
    if (hour < 12) return 'สวัสดีตอนเช้า';
    if (hour < 18) return 'สวัสดีตอนบ่าย';
    return 'สวัสดีตอนเย็น';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<List<DoseScheduleItem>>(
          future: _scheduleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('โหลดตารางยาไม่สำเร็จ'));
            }
            final items = snapshot.data ?? [];
            final doneCount = items
                .where((item) => _actionedScheduleIds.contains(item.scheduleId))
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _Header(
                  greeting: _greeting,
                  name: widget.user.name,
                  avatarUrl: widget.user.avatarUrl != null
                      ? '${widget.mediaBaseUrl}${widget.user.avatarUrl}'
                      : null,
                  uploadingAvatar: _uploadingAvatar,
                  onAvatarTap: _pickAndUploadAvatar,
                ),
                const SizedBox(height: 20),
                _SummaryCard(total: items.length, done: doneCount),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'หมวดอาการ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => _openCategory(null),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ดูทั้งหมด', style: TextStyle(color: OnboardingColors.teal)),
                          Icon(Icons.chevron_right, size: 18, color: OnboardingColors.teal),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, int>>(
                  future: _categoryCountsFuture,
                  builder: (context, snapshot) {
                    final counts = snapshot.data ?? const {};
                    return SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: symptomCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final category = symptomCategories[index];
                          return _CategoryTile(
                            category: category,
                            count: counts[category.key] ?? 0,
                            onTap: () => _openCategory(category.key),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'ตารางยาวันนี้',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('ไม่มีรายการยาวันนี้')),
                  )
                else
                  ...items.map((item) => _DoseTile(
                        item: item,
                        actioned: _actionedScheduleIds.contains(item.scheduleId),
                        onLog: (status) => _logDose(item, status),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.uploadingAvatar,
    required this.onAvatarTap,
  });

  final String greeting;
  final String name;
  final String? avatarUrl;
  final bool uploadingAvatar;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          name: name,
          avatarUrl: avatarUrl,
          radius: 24,
          loading: uploadingAvatar,
          onTap: onAvatarTap,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13)),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count, required this.onTap});

  final SymptomCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(category.icon, color: OnboardingColors.teal, size: 26),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: OnboardingColors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OnboardingColors.teal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ยาวันนี้', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            total == 0 ? 'ไม่มีรายการยาวันนี้' : 'บันทึกแล้ว $done จาก $total รายการ',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.item, required this.actioned, required this.onLog});

  final DoseScheduleItem item;
  final bool actioned;
  final ValueChanged<DoseLogStatus> onLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(14),
        color: actioned ? const Color(0xFFF3FAF8) : Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicationName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${item.dosage} · ${item.scheduledTime}',
                  style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (actioned)
            const Icon(Icons.check_circle, color: OnboardingColors.teal)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: OnboardingColors.teal),
                  tooltip: 'กินยาแล้ว',
                  onPressed: () => onLog(DoseLogStatus.taken),
                ),
                IconButton(
                  icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
                  tooltip: 'ข้าม',
                  onPressed: () => onLog(DoseLogStatus.skipped),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
