import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/pharmacy_finder_repository.dart';
import '../domain/entities/nearby_pharmacy.dart';

class PharmacyFinderScreen extends StatefulWidget {
  const PharmacyFinderScreen({super.key, required this.repository});

  final PharmacyFinderRepository repository;

  @override
  State<PharmacyFinderScreen> createState() => _PharmacyFinderScreenState();
}

class _PharmacyFinderScreenState extends State<PharmacyFinderScreen> {
  bool _loading = true;
  String? _error;
  bool _showOpenAppSettings = false;
  List<NearbyPharmacy> _pharmacies = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _showOpenAppSettings = false;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _error = 'กรุณาเปิดบริการตำแหน่ง (Location) ของเครื่องก่อนใช้งานฟีเจอร์นี้';
          _loading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'ต้องอนุญาตการเข้าถึงตำแหน่งเพื่อค้นหาร้านยาใกล้ฉัน';
          _showOpenAppSettings = permission == LocationPermission.deniedForever;
          _loading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final results = await widget.repository.findNearby(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _pharmacies = results;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 503
            ? _readableApiMessage(e)
            : 'ค้นหาร้านยาไม่สำเร็จ (HTTP ${e.statusCode})';
        _loading = false;
      });
    } on SocketException catch (_) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ค้นหาร้านยาไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  /// The backend returns a JSON body like `{"message": "...", ...}` on
  /// error — fall back to the raw body if it isn't JSON.
  static String _readableApiMessage(ApiException e) {
    try {
      final decoded = jsonDecode(e.message);
      if (decoded is Map && decoded['message'] != null) {
        final message = decoded['message'];
        return message is List ? message.join(', ') : message.toString();
      }
    } catch (_) {
      // Not JSON — fall through to the raw body below.
    }
    return e.message.isEmpty ? 'HTTP ${e.statusCode}' : e.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingHeader(
                icon: Icons.arrow_back,
                onIconTap: () => Navigator.of(context).pop(),
                title: 'ร้านขายยาใกล้ฉัน',
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                onPressed: _showOpenAppSettings ? Geolocator.openAppSettings : _load,
                child: Text(_showOpenAppSettings ? 'เปิดการตั้งค่าแอป' : 'ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }
    if (_pharmacies.isEmpty) {
      return const Center(child: Text('ไม่พบร้านขายยาใกล้เคียง'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _pharmacies.length,
        separatorBuilder: (_, __) => const Divider(color: OnboardingColors.border),
        itemBuilder: (context, index) => _PharmacyTile(pharmacy: _pharmacies[index]),
      ),
    );
  }
}

class _PharmacyTile extends StatelessWidget {
  const _PharmacyTile({required this.pharmacy});

  final NearbyPharmacy pharmacy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFDCEBE6),
            child: Icon(Icons.local_pharmacy_outlined, color: OnboardingColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pharmacy.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (pharmacy.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pharmacy.address,
                    style: const TextStyle(color: OnboardingColors.textMuted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      pharmacy.formattedDistance,
                      style: const TextStyle(color: OnboardingColors.teal, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (pharmacy.openNow != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        pharmacy.openNow! ? 'เปิดอยู่' : 'ปิดแล้ว',
                        style: TextStyle(
                          color: pharmacy.openNow! ? Colors.green : Theme.of(context).colorScheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
