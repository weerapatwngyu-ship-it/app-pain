import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/notification/notification_service.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/reminder_watch_service.dart';
import '../../../core/errors/friendly_error.dart';

/// Answers one question: when a reminder does not arrive, was the alarm never
/// delivered, or was it delivered and the notification suppressed?
///
/// Lives under ตั้งค่า rather than on the reminders screen — that screen is
/// what a patient uses every day and should stay free of instrumentation.
/// Crucially it does NOT reschedule anything: opening the reminders screen
/// re-arms every alarm, which would erase the very evidence being read here.
class NotificationCheckScreen extends StatefulWidget {
  const NotificationCheckScreen({super.key});

  @override
  State<NotificationCheckScreen> createState() => _NotificationCheckScreenState();
}

class _NotificationCheckScreenState extends State<NotificationCheckScreen> {
  bool? _allowed;
  List<PendingNotificationRequest> _pending = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() => _loading = true);
    try {
      final status = await NotificationService.instance.status();
      final pending = await NotificationService.instance.pending();
      if (!mounted) return;
      setState(() {
        _allowed = status.notificationsEnabled;
        _pending = pending;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _scheduleTest() async {
    try {
      // Goes through the reminder service, which is what rings a real
      // reminder now. Testing the old plugin path would prove nothing about
      // whether a reminder arrives.
      await ReminderWatchService.test(seconds: 30);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ตั้งไว้แล้ว — ปิดหน้าจอวางไว้ รอ 30 วินาที'),
          duration: Duration(seconds: 6),
        ),
      );
      await _read();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, whileDoing: 'ตั้งไม่สำเร็จ'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('ตรวจสอบระบบเตือน')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) ...[
                  _Card(
                    title: 'อ่านสถานะไม่สำเร็จ',
                    body: _error!,
                    warn: true,
                  ),
                  const SizedBox(height: 12),
                ],
                _Card(
                  title: 'ระบบอนุญาตให้แจ้งเตือน',
                  body: switch (_allowed) {
                    true => 'อนุญาตแล้ว',
                    false => 'ยังไม่อนุญาต — จะไม่มีอะไรแสดงเลย',
                    null => 'ตรวจสอบไม่ได้บนเครื่องนี้',
                  },
                  warn: _allowed == false,
                ),
                const SizedBox(height: 12),
                _Card(
                  title: 'นาฬิกาที่ระบบถือไว้ให้',
                  body: _pending.isEmpty
                      ? 'ไม่มีเลย'
                      : _pending
                          .map((p) => '#${p.id}  ${p.title ?? ''}')
                          .join('\n'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OnboardingColors.teal,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _scheduleTest,
                  child: const Text('ตั้งทดสอบ 30 วินาที'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _read,
                  child: const Text('อ่านสถานะใหม่'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'วิธีอ่านผล',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กด "ตั้งทดสอบ 30 วินาที" แล้ว "ปิดหน้าจอวางเครื่องทิ้งไว้" '
                  'อย่าเปิดแอปค้างไว้ — ถ้าเปิดค้าง เครื่องจะไม่ปิดแอป '
                  'ผลที่ได้จะไม่ตรงกับตอนใช้งานจริง\n\n'
                  '• ดังขึ้นมา = ใช้งานได้แล้ว เตือนกินยาจะดังตามเวลาที่ตั้ง\n'
                  '• ไม่ดัง = ยังมีอะไรบล็อกอยู่ ส่งภาพหน้าจอนี้มาให้ดูได้',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ตอนนี้แอปเฝ้าเวลาด้วยตัวเอง ไม่ได้ฝากเครื่องปลุกแล้ว '
                  'จึงต้องมีการแจ้งเตือน "MediGo กำลังเฝ้าเวลากินยา" '
                  'ค้างอยู่ในแถบบนตลอด — อันนั้นคือสิ่งที่ทำให้แอปไม่ถูกปิด '
                  'ถ้าปัดทิ้งหรือปิดไป การเตือนกินยาจะกลับไปไม่ดังเหมือนเดิม\n\n'
                  'รายการ "นาฬิกาที่ระบบถือไว้ให้" ด้านบนเป็นของกลไกเดิม '
                  'ตอนนี้เลิกใช้แล้วจึงว่างเปล่าเป็นปกติ ไม่ใช่ความผิดพลาด',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: OnboardingColors.textMuted),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.body, this.warn = false});

  final String title;
  final String body;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? const Color(0xFFFFF4E5) : const Color(0xFFF3F5F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
