import 'package:flutter/material.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/notification/notification_service.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../medication/domain/entities/dose_log.dart';
import '../../medication/domain/medication_repository.dart';
import '../data/reminder_repository.dart';
import '../data/system_alarm.dart';
import '../domain/entities/medication_reminder.dart';
import '../../../core/errors/friendly_error.dart';

/// "เตือนกินยา" — the alarm list, laid out like the phone's own clock app so
/// it needs no explaining: big time, when it repeats, a switch.
///
/// Most of the rows are not the patient's own: they are generated from the
/// dose schedule the doctor prescribed, refreshed each time this opens, and
/// marked "จากแพทย์". They can be switched off but not retimed or deleted —
/// the time belongs to the prescription, and letting it be edited here would
/// produce an alarm that disagrees with the record without either side knowing.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    required this.repository,
    required this.medicationRepository,
    required this.patientId,
  });

  final ReminderRepository repository;

  /// Read only to re-derive the generated reminders from today's doses.
  final MedicationRepository medicationRepository;
  final String patientId;

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

      // Doses answered straight from a notification, before the sync below
      // can delete the reminder they were answered against. The home screen
      // does this too — whichever the patient opens first wins, and draining
      // is destructive so the second finds nothing left to do.
      try {
        for (final dose in await widget.repository.drainTakenDoses()) {
          await widget.medicationRepository.logDose(DoseLog(
            scheduleId: dose.scheduleId,
            scheduledAt: dose.at,
            actionedAt: dose.at,
            status: DoseLogStatus.taken,
          ));
        }
      } catch (error) {
        debugPrint('drainTakenDoses failed: $error');
      }

      // Re-derive the doctor's reminders before listing. Opening this screen
      // is the moment the patient asks "what will I be reminded of", so it is
      // also the moment to make sure the answer matches the current
      // prescription rather than the one in force when they last looked.
      try {
        final schedule = await widget.medicationRepository
            .todaySchedule(widget.patientId);
        await widget.repository.syncFromSchedule(schedule);
      } catch (error) {
        // Offline, most likely. The stored reminders are still the last known
        // schedule and still ring, which is far better than an empty list.
        debugPrint('syncFromSchedule failed: $error');
      }

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
        _error = friendlyError(e,
            whileDoing: t('โหลดการเตือนไม่สำเร็จ', 'Could not load reminders'));
        _loading = false;
      });
    }
  }

  /// Hands one reminder to the phone's clock app, which unlike this app is
  /// guaranteed to be allowed to ring.
  Future<void> _sendToClock(MedicationReminder reminder) async {
    try {
      final result = await SystemAlarm.create(reminder);
      if (!mounted) return;
      if (result.launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(
              'เปิดแอปนาฬิกาแล้ว — กดบันทึกในแอปนาฬิกาเพื่อยืนยัน',
              'Clock app opened — press save there to confirm the alarm',
            )),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      final detail = StringBuffer(
        result.resolvedCount == 0
            ? 'เครื่องนี้ไม่มีแอปนาฬิกาที่รับคำสั่งนี้ได้'
            : 'พบแอปนาฬิกา ${result.resolvedCount} แอป แต่เปิดไม่ได้',
      );
      for (final attempt in result.attempts) {
        detail.write('\n\n$attempt');
      }
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t('ตั้งนาฬิกาปลุกไม่สำเร็จ', 'Could not set the alarm')),
          content: SingleChildScrollView(
            child: SelectableText(detail.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('ปิด', 'Close')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, whileDoing: t('ส่งไปนาฬิกาไม่สำเร็จ', 'Could not hand it to the clock app')))));
    }
  }

  Future<void> _edit([MedicationReminder? existing]) async {
    // A generated reminder has no editable time of its own — it is a copy of
    // the prescription. Saying so beats opening a form whose "เสร็จสิ้น" would
    // be undone by the next sync.
    if (existing != null && existing.fromDoctor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(
            'เวลานี้แพทย์เป็นผู้กำหนด แก้ไขเองไม่ได้ '
                'หากต้องการเปลี่ยน ปรึกษาแพทย์ในแอป',
            'Your doctor set this time, so it cannot be edited here. '
                'Message them in the app to change it.',
          )),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

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
        final saved = await widget.repository.save(result.reminder!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(saved.countdownLabel())),
          );
        }
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, whileDoing: t('บันทึกไม่สำเร็จ', 'Could not save')))));
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
          .showSnackBar(SnackBar(content: Text(friendlyError(e, whileDoing: t('เปลี่ยนสถานะไม่สำเร็จ', 'Could not change that')))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(t('เตือนกินยา', 'Medication reminders'))),
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
                child: Text(t('ลองอีกครั้ง', 'Try again')),
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
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              t(
                'ยังไม่มีการเตือน\n\n'
                    'เมื่อแพทย์สั่งยาให้ ระบบจะตั้งเวลาเตือนตามที่แพทย์กำหนดให้เอง '
                    'ไม่ต้องตั้งเอง\n\n'
                    'หรือกดปุ่ม + เพื่อเพิ่มการเตือนของตัวเอง',
                'No reminders yet\n\n'
                    'When your doctor prescribes something, the app sets the '
                    'reminders for you at the times they chose.\n\n'
                    'Or press + to add one of your own.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: OnboardingColors.textMuted, height: 1.6),
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
              onSendToClock: () => _sendToClock(reminder),
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
    required this.onSendToClock,
  });

  final MedicationReminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSendToClock;

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
                    if (reminder.fromDoctor) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t('จากแพทย์ · ตั้งให้อัตโนมัติ',
                              'From your doctor · set automatically'),
                          style: const TextStyle(
                              fontSize: 11, color: OnboardingColors.teal),
                        ),
                      ),
                    ],
                    if (reminder.enabled) ...[
                      const SizedBox(height: 2),
                      Text(
                        reminder.countdownLabel(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: OnboardingColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: t('ตั้งในนาฬิกาปลุกของเครื่อง',
                    "Add to the phone's clock app"),
                icon: const Icon(Icons.alarm_add, color: OnboardingColors.teal),
                onPressed: onSendToClock,
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

  /// Same reminder the user is about to save, asked when it would next fire.
  /// Built from the live form rather than the saved row, so choosing a time
  /// that has already passed today immediately reads "อีก 23 ชั่วโมง ..."
  /// instead of looking like nothing happened.
  String _previewCountdown() {
    final days = switch (_repeat) {
      _Repeat.once => <int>{},
      _Repeat.everyDay => {1, 2, 3, 4, 5, 6, 7},
      _Repeat.custom => _days,
    };
    if (_repeat == _Repeat.custom && days.isEmpty) return t('เลือกวันที่ต้องการเตือน', 'Choose which days to be reminded');
    return MedicationReminder(
      id: 0,
      label: '',
      hour: _time.hour,
      minute: _time.minute,
      days: days,
      enabled: true,
    ).countdownLabel();
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
        SnackBar(content: Text(t('เลือกอย่างน้อย 1 วัน', 'Pick at least one day'))),
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
                  child: Text(t('ยกเลิก', 'Cancel')),
                ),
                Text(
                  widget.existing == null ? t('ตั้งเวลาใหม่', 'New reminder') : t('แก้ไขการเตือน', 'Edit reminder'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton(onPressed: _submit, child: Text(t('เสร็จสิ้น', 'Done'))),
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
                    Text(
                      _previewCountdown(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: OnboardingColors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t('แตะเพื่อเปลี่ยนเวลา', 'Tap to change the time'),
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
                labelText: t('ชื่อยา หรือข้อความเตือน', 'Medication name or reminder text'),
                hintText: t('เช่น ยาความดัน 1 เม็ด หลังอาหารเช้า', 'e.g. 1 blood-pressure tablet after breakfast'),
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
                  label: Text(t('ลบการเตือนนี้', 'Delete this reminder'),
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
  once,
  everyDay,
  custom;

  /// A getter rather than a constructor argument: an enum constant is a const
  /// expression, and a translated label is decided at run time.
  String get label => switch (this) {
        _Repeat.once => t('ดังครั้งเดียว', 'Once'),
        _Repeat.everyDay => t('ทุกวัน', 'Every day'),
        _Repeat.custom => t('กำหนดเอง', 'Custom'),
      };
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
        ? t(
            'ระบบปิดกั้นการแจ้งเตือนของแอปนี้อยู่ จึงจะไม่มีเสียงเตือนแม้ตั้งเวลาไว้\n\n'
                'เปิดที่ ตั้งค่า > แอป > MediGo > การแจ้งเตือน',
            'Notifications are blocked for this app, so nothing will ring '
                'however it is set.\n\n'
                'Turn them on in Settings > Apps > MediGo > Notifications',
          )
        : t(
            'ตั้งเวลาไว้ $reminderCount รายการ แต่ระบบไม่ได้รับนาฬิกาไว้เลย\n\n'
                'มักเกิดจากสิทธิ์ "การปลุกและการเตือนความจำ" ยังไม่ได้เปิด '
                'หรือเครื่องปิดการทำงานเบื้องหลังของแอปไว้',
            '$reminderCount reminders are set, but the system is holding no '
                'alarms.\n\n'
                'Usually the "alarms and reminders" permission is off, or the '
                'phone is blocking the app from running in the background.',
          );

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
