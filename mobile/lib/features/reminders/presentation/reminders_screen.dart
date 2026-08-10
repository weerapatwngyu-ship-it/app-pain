import 'package:flutter/material.dart';

import '../../../core/notification/notification_service.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/reminder_repository.dart';
import '../domain/entities/medication_reminder.dart';

/// "เตือนกินยา" — the alarm list, laid out like the phone's own clock app so
/// it needs no explaining: big time, when it repeats, a switch.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    required this.repository,
    required this.alertsRepository,
  });

  final ReminderRepository repository;
  final AlertsRepository alertsRepository;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<MedicationReminder> _reminders = const [];
  NotificationStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Ask on arrival, not at launch: on Android 13+ nothing fires without
      // the notification permission, and asking here means the prompt shows
      // up while the user is looking at the reminders screen.
      await NotificationService.instance.requestPermissions();
      // Alarms do not survive a reboot, so re-apply them whenever this opens.
      await widget.repository.rescheduleAll();
      final reminders = await widget.repository.all();
      // Read after rescheduling, so the count reflects what the OS is
      // actually holding rather than what we hoped it would take.
      final status = await NotificationService.instance.status();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _status = status;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดการเตือนไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _test() async {
    try {
      await NotificationService.instance.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งแล้ว — ถ้าไม่เห็นการแจ้งเตือน แปลว่าระบบปิดกั้นอยู่'),
          duration: Duration(seconds: 5),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ส่งไม่สำเร็จ: $e')));
    }
  }

  Future<void> _edit([MedicationReminder? existing]) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ReminderSheet(existing: existing),
    );
    if (result == null) return;

    try {
      if (result.delete) {
        await widget.repository.delete(existing!.id);
      } else {
        await widget.repository.save(result.reminder!);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    }
  }

  Future<void> _toggle(MedicationReminder reminder, bool value) async {
    setState(() {
      _reminders = [
        for (final r in _reminders)
          if (r.id == reminder.id) r.copyWith(enabled: value) else r,
      ];
    });
    try {
      await widget.repository.setEnabled(reminder, value);
    } catch (e) {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เปลี่ยนสถานะไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('เตือนกินยา'),
        actions: [
          IconButton(
            tooltip: 'ทดสอบการแจ้งเตือน',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _test,
          ),
          IconButton(
            tooltip: 'การแจ้งเตือนจากระบบ',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AlertsScreen(alertsRepository: widget.alertsRepository),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        backgroundColor: OnboardingColors.teal,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }
    if (_reminders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _StatusBanner(status: _status, reminderCount: 0),
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'ยังไม่มีการเตือน\nกดปุ่ม + เพื่อตั้งเวลากินยา',
              textAlign: TextAlign.center,
              style: TextStyle(color: OnboardingColors.textMuted, height: 1.6),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _StatusBanner(status: _status, reminderCount: _reminders.length),
          for (final reminder in _reminders)
            _ReminderCard(
              reminder: reminder,
              onTap: () => _edit(reminder),
              onToggle: (value) => _toggle(reminder, value),
            ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onTap,
    required this.onToggle,
  });

  final MedicationReminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    // Disabled reminders fade rather than disappear, the way the clock app
    // does it, so the row stays tappable to switch back on.
    final faded = !reminder.enabled;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFF6F8F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.timeLabel,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: faded
                            ? OnboardingColors.textMuted
                            : OnboardingColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        reminder.repeatLabel,
                        if (reminder.label.trim().isNotEmpty) reminder.label.trim(),
                      ].join(' | '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: OnboardingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: reminder.enabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the sheet hands back: either a reminder to save, or a delete request.
class _EditResult {
  const _EditResult.save(this.reminder) : delete = false;
  const _EditResult.remove()
      : reminder = null,
        delete = true;

  final MedicationReminder? reminder;
  final bool delete;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.existing});

  final MedicationReminder? existing;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late TimeOfDay _time;
  late Set<int> _days;
  late final TextEditingController _label;

  /// Which of the three chips is lit. Kept separately from [_days] so that
  /// picking "กำหนดเอง" can show an empty weekday row waiting to be filled,
  /// instead of being indistinguishable from "ดังครั้งเดียว".
  late _Repeat _repeat;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _time = existing == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: existing.hour, minute: existing.minute);
    _days = {...?existing?.days};
    _label = TextEditingController(text: existing?.label ?? '');
    _repeat = existing == null || existing.isOneOff
        ? _Repeat.once
        : existing.isEveryDay
            ? _Repeat.everyDay
            : _Repeat.custom;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final days = switch (_repeat) {
      _Repeat.once => <int>{},
      _Repeat.everyDay => {1, 2, 3, 4, 5, 6, 7},
      _Repeat.custom => _days,
    };
    // "กำหนดเอง" with nothing ticked would silently become a one-off, which
    // is not what the user asked for — make them pick.
    if (_repeat == _Repeat.custom && days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกอย่างน้อย 1 วัน')),
      );
      return;
    }

    Navigator.of(context).pop(
      _EditResult.save(
        MedicationReminder(
          id: widget.existing?.id ?? 0,
          label: _label.text.trim(),
          hour: _time.hour,
          minute: _time.minute,
          days: days,
          enabled: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = {
      1: 'จ.',
      2: 'อ.',
      3: 'พ.',
      4: 'พฤ.',
      5: 'ศ.',
      6: 'ส.',
      7: 'อา.',
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ยกเลิก'),
                ),
                Text(
                  widget.existing == null ? 'ตั้งเวลาใหม่' : 'แก้ไขการเตือน',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton(onPressed: _submit, child: const Text('เสร็จสิ้น')),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _time.format(context),
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w700, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'แตะเพื่อเปลี่ยนเวลา',
                      style: TextStyle(
                          fontSize: 12, color: OnboardingColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final option in _Repeat.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: _repeat == option,
                    onSelected: (_) => setState(() {
                      _repeat = option;
                      if (option != _Repeat.custom) _days = {};
                    }),
                  ),
              ],
            ),
            if (_repeat == _Repeat.custom) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final entry in dayNames.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _days.contains(entry.key),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _days.add(entry.key);
                        } else {
                          _days.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'ชื่อยา หรือข้อความเตือน',
                hintText: 'เช่น ยาความดัน 1 เม็ด หลังอาหารเช้า',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(const _EditResult.remove()),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFC0392B)),
                  label: const Text('ลบการเตือนนี้',
                      style: TextStyle(color: Color(0xFFC0392B))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Repeat {
  once('ดังครั้งเดียว'),
  everyDay('ทุกวัน'),
  custom('กำหนดเอง');

  const _Repeat(this.label);
  final String label;
}

/// Says out loud what the OS is doing with our reminders.
///
/// Only appears when something is actually wrong, so a working setup stays
/// uncluttered — but when nothing fires, this is the difference between
/// "permission refused" and "the alarm was never registered", which need
/// completely different fixes.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.reminderCount});

  final NotificationStatus? status;
  final int reminderCount;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    if (status == null) return const SizedBox.shrink();

    final blocked = status.notificationsEnabled == false;
    final enabledButUnscheduled = !blocked &&
        reminderCount > 0 &&
        status.scheduledCount == 0;

    if (!blocked && !enabledButUnscheduled) return const SizedBox.shrink();

    final message = blocked
        ? 'ระบบปิดกั้นการแจ้งเตือนของแอปนี้อยู่ จึงจะไม่มีเสียงเตือนแม้ตั้งเวลาไว้\n\n'
            'เปิดที่ ตั้งค่า > แอป > MediGo > การแจ้งเตือน'
        : 'ตั้งเวลาไว้ $reminderCount รายการ แต่ระบบไม่ได้รับนาฬิกาไว้เลย\n\n'
            'มักเกิดจากสิทธิ์ "การปลุกและการเตือนความจำ" ยังไม่ได้เปิด '
            'หรือเครื่องปิดการทำงานเบื้องหลังของแอปไว้';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D6A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFB26A00), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF7A4A00)),
            ),
          ),
        ],
      ),
    );
  }
}
