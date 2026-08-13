import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../profile/data/patient_profile_repository.dart';
import '../data/medication_list_repository.dart';
import '../domain/entities/medication.dart';
import 'medication_edit_sheet.dart';
import '../../../core/errors/friendly_error.dart';

/// The patient's medication list — what they are taking, and when.
///
/// This exists because nothing could put a medication into the app at all:
/// prescriptions were writable by clinical staff only and no screen ever did,
/// so every patient's "today" was permanently empty and the reminders had
/// nothing to remind about.
class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({
    super.key,
    required this.patientId,
    required this.repository,
    required this.profileRepository,
  });

  final String patientId;
  final MedicationListRepository repository;

  /// Read for the allergy list, which is checked against the name being
  /// added.
  final PatientProfileRepository profileRepository;

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  late Future<List<Medication>> _future;
  List<String> _allergies = const [];

  @override
  void initState() {
    super.initState();
    _future = widget.repository.forPatient(widget.patientId);
    _loadAllergies();
  }

  Future<void> _loadAllergies() async {
    try {
      final profile = await widget.profileRepository.fetch(widget.patientId);
      if (mounted) setState(() => _allergies = profile.drugAllergies);
    } catch (_) {
      // The list still works without it; the warning simply won't appear.
      // Blocking the screen on this would be worse than losing the check.
    }
  }

  void _reload() {
    setState(() {
      _future = widget.repository.forPatient(widget.patientId);
    });
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<MedicationDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MedicationEditSheet(allergies: _allergies),
    );
    if (result == null) return;

    try {
      await widget.repository.add(
        patientId: widget.patientId,
        name: result.name,
        dosage: result.dosage,
        frequency: result.frequency,
        startDate: result.startDate,
        endDate: result.endDate,
        times: result.times,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เพิ่ม ${result.name} แล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, whileDoing: 'เพิ่มยาไม่สำเร็จ'))));
    }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มยา'),
      ),
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
                'ยังไม่มียาในรายการ\n\nกด "เพิ่มยา" เพื่อใส่ยาที่กินอยู่ '
                'แล้วระบบจะเตือนตามเวลาที่ตั้งไว้',
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
