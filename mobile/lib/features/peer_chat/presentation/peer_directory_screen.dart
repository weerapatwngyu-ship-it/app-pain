import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/user_avatar.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../../chat/presentation/chat_screen.dart';
import '../data/peer_chat_repository.dart';
import '../domain/entities/peer_thread.dart';
import '../../../shared/theme/app_palette.dart';

/// Finds another patient to message. Only people who switched peer chat on
/// appear here, and only if the viewer switched it on too.
class PeerDirectoryScreen extends StatefulWidget {
  const PeerDirectoryScreen({super.key, required this.repository});

  final PeerChatRepository repository;

  @override
  State<PeerDirectoryScreen> createState() => _PeerDirectoryScreenState();
}

class _PeerDirectoryScreenState extends State<PeerDirectoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<PeerContact> _contacts = const [];
  bool _loading = true;
  String? _error;
  String? _openingFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await widget.repository.directory(
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'ค้นหาไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    // One query per pause in typing rather than one per keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _loading = true);
      _load();
    });
  }

  Future<void> _openChat(PeerContact contact) async {
    setState(() => _openingFor = contact.patientId);
    try {
      final conversationId =
          await widget.repository.openConversation(contact.patientId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            title: contact.displayName,
            subtitle: 'ผู้ป่วยด้วยกัน',
            repository: widget.repository,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดแชทไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _openingFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.tint,
      appBar: AppBar(title: const Text('หาเพื่อนคุย')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ค้นหาด้วยชื่อ',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
          Expanded(child: _buildBody()),
        ],
      ),
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
    if (_contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'ยังไม่พบใคร\nจะเห็นเฉพาะคนที่เปิดให้คุยด้วยเท่านั้น',
            textAlign: TextAlign.center,
            style: TextStyle(color: OnboardingColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final opening = _openingFor == contact.patientId;
        return ListTile(
          leading: UserAvatar(name: contact.displayName, radius: 20),
          title: Text(contact.displayName),
          trailing: opening
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chat_bubble_outline, size: 20),
          onTap: opening ? null : () => _openChat(contact),
        );
      },
    );
  }
}
