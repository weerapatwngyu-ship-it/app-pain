import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/medication_list_repository.dart';
import '../domain/entities/medication.dart';
import '../../../core/errors/friendly_error.dart';

/// The patient's medication list — what they are taking, and when.
///
/// Read-only as far as adding goes: prescribing is the doctor's, and the
/// allergy check that used to live on the patient's own entry form moved with
/// it, to the screen where the person choosing the drug can act on it.
/// Medication a patient entered themselves before that change is still theirs
/// to stop or delete.
class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({
    super.key,
    required this.patientId,
    required this.repository,
  });

  final String patientId;
  final MedicationListRepository repository;

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  late Future<List<Medication>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.forPatient(widget.patientId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.forPatient(widget.patientId);
    });
  }


  Future<void> _confirmRemove(Medication medication) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(medication.name),
        content: const Text(
          'หยุดยา จะเก็บประวัติการกินไว้และไม่แสดงในรายการวันนี้อีก\n'
          'ลบออก จะลบทั้งรายการและประวัติการกินยานี้ทิ้ง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('stop'),
            child: const Text('หยุดยา'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('delete'),
            child: const Text('ลบออก', style: TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (choice == null) return;

    try {
      if (choice == 'stop') {
        await widget.repository.stop(medication.id);
      } else {
        await widget.repository.remove(medication.id);
      }
      if (!mounted) return;
      _reload();
    } on StateError catch (e) {
      // Thrown by the repository with a message already written for a patient
      // ("this can only be changed by whoever added it"), so it is shown as is.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, whileDoing: 'ทำรายการไม่สำเร็จ'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ยาของฉัน')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<List<Medication>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Message(friendlyError(snapshot.error!,
                  whileDoing: 'โหลดรายการยาไม่สำเร็จ'));
            }
            final all = snapshot.data ?? const <Medication>[];
            final active = all.where((m) => m.isActive).toList();
            final stopped = all.where((m) => !m.isActive).toList();

            if (all.isEmpty) {
              return const _Message(
                'ยังไม่มีรายการยา\n\n'
                'แพทย์จะเป็นผู้สั่งยาให้ผ่านระบบ '
                'เมื่อสั่งแล้วยาจะขึ้นที่นี่และแอปจะเตือนตามเวลาที่แพทย์กำหนด\n\n'
                'หากมียาที่กินอยู่ ปรึกษาแพทย์ในแอปเพื่อให้บันทึกให้',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final medication in active)
                  _MedicationCard(
                    medication: medication,
                    onManage: medication.enteredBySelf
                        ? () => _confirmRemove(medication)
                        : null,
                  ),
                if (stopped.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'หยุดแล้ว',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: OnboardingColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final medication in stopped)
                    _MedicationCard(medication: medication, faded: true),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    this.faded = false,
    this.onManage,
  });

  final Medication medication;
  final bool faded;
  /// Opens stop/delete. Null for a clinician's prescription, which the
  /// patient may read but not change.
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OnboardingColors.border),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      medication.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!medication.enteredBySelf)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'จากแพทย์',
                        style: TextStyle(
                            fontSize: 11, color: OnboardingColors.teal),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [medication.dosage, medication.frequency]
                    .where((part) => part.trim().isNotEmpty)
                    .join(' · '),
                style: const TextStyle(
                    fontSize: 13, color: OnboardingColors.textMuted),
              ),
              if (medication.times.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final time in medication.times)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: OnboardingColors.border),
                        ),
                        child: Text(time,
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
              if (onManage != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.more_horiz, size: 18),
                    label: const Text('หยุดยา / ลบ'),
                    style: TextButton.styleFrom(
                      foregroundColor: OnboardingColors.textMuted,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: OnboardingColors.textMuted, height: 1.6),
        ),
      ],
    );
  }
}
