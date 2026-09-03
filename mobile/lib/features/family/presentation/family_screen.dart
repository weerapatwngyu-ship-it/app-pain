import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/family_repository.dart';
import '../../admin/data/caseload_repository.dart';
import '../../admin/presentation/caseload_screen.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';

/// Family access, from both sides at once.
///
/// The same screen answers "who can see my record" and "whose records can I
/// see", because one person is usually both: the daughter who looks after her
/// mother is also a patient with her own medication. Splitting it into two
/// screens would mean the same person hunting through two menus for two halves
/// of one idea.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({
    super.key,
    required this.repository,
    required this.caseloadRepository,
  });

  final FamilyRepository repository;

  /// Opening a relative's record reuses the screen clinical staff read, with
  /// no medication repository passed — which is what hides prescribing.
  final CaseloadRepository caseloadRepository;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late Future<_FamilyView> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FamilyView> _load() async {
    // The code is minted on first read, so this call is also what creates it.
    final code = await widget.repository.myCode();
    final members = await widget.repository.members();
    final caringFor = await widget.repository.patientsICareFor();
    return _FamilyView(
      code: code,
      members: members,
      caringFor: caringFor,
      missedByPatient: await _countMissed(caringFor),
    );
  }

  /// How many doses each relative has missed in the last week.
  ///
  /// Read through the same record call the doctor's chart uses, rather than a
  /// query of its own. "Missed" is worked out by walking the schedule against
  /// the logs, and a second implementation of that rule here could disagree
  /// with the one on the chart — two different answers to the same question,
  /// on the screen a family opens because they are worried.
  ///
  /// Family lists are a handful of people, so fetching each is affordable;
  /// they are fetched together rather than one after another. A relative whose
  /// record fails to load is left out entirely, not recorded as zero.
  Future<Map<String, int>> _countMissed(List<FamilyPatient> relatives) async {
    final active = relatives.where((r) => !r.isPending).toList();
    if (active.isEmpty) return const {};

    final counted = await Future.wait(active.map((relative) async {
      try {
        final patient =
            await widget.caseloadRepository.patient(relative.patientId);
        final record = await widget.caseloadRepository.record(patient);
        return MapEntry(relative.patientId, record.missedDoses.length);
      } catch (_) {
        return null;
      }
    }));

    return {
      for (final entry in counted)
        if (entry != null) entry.key: entry.value,
    };
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(success)));
      _reload();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openJoinSheet() async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _JoinSheet(repository: widget.repository),
    );
    if (joined == true) _reload();
  }

  Future<void> _confirmRevoke(FamilyMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('นำ ${member.name} ออก', 'Remove ${member.name}')),
        content: Text(t(
          'เขาจะไม่เห็นข้อมูลสุขภาพ ยา และบันทึกอาการของคุณอีก '
              'และจะขอเข้าใหม่ได้ก็ต่อเมื่อคุณอนุมัติอีกครั้ง',
          'They will no longer see your health details, medication or symptom '
              'notes, and can only come back if you approve them again.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('นำออก', 'Remove'),
                style: const TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => widget.repository.revoke(member.userId),
        t('นำ ${member.name} ออกแล้ว', 'Removed ${member.name}'));
  }

  Future<void> _openRecord(FamilyPatient relative) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final patient =
          await widget.caseloadRepository.patient(relative.patientId);
      if (!mounted) return;
      navigator.push(MaterialPageRoute(
        builder: (_) => PatientRecordScreen(
          patient: patient,
          repository: widget.caseloadRepository,
          // No medicationRepository: a family member reads the record, and
          // the prescribe and stop actions are hidden rather than shown and
          // then refused by the database.
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(friendlyError(e,
            whileDoing: t('เปิดข้อมูลไม่สำเร็จ', 'Could not open the record'))),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<_FamilyView>(
          future: _future,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                OnboardingHeader(
                  icon: Icons.arrow_back,
                  onIconTap: () => Navigator.of(context).pop(),
                  title: t('ครอบครัว', 'Family'),
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _ErrorBlock(error: snapshot.error!, onRetry: _reload)
                else if (snapshot.hasData)
                  ..._buildBody(snapshot.data!),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(_FamilyView view) {
    final pending = view.members.where((m) => m.isPending).toList();
    final active = view.members.where((m) => !m.isPending).toList();

    return [
      Text(
        t('ให้คนในครอบครัวช่วยดูแลการกินยาของคุณ โดยที่คุณเป็นคนอนุมัติเองทุกครั้ง',
            'Let your family help keep track of your medication — you approve every one of them yourself'),
        style: const TextStyle(
            fontSize: 14, height: 1.6, color: OnboardingColors.textMuted),
      ),
      const SizedBox(height: 20),
      _CodeCard(code: view.code),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _busy ? null : _openJoinSheet,
        icon: const Icon(Icons.group_add_outlined, size: 20),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: OnboardingColors.border),
          foregroundColor: OnboardingColors.text,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        label: Text(t('เข้าร่วมครอบครัวด้วยรหัส', 'Join a family with a code'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),

      if (pending.isNotEmpty) ...[
        const SizedBox(height: 28),
        _SectionTitle(t('คำขอเข้าร่วม (${pending.length})',
            'Requests to join (${pending.length})')),
        const SizedBox(height: 4),
        Text(
          t('อนุมัติแล้วเขาจะเห็นข้อมูลสุขภาพ ยา และบันทึกอาการของคุณทั้งหมด',
              'Once approved they see all of your health details, medication and symptom notes'),
          style: const TextStyle(
              fontSize: 12.5, height: 1.5, color: Color(0xFFB26A00)),
        ),
        const SizedBox(height: 10),
        ...pending.map((m) => _PendingTile(
              member: m,
              busy: _busy,
              onApprove: () => _run(
                  () => widget.repository.approve(m.userId),
                  t('อนุมัติ ${m.name} แล้ว', 'Approved ${m.name}')),
              onDecline: () => _run(
                  () => widget.repository.revoke(m.userId),
                  t('ปฏิเสธคำขอแล้ว', 'Request declined')),
            )),
      ],

      const SizedBox(height: 28),
      _SectionTitle(t('คนที่ดูข้อมูลของฉันได้', 'Who can see my record')),
      const SizedBox(height: 10),
      if (active.isEmpty)
        _Empty(t('ยังไม่มีใคร — ส่งรหัสด้านบนให้คนในครอบครัวเพื่อเริ่ม',
            'Nobody yet — share the code above with your family to start'))
      else
        ...active.map((m) => _MemberTile(
              member: m,
              busy: _busy,
              onRemove: () => _confirmRevoke(m),
            )),

      const SizedBox(height: 28),
      _SectionTitle(t('ฉันดูแลใครบ้าง', 'Who I look after')),
      const SizedBox(height: 10),
      if (view.caringFor.isEmpty)
        _Empty(t('ยังไม่ได้เข้าร่วมครอบครัวของใคร',
            'You have not joined anyone’s family yet'))
      else
        ...view.caringFor.map((p) => _RelativeTile(
              relative: p,
              missedDoses: view.missedByPatient[p.patientId],
              busy: _busy,
              onOpen: p.isPending ? null : () => _openRecord(p),
              onLeave: () => _run(
                  () => widget.repository.leave(p.patientId),
                  t('ออกจากครอบครัวของ ${p.name} แล้ว',
                      'Left ${p.name}’s family')),
            )),
    ];
  }
}

class _FamilyView {
  const _FamilyView({
    required this.code,
    required this.members,
    required this.caringFor,
    required this.missedByPatient,
  });

  final String code;
  final List<FamilyMember> members;
  final List<FamilyPatient> caringFor;

  /// Doses that came due for each relative in the last week and were never
  /// answered, keyed by patient id. Absent for anyone whose record could not
  /// be read — which is not the same as zero, and is shown as nothing rather
  /// than as "all caught up".
  final Map<String, int> missedByPatient;
}

/// The code, big enough to read aloud across a room.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('รหัสครอบครัวของคุณ', 'Your family code'),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: OnboardingColors.teal),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: OnboardingColors.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: t('คัดลอก', 'Copy'),
                icon: const Icon(Icons.copy_rounded,
                    color: OnboardingColors.teal),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t('คัดลอกรหัสแล้ว', 'Code copied')),
                  ));
                },
              ),
            ],
          ),
          Text(
            t('ส่งรหัสนี้ให้คนในครอบครัว เขากรอกในแอปแล้วคุณกดอนุมัติ',
                'Send this to your family — they enter it in the app and you approve'),
            style: const TextStyle(
                fontSize: 12.5, height: 1.5, color: OnboardingColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.repository});

  final FamilyRepository repository;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = t('กรอกรหัสให้ครบ', 'Enter the whole code'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await widget.repository.requestAccess(code);
      if (!mounted) return;
      switch (result) {
        case JoinFamilyResult.pending:
          navigator.pop(true);
          messenger.showSnackBar(SnackBar(
            content: Text(t('ส่งคำขอแล้ว — รอเจ้าของรหัสกดอนุมัติ',
                'Request sent — waiting for them to approve')),
          ));
        case JoinFamilyResult.alreadyActive:
          setState(() => _error =
              t('คุณอยู่ในครอบครัวนี้อยู่แล้ว', 'You are already in this family'));
        case JoinFamilyResult.ownCode:
          setState(() => _error =
              t('นี่คือรหัสของคุณเอง', 'That is your own code'));
        case JoinFamilyResult.notFound:
          setState(() => _error =
              t('ไม่พบรหัสนี้ — ตรวจสอบอีกครั้ง', 'No such code — check it again'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('เข้าร่วมครอบครัว', 'Join a family'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            t('กรอกรหัสที่ได้รับ เจ้าของรหัสจะเห็นคำขอและกดอนุมัติเอง',
                'Enter the code you were given. They see the request and approve it themselves.'),
            style: const TextStyle(
                fontSize: 13, height: 1.6, color: OnboardingColors.textMuted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
            decoration: InputDecoration(
              hintText: t('รหัสครอบครัว', 'Family code'),
              hintStyle: const TextStyle(
                  fontSize: 15,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                  color: OnboardingColors.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: OnboardingColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: OnboardingColors.border),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFC0392B), height: 1.5)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: OnboardingColors.teal,
                disabledBackgroundColor: OnboardingColors.tealDisabled,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(t('ส่งคำขอ', 'Send request'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.member,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final FamilyMember member;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        border: Border.all(color: const Color(0xFFF0DFC0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.name,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          if (member.email != null)
            Text(member.email!,
                style: const TextStyle(
                    fontSize: 12.5, color: OnboardingColors.textMuted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: OnboardingColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(t('อนุมัติ', 'Approve')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC0392B),
                    side: const BorderSide(color: Color(0xFFE6C9C4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(t('ปฏิเสธ', 'Decline')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.busy,
    required this.onRemove,
  });

  final FamilyMember member;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: OnboardingColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (member.email != null)
                  Text(member.email!,
                      style: const TextStyle(
                          fontSize: 12, color: OnboardingColors.textMuted)),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onRemove,
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC0392B)),
            child: Text(t('นำออก', 'Remove')),
          ),
        ],
      ),
    );
  }
}

class _RelativeTile extends StatelessWidget {
  const _RelativeTile({
    required this.relative,
    required this.missedDoses,
    required this.busy,
    required this.onOpen,
    required this.onLeave,
  });

  final FamilyPatient relative;

  /// Doses missed in the last week. Null when the count could not be read —
  /// which is left blank rather than shown as zero, since "nothing missed"
  /// and "could not check" are opposite things to tell a worried relative.
  final int? missedDoses;

  final bool busy;

  /// Null while the request is still pending — there is nothing to open yet.
  final VoidCallback? onOpen;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final missed = missedDoses;
    final behind = !relative.isPending && missed != null && missed > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: behind ? const Color(0xFFFDF3F1) : null,
        border: Border.all(
            color: behind ? const Color(0xFFF3D3CD) : OnboardingColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(
          relative.isPending
              ? Icons.hourglass_empty
              : behind
                  ? Icons.error_outline
                  : Icons.favorite_outline,
          color: relative.isPending
              ? const Color(0xFFB26A00)
              : behind
                  ? const Color(0xFFC0392B)
                  : OnboardingColors.teal,
        ),
        title: Text(relative.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(
          relative.isPending
              ? t('รออนุมัติ', 'Waiting for approval')
              : behind
                  // The count is the reason a family member opens this screen,
                  // so it is the line under the name rather than a number they
                  // have to go looking for.
                  ? t('ไม่ได้กินยา $missed มื้อ ใน 7 วันล่าสุด — แตะเพื่อดู',
                      '$missed doses not taken in the last 7 days — tap to see')
                  : missed == null
                      ? t('แตะเพื่อดูข้อมูลสุขภาพและการกินยา',
                          'Tap to see health details and medication')
                      : t('กินยาครบใน 7 วันล่าสุด',
                          'No doses missed in the last 7 days'),
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            fontWeight: behind ? FontWeight.w600 : FontWeight.w400,
            color: behind
                ? const Color(0xFFC0392B)
                : OnboardingColors.textMuted,
          ),
        ),
        onTap: busy ? null : onOpen,
        trailing: IconButton(
          tooltip: t('ออกจากครอบครัวนี้', 'Leave this family'),
          icon: const Icon(Icons.logout, size: 20, color: OnboardingColors.textMuted),
          onPressed: busy ? null : onLeave,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13.5, height: 1.5, color: OnboardingColors.textMuted)),
      );
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Text(
              friendlyError(error,
                  whileDoing: t('โหลดข้อมูลครอบครัวไม่สำเร็จ',
                      'Could not load your family')),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: onRetry,
                child: Text(t('ลองอีกครั้ง', 'Try again'))),
          ],
        ),
      );
}
