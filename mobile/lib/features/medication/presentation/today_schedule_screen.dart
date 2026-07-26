import 'package:flutter/material.dart';

import '../domain/entities/dose_log.dart';
import '../domain/entities/dose_schedule_item.dart';
import '../domain/medication_repository.dart';
import '../domain/usecases/log_dose_usecase.dart';

class TodayScheduleScreen extends StatefulWidget {
  const TodayScheduleScreen({
    super.key,
    required this.patientId,
    required this.medicationRepository,
    required this.logDoseUseCase,
  });

  final String patientId;
  final MedicationRepository medicationRepository;
  final LogDoseUseCase logDoseUseCase;

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  late Future<List<DoseScheduleItem>> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = widget.medicationRepository.todaySchedule(widget.patientId);
  }

  Future<void> _logDose(DoseScheduleItem item, DoseLogStatus status) async {
    await widget.logDoseUseCase(DoseLog(
      scheduleId: item.scheduleId,
      scheduledAt: DateTime.now(),
      actionedAt: DateTime.now(),
      status: status,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('บันทึกแล้ว: ${item.medicationName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตารางยาวันนี้')),
      body: FutureBuilder<List<DoseScheduleItem>>(
        future: _scheduleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('โหลดตารางยาไม่สำเร็จ'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่มีรายการยาวันนี้'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(item.medicationName),
                  subtitle: Text('${item.dosage} · ${item.scheduledTime}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: 'กินยาแล้ว',
                        onPressed: () => _logDose(item, DoseLogStatus.taken),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: 'ข้าม',
                        onPressed: () => _logDose(item, DoseLogStatus.skipped),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
