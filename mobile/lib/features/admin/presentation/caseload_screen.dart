import 'package:flutter/material.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../symptom_tracking/domain/entities/symptom_category.dart';
import '../data/caseload_repository.dart';

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
  });

  final CaseloadRepository repository;

  /// Set only when a doctor is viewing. An admin browsing the caseload has no
  /// listing of their own to send from, so they get the read-only screen and
  /// no message button rather than one that would fail at insert.
  final ChatRepository? chatRepository;
  final String? doctorId;

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
      appBar: AppBar(title: const Text('ผู้ป่วยทั้งหมด')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อผู้ป่วย',
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
                            ? 'ยังไม่มีผู้ป่วยในระบบ'
                            : 'ไม่พบผู้ป่วยที่ตรงกับ "$_query"',
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
                            'อายุ ${patient.age} ปี',
                            if (patient.gender != null) patient.gender!,
                            if (patient.primaryCondition != null)
                              patient.primaryCondition!,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PatientRecordScreen(
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
  });

  final CaseloadPatient patient;
  final CaseloadRepository repository;
  final ChatRepository? chatRepository;
  final String? doctorId;

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  late Future<PatientRecord> _future;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.record(widget.patient);
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
            title: widget.patient.name,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.patient.name)),
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
              label: const Text('ส่งข้อความ',
                  style: TextStyle(color: Colors.white)),
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
              const _SectionTitle('ยาที่ใช้อยู่'),
              if (active.isEmpty)
                const _Empty('ไม่มีรายการยาที่ใช้อยู่')
              else
                ...active.map((p) => _PrescriptionTile(prescription: p)),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionTitle('ยาที่หยุดแล้ว'),
                ...past.map((p) => _PrescriptionTile(prescription: p, faded: true)),
              ],
              const SizedBox(height: 24),
              const _SectionTitle('บันทึกอาการล่าสุด'),
              if (record.symptomLogs.isEmpty)
                const _Empty('ผู้ป่วยยังไม่ได้บันทึกอาการ')
              else
                ...record.symptomLogs.map((s) => _SymptomTile(entry: s)),
              const SizedBox(height: 24),
              const Text(
                'หน้านี้แสดงข้อมูลอย่างเดียว การแก้ใบสั่งยาต้องเป็นแพทย์ที่ดูแลผู้ป่วยรายนี้',
                style: TextStyle(fontSize: 12, color: OnboardingColors.textMuted),
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
              'อายุ ${patient.age} ปี',
              if (patient.gender != null) patient.gender!,
            ].join(' · '),
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          ),
          if (patient.primaryCondition != null) ...[
            const SizedBox(height: 4),
            Text('โรคประจำตัว: ${patient.primaryCondition}',
                style: const TextStyle(fontSize: 13)),
          ],
          if (openAlerts > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFC0392B)),
                const SizedBox(width: 6),
                Text(
                  'มีการแจ้งเตือนค้างอยู่ $openAlerts รายการ',
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
  const _PrescriptionTile({required this.prescription, this.faded = false});

  final PrescriptionSummary prescription;
  final bool faded;

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
                    '${prescription.dosage} · ${prescription.frequency}',
                    style: const TextStyle(
                        fontSize: 12, color: OnboardingColors.textMuted),
                  ),
                ],
              ),
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
