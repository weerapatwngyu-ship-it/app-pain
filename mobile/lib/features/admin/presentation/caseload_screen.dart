import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../symptom_tracking/domain/entities/symptom_category.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../shared/format/thai_date.dart';
import '../../medication/data/medication_list_repository.dart';
import '../../medication/presentation/medication_edit_sheet.dart';
import '../data/caseload_repository.dart';
import '../../../core/i18n/app_locale.dart';

/// Every patient in the system, for clinical staff.
///
/// Read-only on purpose: staff can see a patient's medication and symptom
/// history, but changing a prescription still requires being that patient's
/// assigned provider (enforced by RLS, not by hiding buttons).
class CaseloadScreen extends StatefulWidget {
  const CaseloadScreen({
    super.key,
    required this.repository,
    this.chatRepository,
    this.doctorId,
    this.medicationRepository,
  });

  final CaseloadRepository repository;

  /// Set only when a doctor is viewing. An admin browsing the caseload has no
  /// listing of their own to send from, so they get the read-only screen and
  /// no message button rather than one that would fail at insert.
  final ChatRepository? chatRepository;
  final String? doctorId;

  /// Passed through to the record screen, where prescribing happens. Null
  /// hides the action rather than showing one the viewer cannot complete.
  final MedicationListRepository? medicationRepository;

  @override
  State<CaseloadScreen> createState() => _CaseloadScreenState();
}

class _CaseloadScreenState extends State<CaseloadScreen> {
  late Future<List<CaseloadPatient>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.patients();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.patients());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(t('ผู้ป่วยทั้งหมด', 'All patients'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: t('ค้นหาชื่อผู้ป่วย', 'Search patient name'),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: OnboardingColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: OnboardingColors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CaseloadPatient>>(
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
                          Text('โหลดรายชื่อไม่สำเร็จ: ${snapshot.error}',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton(
                              onPressed: _reload, child: const Text('ลองอีกครั้ง')),
                        ],
                      ),
                    ),
                  );
                }
                final all = snapshot.data ?? const <CaseloadPatient>[];
                final patients = _query.isEmpty
                    ? all
                    : all.where((p) => p.name.toLowerCase().contains(_query)).toList();

                if (patients.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        all.isEmpty
                            ? t('ยังไม่มีผู้ป่วยในระบบ', 'No patients yet')
                            : t('ไม่พบผู้ป่วยที่ตรงกับ "$_query"', 'No patients match "$_query"'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OnboardingColors.textMuted),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    itemCount: patients.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: OnboardingColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final patient = patients[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFDCEBE6),
                          child: Icon(Icons.person, color: OnboardingColors.teal),
                        ),
                        title: Text(patient.name),
                        subtitle: Text(
                          [
                            t('อายุ ${patient.age} ปี', '${patient.age} years old'),
                            // genderLabel, not the raw column: the database
                            // stores 'female'/'male', which is not what a Thai
                            // clinician should be reading off a caseload.
                            if (patient.genderLabel != null)
                              patient.genderLabel!,
                            if (patient.primaryCondition != null)
                              patient.primaryCondition!,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PatientRecordScreen(
                              medicationRepository: widget.medicationRepository,
                              patient: patient,
                              repository: widget.repository,
                              chatRepository: widget.chatRepository,
                              doctorId: widget.doctorId,
                            ),
                          ),
                        ),
                      );
                    },
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

class PatientRecordScreen extends StatefulWidget {
  const PatientRecordScreen({
    super.key,
    required this.patient,
    required this.repository,
    this.chatRepository,
    this.doctorId,
    this.medicationRepository,
  });

  final CaseloadPatient patient;
  final CaseloadRepository repository;
  final ChatRepository? chatRepository;
  final String? doctorId;

  /// Null for a viewer who may read the record but not prescribe — the
  /// prescribe action is hidden rather than shown and refused.
  final MedicationListRepository? medicationRepository;

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  late Future<PatientRecord> _future;
  bool _opening = false;

  /// The freshest copy of the patient this screen has seen.
  ///
  /// [PatientRecordScreen.patient] is the row the caseload list happened to
  /// hold when it was last pulled, which can be hours old. Everything that
  /// depends on the details — the allergy check when prescribing, above all —
  /// reads this instead.
  late CaseloadPatient _patient;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _future = _load();
  }

  Future<PatientRecord> _load() async {
    final record = await widget.repository.record(widget.patient);
    // No setState: returning from this future is what rebuilds the tree, and
    // calling it here would schedule a second build for the same change.
    _patient = record.patient;
    return record;
  }

  bool get _canPrescribe => widget.medicationRepository != null;

  /// Ends a course of treatment. The row stays, so the record still shows the
  /// drug was prescribed, what was taken, and when it stopped.
  ///
  /// Two dates on offer because "the patient has recovered" and "finish the
  /// course today" are different instructions, and only the doctor knows which
  /// one they mean. Stopping as of yesterday takes today's remaining doses off
  /// the patient's schedule immediately; stopping today leaves them standing.
  Future<void> _stop(PrescriptionSummary prescription) async {
    final medicationRepository = widget.medicationRepository;
    if (medicationRepository == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('หยุด ${prescription.medicationName}',
            'Stop ${prescription.medicationName}')),
        content: Text(t(
          'ประวัติการกินยาที่บันทึกไว้จะยังอยู่ครบ\n\n'
              'หยุดทันที — ยาหายจากตารางของผู้ป่วยเลย รวมมื้อที่เหลือของวันนี้\n'
              'หยุดวันนี้ — มื้อที่เหลือของวันนี้ยังกินตามเดิม แล้วหยุดพรุ่งนี้',
          'The dose history already recorded is kept in full.\n\n'
              'Stop now — it leaves the schedule immediately, including the '
              'doses left today.\n'
              'Stop today — the doses left today stand, then it stops tomorrow.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('today'),
            child: Text(t('หยุดวันนี้', 'Stop today')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('now'),
            child: Text(t('หยุดทันที', 'Stop now')),
          ),
        ],
      ),
    );
    if (choice == null) return;

    final endDate = choice == 'now'
        ? DateTime.now().subtract(const Duration(days: 1))
        : DateTime.now();
    await _writeMedication(
      () => medicationRepository.stop(prescription.id, endDate: endDate),
      t('หยุด ${prescription.medicationName} แล้ว',
          'Stopped ${prescription.medicationName}'),
    );
  }

  /// For an order written by mistake. It destroys the dose history along with
  /// the prescription, which is why it is worded as a mistake rather than as a
  /// way to end treatment.
  Future<void> _delete(PrescriptionSummary prescription) async {
    final medicationRepository = widget.medicationRepository;
    if (medicationRepository == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('ลบ ${prescription.medicationName}',
            'Delete ${prescription.medicationName}')),
        content: Text(t(
          'ใช้เมื่อสั่งผิดเท่านั้น\n\n'
              'การลบจะลบประวัติการกินยาของรายการนี้ทั้งหมดไปด้วย และกู้คืนไม่ได้ '
              'ถ้าต้องการจบการรักษา ให้ใช้ "หยุดยา" ซึ่งเก็บประวัติไว้',
          'Only for an order entered by mistake.\n\n'
              'Deleting also removes every dose recorded against it, and cannot '
              'be undone. To end treatment use "Stop", which keeps the history.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('ลบทิ้ง', 'Delete'),
                style: const TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _writeMedication(
      () => medicationRepository.remove(prescription.id),
      t('ลบ ${prescription.medicationName} แล้ว',
          'Deleted ${prescription.medicationName}'),
    );
  }

  Future<void> _writeMedication(
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!mounted) return;
      setState(() => _future = _load());
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } on StateError catch (e) {
      // Already worded for a clinician by the repository — a refusal here
      // means this doctor is no longer in charge of this patient.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyError(e,
            whileDoing: t('ทำรายการไม่สำเร็จ', 'That did not work'))),
      ));
    }
  }

  bool get _canMessage =>
      widget.chatRepository != null && widget.doctorId != null;

  Future<void> _message() async {
    final chat = widget.chatRepository;
    final doctorId = widget.doctorId;
    if (chat == null || doctorId == null || _opening) return;

    setState(() => _opening = true);
    try {
      // Reuses the patient-side call: unique (patient_id, doctor_id) means
      // starting from here continues the thread the patient may already have
      // open rather than forking a second one.
      final conversation = await chat.openConversation(
        patientId: widget.patient.id,
        doctorId: doctorId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversation.id,
            title: _patient.name,
            subtitle: 'ผู้ป่วย',
            repository: chat,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดแชทไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Prescribes for this patient.
  ///
  /// Reuses the medication form the patient once had, handed the recorded
  /// allergies — the warning it carries belongs here more than it did there,
  /// since this is where the drug is actually chosen.
  Future<void> _prescribe() async {
    final medicationRepository = widget.medicationRepository;
    if (medicationRepository == null) return;

    final draft = await showModalBottomSheet<MedicationDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MedicationEditSheet(
        allergies: _patient.drugAllergies,
        title: t('สั่งยาให้ ${_patient.name}', 'Prescribe for ${_patient.name}'),
      ),
    );
    if (draft == null) return;

    try {
      await medicationRepository.add(
        patientId: widget.patient.id,
        name: draft.name,
        dosage: draft.dosage,
        frequency: draft.frequency,
        startDate: draft.startDate,
        endDate: draft.endDate,
        times: draft.times,
        // Written as the clinician's, which is what makes it read-only to the
        // patient and marks it "จากแพทย์" on their list.
        bySelf: false,
      );
      if (!mounted) return;
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('สั่ง ${draft.name} ให้ผู้ป่วยแล้ว', 'Prescribed ${draft.name}'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(
            e,
            whileDoing: t('สั่งยาไม่สำเร็จ', 'Could not prescribe'),
            // A doctor takes charge of a patient by opening a conversation
            // with them; until then the record is read-only. Saying that is
            // more use than "no permission", because it is something the
            // doctor can do from this very screen.
            deniedMessage: t(
              'ต้องเริ่มสนทนากับผู้ป่วยรายนี้ก่อน '
                  'จึงจะสั่งยาให้ได้ (กดปุ่ม ส่งข้อความ)',
              'Start a conversation with this patient first, '
                  'before prescribing (press Message).',
            ),
          )),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_patient.name),
        actions: [
          if (widget.medicationRepository != null)
            IconButton(
              onPressed: _prescribe,
              icon: const Icon(Icons.medication_outlined),
              tooltip: t('สั่งยา', 'Prescribe'),
            ),
        ],
      ),
      floatingActionButton: _canMessage
          ? FloatingActionButton.extended(
              onPressed: _opening ? null : _message,
              backgroundColor: OnboardingColors.teal,
              icon: _opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: Text(t('ส่งข้อความ', 'Message'),
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: FutureBuilder<PatientRecord>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final record = snapshot.data!;
          final active = record.prescriptions.where((p) => p.isActive).toList();
          final past = record.prescriptions.where((p) => !p.isActive).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            children: [
              _Header(patient: record.patient, openAlerts: record.openAlerts),
              const SizedBox(height: 24),
              _SectionTitle(t('ข้อมูลผู้ป่วย', 'Patient details')),
              _ProfileCard(patient: record.patient),
              const SizedBox(height: 24),
              _SectionTitle(t('ยาที่ใช้อยู่', 'Current medication')),
              if (active.isEmpty)
                _Empty(t('ไม่มีรายการยาที่ใช้อยู่', 'No current medication'))
              else
                ...active.map((p) => _PrescriptionTile(
                      prescription: p,
                      // Null when this viewer may read but not prescribe, so
                      // the actions are absent rather than shown and refused.
                      onStop: _canPrescribe ? () => _stop(p) : null,
                      onDelete: _canPrescribe ? () => _delete(p) : null,
                    )),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle(t('ยาที่หยุดแล้ว', 'Stopped medication')),
                ...past.map((p) => _PrescriptionTile(
                      prescription: p,
                      faded: true,
                      onDelete: _canPrescribe ? () => _delete(p) : null,
                    )),
              ],
              const SizedBox(height: 24),
              _SectionTitle(t('การกินยา 7 วันล่าสุด', 'Adherence, last 7 days')),
              _AdherenceCard(
                adherence: record.adherence,
                logs: record.doseLogs,
              ),
              const SizedBox(height: 24),
              _SectionTitle(t('บันทึกอาการล่าสุด', 'Recent symptom entries')),
              if (record.symptomLogs.isEmpty)
                _Empty(t('ผู้ป่วยยังไม่ได้บันทึกอาการ', 'The patient has not logged any symptoms'))
              else
                ...record.symptomLogs.map((s) => _SymptomTile(entry: s)),
              const SizedBox(height: 24),
              Text(
                t('หน้านี้แสดงข้อมูลอย่างเดียว การแก้ใบสั่งยาต้องเป็นแพทย์ที่ดูแลผู้ป่วยรายนี้', 'This screen is read-only. Changing a prescription requires being this patient’s provider.'),
                style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.patient, required this.openAlerts});

  final CaseloadPatient patient;
  final int openAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(patient.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            [
              t('อายุ ${patient.age} ปี', '${patient.age} years old'),
              if (patient.genderLabel != null) patient.genderLabel!,
              if (patient.bloodType != null) 'กรุ๊ปเลือด ${patient.bloodType}',
            ].join(' · '),
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          ),
          if (patient.primaryCondition != null) ...[
            const SizedBox(height: 4),
            Text('โรคประจำตัว: ${patient.primaryCondition}',
                style: const TextStyle(fontSize: 13)),
          ],
          // Above the prescriptions and styled like a warning, because this is
          // the one line on the screen that changes what may be prescribed.
          if (patient.drugAllergies.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AllergyBanner(
              icon: Icons.dangerous_outlined,
              text: 'แพ้ยา: ${patient.drugAllergies.join(', ')}',
              background: const Color(0xFFFDECEC),
              border: const Color(0xFFE79A9A),
              foreground: const Color(0xFFC0392B),
            ),
          ],
          // Amber rather than red: it matters, and it is not the line that
          // stops a prescription — keeping them the same colour would make
          // the drug allergy easier to skim past.
          if (patient.foodAllergies.isNotEmpty) ...[
            const SizedBox(height: 8),
            _AllergyBanner(
              icon: Icons.restaurant_outlined,
              text: 'แพ้อาหาร: ${patient.foodAllergies.join(', ')}',
              background: const Color(0xFFFFF4E5),
              border: const Color(0xFFF0D6A8),
              foreground: const Color(0xFF7A4A00),
            ),
          ],
          if (openAlerts > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFC0392B)),
                const SizedBox(width: 6),
                Text(
                  t('มีการแจ้งเตือนค้างอยู่ $openAlerts รายการ', '$openAlerts open alerts'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC0392B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What the patient did with the doses that came due this week.
///
/// The counts are the point, not the list: a doctor asking "is this being
/// taken" wants the shape of the week before they want individual entries.
/// "ไม่ได้บันทึก" is shown as its own number rather than folded into a
/// percentage, because a dose with no log means the app was not answered —
/// which is not the same as the patient saying they skipped it, and only the
/// doctor can judge which one it really was.
class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.adherence, required this.logs});

  final DoseAdherence adherence;
  final List<DoseLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (!adherence.hasSchedule) {
      return _Empty(t('ยังไม่มียาที่ต้องกินตามเวลาในช่วง 7 วันนี้', 'Nothing was due on a schedule in the last 7 days'));
    }

    final rate = adherence.takenRate;
    final recent = logs.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                rate == null ? '—' : '${(rate * 100).round()}%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: _rateColor(rate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'กินตามเวลา ${adherence.taken} จาก ${adherence.expected} ครั้ง'
                  'ที่ต้องกิน',
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: OnboardingColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Tally(
                label: t('กินแล้ว', 'Taken'),
                count: adherence.taken,
                color: OnboardingColors.teal,
              ),
              _Tally(
                label: t('ข้าม', 'Skipped'),
                count: adherence.skipped,
                color: const Color(0xFFB26A00),
              ),
              _Tally(
                label: t('ไม่ได้บันทึก', 'No answer'),
                count: adherence.unanswered,
                color: const Color(0xFFC0392B),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(color: OnboardingColors.border, height: 20),
            for (final log in recent) _DoseLogRow(log: log),
          ],
        ],
      ),
    );
  }

  /// Deliberately coarse. A number this rough should not be read to the
  /// percentage point, and three bands is what a doctor acts on: fine,
  /// worth asking about, worth calling about.
  static Color _rateColor(double? rate) {
    if (rate == null) return OnboardingColors.textMuted;
    if (rate >= 0.8) return OnboardingColors.teal;
    if (rate >= 0.5) return const Color(0xFFB26A00);
    return const Color(0xFFC0392B);
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11.5, color: OnboardingColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DoseLogRow extends StatelessWidget {
  const _DoseLogRow({required this.log});

  final DoseLogEntry log;

  @override
  Widget build(BuildContext context) {
    final taken = log.status == 'taken';
    final at = log.actionedAt ?? log.scheduledAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            taken ? Icons.check_circle : Icons.remove_circle_outline,
            size: 16,
            color: taken ? OnboardingColors.teal : const Color(0xFFB26A00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.medicationName.isEmpty ? 'ยา' : log.medicationName,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${thaiDate(at)} ${_clock(at)}',
            style: const TextStyle(
                fontSize: 12, color: OnboardingColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}';
  }
}

class _AllergyBanner extends StatelessWidget {
  const _AllergyBanner({
    required this.icon,
    required this.text,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The patient's own particulars, as a chart's front page.
///
/// Every row is present whether or not it has a value: "ยังไม่ได้ระบุ" is a
/// clinical answer and a blank space is not. A doctor who cannot see that
/// nothing was recorded for allergies has no way to tell it apart from a
/// patient who recorded none.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.patient});

  final CaseloadPatient patient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OnboardingColors.border),
      ),
      child: Column(
        children: [
          _ProfileRow(label: t('ชื่อ-นามสกุล', 'Name'), value: patient.name),
          _ProfileRow(
            label: t('วันเกิด', 'Date of birth'),
            value: '${thaiDateFull(patient.birthDate)} '
                '(อายุ ${patient.age} ปี)',
            note: patient.birthDateUnconfirmed
                ? t('ค่าเริ่มต้นของระบบ — ผู้ป่วยอาจยังไม่ได้กรอกวันเกิดจริง', 'System default — the patient may not have entered a real date of birth')
                : null,
          ),
          _ProfileRow(label: t('เพศ', 'Gender'), value: patient.genderLabel),
          _ProfileRow(label: t('กรุ๊ปเลือด', 'Blood type'), value: patient.bloodType),
          _ProfileRow(
            label: t('น้ำหนัก / ส่วนสูง', 'Weight / height'),
            value: _measurements(),
          ),
          _ProfileRow(
            label: t('โรคประจำตัว', 'Ongoing conditions'),
            value: patient.primaryCondition,
          ),
          _ProfileRow(
            label: t('แพ้ยา', 'Drug allergies'),
            value: patient.drugAllergies.isEmpty
                ? null
                : patient.drugAllergies.join(', '),
            emphasis: patient.drugAllergies.isNotEmpty,
          ),
          _ProfileRow(
            label: t('แพ้อาหาร', 'Food allergies'),
            value: patient.foodAllergies.isEmpty
                ? null
                : patient.foodAllergies.join(', '),
            last: true,
          ),
        ],
      ),
    );
  }

  String? _measurements() {
    final parts = [
      if (patient.weightKg != null) '${_number(patient.weightKg!)} กก.',
      if (patient.heightCm != null) '${_number(patient.heightCm!)} ซม.',
    ];
    if (parts.isEmpty) return null;
    final bmi = patient.bmi;
    if (bmi != null) parts.add('BMI ${bmi.toStringAsFixed(1)}');
    return parts.join(' · ');
  }

  /// Drops a trailing `.0` so 65 kilos does not read as 65.0.
  static String _number(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.note,
    this.emphasis = false,
    this.last = false,
  });

  final String label;

  /// Null means the patient has not filled this in, which is shown as such
  /// rather than left blank.
  final String? value;

  final String? note;
  final bool emphasis;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: OnboardingColors.border),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: OnboardingColors.textMuted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missing ? t('ยังไม่ได้ระบุ', 'Not recorded') : value!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                    fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                    color: missing
                        ? OnboardingColors.textMuted
                        : emphasis
                            ? const Color(0xFFC0392B)
                            : OnboardingColors.text,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    note!,
                    style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Color(0xFFB26A00)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted)),
      );
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    this.faded = false,
    this.onStop,
    this.onDelete,
  });

  final PrescriptionSummary prescription;
  final bool faded;

  /// Both null for a viewer who may read the record but not change it.
  final VoidCallback? onStop;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: OnboardingColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.medication_outlined, color: OnboardingColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prescription.medicationName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      prescription.dosage,
                      prescription.frequency,
                      // The stop date, once there is one: a list of stopped
                      // medication with no dates on it cannot answer "when did
                      // they come off this".
                      if (prescription.endDate != null)
                        t('ถึง ${thaiOrEnglishDate(prescription.endDate!)}',
                            'until ${thaiOrEnglishDate(prescription.endDate!)}'),
                    ].where((part) => part.trim().isNotEmpty).join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: OnboardingColors.textMuted),
                  ),
                ],
              ),
            ),
            if (onStop != null || onDelete != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 20, color: OnboardingColors.textMuted),
                tooltip: t('จัดการยานี้', 'Manage this medication'),
                onSelected: (value) {
                  if (value == 'stop') onStop?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (onStop != null)
                    PopupMenuItem(
                      value: 'stop',
                      child: Text(t('หยุดยา', 'Stop')),
                    ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        t('ลบ (สั่งผิด)', 'Delete (entered by mistake)'),
                        style: const TextStyle(color: Color(0xFFC0392B)),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SymptomTile extends StatelessWidget {
  const _SymptomTile({required this.entry});

  final SymptomEntry entry;

  @override
  Widget build(BuildContext context) {
    final score = entry.painScore;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              '${entry.recordedAt.day}/${entry.recordedAt.month} '
              '${entry.recordedAt.hour.toString().padLeft(2, '0')}:'
              '${entry.recordedAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              entry.category == null
                  ? 'ไม่ระบุหมวด'
                  : symptomCategoryLabel(entry.category!),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: score >= 7
                    ? const Color(0xFFFDE7E4)
                    : score >= 4
                        ? const Color(0xFFFFF4E5)
                        : const Color(0xFFE3F3EF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ปวด $score',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: score >= 7
                      ? const Color(0xFFC0392B)
                      : score >= 4
                          ? const Color(0xFFB26A00)
                          : OnboardingColors.teal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
