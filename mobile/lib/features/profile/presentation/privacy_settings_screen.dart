import 'package:flutter/material.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../shared/format/thai_date.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../peer_chat/data/peer_chat_repository.dart';
import '../data/privacy_repository.dart';

/// What the patient can actually decide about their own record.
///
/// Only real controls belong here. Two exist, and both are enforced by the
/// database rather than by this screen: whether other patients can see the
/// display name, and which doctors may read the record. A row that looked like
/// a privacy setting but changed nothing would be worse than no row.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({
    super.key,
    required this.patientId,
    required this.repository,
    required this.peerChatRepository,
  });

  final String patientId;
  final PrivacyRepository repository;
  final PeerChatRepository peerChatRepository;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  List<AccessGrant> _grants = const [];
  bool _peerEnabled = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final grants = await widget.repository.accessList(widget.patientId);
      final peer = await widget.peerChatRepository.isEnabled(widget.patientId);
      if (!mounted) return;
      setState(() {
        _grants = grants;
        _peerEnabled = peer;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e,
            whileDoing: t('โหลดข้อมูลไม่สำเร็จ', 'Could not load'));
        _loading = false;
      });
    }
  }

  Future<void> _setPeer(bool value) async {
    // Optimistic: the switch answers immediately and is put back if the write
    // fails, rather than sitting still while a request goes out.
    setState(() => _peerEnabled = value);
    try {
      await widget.peerChatRepository
          .setEnabled(patientId: widget.patientId, enabled: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _peerEnabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyError(e,
            whileDoing: t('เปลี่ยนการตั้งค่าไม่สำเร็จ', 'Could not change that'))),
      ));
    }
  }

  Future<void> _confirmRevoke(AccessGrant grant) async {
    final who = grant.name ?? t('บัญชีนี้', 'this account');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('เพิกถอนสิทธิ์', 'Withdraw access')),
        content: Text(t(
          'หลังเพิกถอน $who จะไม่เห็นยา อาการ และประวัติของคุณ '
              'และสั่งยาให้คุณไม่ได้\n\n'
              'ห้องสนทนาที่คุยกันไว้ยังอยู่ และคุณคืนสิทธิ์ได้ภายหลัง',
          'Once withdrawn, $who can no longer see your medication, symptoms or '
              'record, and cannot prescribe for you.\n\n'
              'Your conversation stays, and you can give access back later.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('ยกเลิก', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('เพิกถอน', 'Withdraw'),
                style: const TextStyle(color: Color(0xFFC0392B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _write(() => widget.repository.revoke(grant.linkId));
  }

  Future<void> _restore(AccessGrant grant) =>
      _write(() => widget.repository.restore(grant.linkId));

  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on StateError catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t('ตั้งค่าความเป็นส่วนตัว', 'Privacy settings')),
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

    final active = _grants.where((g) => g.isActive).toList();
    final withdrawn = _grants.where((g) => !g.isActive).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _SectionLabel(t('ผู้ป่วยคนอื่น', 'Other patients')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _peerEnabled,
            onChanged: _setPeer,
            activeThumbColor: OnboardingColors.teal,
            title: Text(
              t('ให้ผู้ป่วยคนอื่นเห็นชื่อและคุยกับคุณได้',
                  'Let other patients see your name and message you'),
              style: const TextStyle(fontSize: 14.5),
            ),
            subtitle: Text(
              t(
                'เห็นได้เฉพาะชื่อที่แสดง ยา อาการ และประวัติของคุณไม่ถูกแชร์',
                'Only your display name. Your medication, symptoms and record '
                    'are not shared.',
              ),
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: OnboardingColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(t('ใครเห็นประวัติของคุณ', 'Who can see your record')),
          Text(
            t(
              'แพทย์จะได้สิทธิ์เมื่อเริ่มสนทนากับคุณในแอป และคุณเพิกถอนได้ทุกเมื่อ',
              'A doctor gets access when a conversation with you starts, and '
                  'you can withdraw it at any time.',
            ),
            style: const TextStyle(
                fontSize: 12, height: 1.55, color: OnboardingColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (active.isEmpty)
            Text(
              t('ยังไม่มีใครนอกจากคุณเข้าถึงประวัตินี้',
                  'Nobody but you has access to this record'),
              style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: OnboardingColors.textMuted),
            )
          else
            for (final grant in active)
              _GrantCard(grant: grant, onRevoke: () => _confirmRevoke(grant)),
          if (withdrawn.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel(t('เพิกถอนแล้ว', 'Withdrawn')),
            for (final grant in withdrawn)
              _GrantCard(
                grant: grant,
                faded: true,
                onRestore: () => _restore(grant),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OnboardingColors.textMuted),
        ),
      );
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({
    required this.grant,
    this.faded = false,
    this.onRevoke,
    this.onRestore,
  });

  final AccessGrant grant;
  final bool faded;
  final VoidCallback? onRevoke;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    // Names come from the doctors directory. A link with no listing behind it
    // is shown as what it is rather than as a blank line: the patient is
    // entitled to know something has access even when the name is not theirs
    // to read.
    final name = grant.name ??
        (grant.isProvider
            ? t('บัญชีบุคลากร', 'A clinical account')
            : t('บัญชีผู้ดูแล', 'A caregiver account'));

    return Opacity(
      opacity: faded ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OnboardingColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (grant.specialty != null) grant.specialty!,
                      t('ได้สิทธิ์ ${thaiOrEnglishDate(grant.grantedAt)}',
                          'since ${thaiOrEnglishDate(grant.grantedAt)}'),
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: OnboardingColors.textMuted),
                  ),
                ],
              ),
            ),
            if (onRevoke != null)
              TextButton(
                onPressed: onRevoke,
                child: Text(t('เพิกถอน', 'Withdraw'),
                    style: const TextStyle(color: Color(0xFFC0392B))),
              ),
            if (onRestore != null)
              TextButton(
                onPressed: onRestore,
                child: Text(t('คืนสิทธิ์', 'Restore')),
              ),
          ],
        ),
      ),
    );
  }
}
