import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/pharmacy_finder_repository.dart';
import '../domain/entities/nearby_pharmacy.dart';
import 'pharmacy_map_view.dart';

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
  bool _showMap = false;
  List<NearbyPharmacy> _pharmacies = const [];
  double? _userLat;
  double? _userLng;

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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 15)),
      );
      final results = await widget.repository.findNearby(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _pharmacies = results;
        _userLat = position.latitude;
        _userLng = position.longitude;
        _loading = false;
      });
    } on PharmacyLookupException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on SocketException catch (_) {
      setState(() {
        _error = 'เชื่อมต่อ OpenStreetMap ไม่ได้ — ตรวจสอบอินเทอร์เน็ต';
        _loading = false;
      });
    } on TimeoutException catch (_) {
      setState(() {
        _error = 'หาตำแหน่งไม่สำเร็จ (หมดเวลา) — ถ้ารันบน emulator ต้องตั้งตำแหน่งจำลองก่อน '
            '(Extended Controls > Location) เพราะ emulator ไม่มีสัญญาณ GPS จริง';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ค้นหาร้านยาไม่สำเร็จ: $e';
        _loading = false;
      });
    }
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
              Row(
                children: [
                  Expanded(
                    child: OnboardingHeader(
                      icon: Icons.arrow_back,
                      onIconTap: () => Navigator.of(context).pop(),
                      title: 'ร้านยา/คลินิกใกล้ฉัน',
                    ),
                  ),
                  if (!_loading && _error == null && _pharmacies.isNotEmpty)
                    OnboardingIconButton(
                      icon: _showMap ? Icons.list : Icons.map_outlined,
                      onTap: () => setState(() => _showMap = !_showMap),
                    ),
                ],
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
      return const Center(child: Text('ไม่พบร้านยา/คลินิกใกล้เคียง'));
    }
    if (_showMap && _userLat != null && _userLng != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PharmacyMapView(
          userLat: _userLat!,
          userLng: _userLng!,
          pharmacies: _pharmacies,
          onTapPharmacy: _showPharmacySheet,
        ),
      );
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

  void _showPharmacySheet(NearbyPharmacy pharmacy) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pharmacy.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (pharmacy.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(pharmacy.address, style: const TextStyle(color: OnboardingColors.textMuted)),
            ],
            const SizedBox(height: 4),
            Text(
              pharmacy.formattedDistance,
              style: const TextStyle(color: OnboardingColors.teal, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            OnboardingPrimaryButton(
              label: 'เปิดใน Google Maps',
              onPressed: () => openPharmacyInGoogleMaps(context, pharmacy),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openPharmacyInGoogleMaps(BuildContext context, NearbyPharmacy pharmacy) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${pharmacy.lat},${pharmacy.lng}',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เปิด Google Maps ไม่สำเร็จ')),
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
          CircleAvatar(
            backgroundColor: const Color(0xFFDCEBE6),
            child: Icon(
              pharmacy.isPharmacy ? Icons.local_pharmacy_outlined : Icons.medical_services_outlined,
              color: OnboardingColors.teal,
            ),
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
          IconButton(
            onPressed: () => openPharmacyInGoogleMaps(context, pharmacy),
            icon: const Icon(Icons.map_outlined, color: OnboardingColors.teal),
            tooltip: 'เปิดใน Google Maps',
          ),
        ],
      ),
    );
  }
}
