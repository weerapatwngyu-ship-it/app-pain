import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../data/pharmacy_finder_repository.dart';
import '../domain/entities/nearby_pharmacy.dart';
import 'pharmacy_map_view.dart';

const _searchRadiusMeters = 1500;

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
  bool _showMap = true;
  List<NearbyPharmacy> _places = const [];
  PlaceKind? _filter;
  double? _userLat;
  double? _userLng;

  /// A null `_filter` is the "ทั้งหมด" chip — no filtering at all.
  List<NearbyPharmacy> get _visiblePlaces =>
      _filter == null ? _places : _places.where((p) => p.kind == _filter).toList();

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
        radiusMeters: _searchRadiusMeters,
      );
      if (!mounted) return;
      setState(() {
        _places = results;
        _userLat = position.latitude;
        _userLng = position.longitude;
        _loading = false;
      });
    } on PharmacyLookupException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on SocketException catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'เชื่อมต่อ OpenStreetMap ไม่ได้ — ตรวจสอบอินเทอร์เน็ต';
        _loading = false;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'หาตำแหน่งไม่สำเร็จ (หมดเวลา) — ถ้ารันบน emulator ต้องตั้งตำแหน่งจำลองก่อน '
            '(Extended Controls > Location) เพราะ emulator ไม่มีสัญญาณ GPS จริง';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'ค้นหาร้านยาไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = !_loading && _error == null && _places.isNotEmpty;
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
                  if (hasResults)
                    OnboardingIconButton(
                      icon: _showMap ? Icons.list : Icons.map_outlined,
                      onTap: () => setState(() => _showMap = !_showMap),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StatusLine(
                loading: _loading,
                error: _error,
                count: _visiblePlaces.length,
                radiusMeters: _searchRadiusMeters,
              ),
              if (hasResults) ...[
                const SizedBox(height: 12),
                _FilterChips(
                  selected: _filter,
                  countAll: _places.length,
                  countPharmacy: _places.where((p) => p.isPharmacy).length,
                  countClinic: _places.where((p) => !p.isPharmacy).length,
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ],
              const SizedBox(height: 12),
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
    if (_places.isEmpty) {
      return const Center(child: Text('ไม่พบร้านยา/คลินิกใกล้เคียง'));
    }

    final visible = _visiblePlaces;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Map and list are shown together rather than swapped, so a result
        // tapped on the map can be read about without losing the overview.
        if (_showMap && _userLat != null && _userLng != null) ...[
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PharmacyMapView(
                userLat: _userLat!,
                userLng: _userLng!,
                pharmacies: visible,
                onTapPharmacy: _showDetailSheet,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _filter == PlaceKind.pharmacy
                        ? 'ไม่พบร้านขายยาในรัศมีนี้'
                        : 'ไม่พบคลินิกในรัศมีนี้',
                    style: const TextStyle(color: OnboardingColors.textMuted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _PlaceCard(
                      place: visible[index],
                      onDetails: () => _showDetailSheet(visible[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showDetailSheet(NearbyPharmacy place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DetailSheet(place: place),
    );
  }
}

// ---------------------------------------------------------------------------
// Header pieces
// ---------------------------------------------------------------------------

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.loading,
    required this.error,
    required this.count,
    required this.radiusMeters,
  });

  final bool loading;
  final String? error;
  final int count;
  final int radiusMeters;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;
    if (loading) {
      icon = Icons.my_location;
      text = 'กำลังค้นหาตำแหน่ง...';
    } else if (error != null) {
      icon = Icons.error_outline;
      // Deliberately vague about which step failed: the message below already
      // says, and claiming the location lookup failed when it was the place
      // search sends the user off to check GPS for nothing.
      text = 'ค้นหาไม่สำเร็จ';
    } else {
      icon = Icons.place_outlined;
      text = 'พบ $count แห่ง ในรัศมี ${(radiusMeters / 1000).toStringAsFixed(1)} กม.';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: OnboardingColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.countAll,
    required this.countPharmacy,
    required this.countClinic,
    required this.onChanged,
  });

  final PlaceKind? selected;
  final int countAll;
  final int countPharmacy;
  final int countClinic;
  final ValueChanged<PlaceKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'ทั้งหมด ($countAll)',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '💊 ร้านขายยา ($countPharmacy)',
            selected: selected == PlaceKind.pharmacy,
            onTap: () => onChanged(PlaceKind.pharmacy),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '🏥 คลินิก ($countClinic)',
            selected: selected == PlaceKind.clinic,
            onTap: () => onChanged(PlaceKind.clinic),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? OnboardingColors.teal : Colors.white,
          border: Border.all(
            color: selected ? OnboardingColors.teal : OnboardingColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : OnboardingColors.text,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result card
// ---------------------------------------------------------------------------

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onDetails});

  final NearbyPharmacy place;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: OnboardingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDCEBE6),
                child: Icon(
                  place.isPharmacy
                      ? Icons.local_pharmacy_outlined
                      : Icons.medical_services_outlined,
                  color: OnboardingColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.kind.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OnboardingColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 13, color: OnboardingColors.teal),
                        const SizedBox(width: 3),
                        Text(
                          place.formattedDistance,
                          style: const TextStyle(
                            color: OnboardingColors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (place.openingHours != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.schedule,
                              size: 13, color: OnboardingColors.textMuted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              place.openingHours!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: OnboardingColors.textMuted,
                              ),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnboardingColors.teal,
                    side: const BorderSide(color: OnboardingColors.teal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('รายละเอียด'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openPharmacyInGoogleMaps(context, place),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OnboardingColors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text('นำทาง'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail sheet
// ---------------------------------------------------------------------------

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.place});

  final NearbyPharmacy place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDCEBE6),
                child: Icon(
                  place.isPharmacy
                      ? Icons.local_pharmacy_outlined
                      : Icons.medical_services_outlined,
                  color: OnboardingColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${place.kind.label} · ${place.formattedDistance}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: OnboardingColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (place.address.isNotEmpty)
            _DetailRow(icon: Icons.place_outlined, text: place.address),
          if (place.openingHours != null)
            _DetailRow(icon: Icons.schedule, text: place.openingHours!),
          if (place.phone != null)
            _DetailRow(
              icon: Icons.phone_outlined,
              text: place.phone!,
              onTap: () => _launch(context, Uri.parse('tel:${place.phone}'), 'โทรออก'),
            ),
          if (place.website != null)
            _DetailRow(
              icon: Icons.language,
              text: place.website!,
              onTap: () => _launch(context, Uri.parse(place.website!), 'เปิดเว็บไซต์'),
            ),
          if (place.address.isEmpty &&
              place.openingHours == null &&
              place.phone == null &&
              place.website == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'OpenStreetMap ยังไม่มีข้อมูลติดต่อของสถานที่นี้',
                style: TextStyle(fontSize: 13, color: OnboardingColors.textMuted),
              ),
            ),
          const SizedBox(height: 20),
          OnboardingPrimaryButton(
            label: 'นำทางด้วย Google Maps',
            onPressed: () => openPharmacyInGoogleMaps(context, place),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri, String what) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$whatไม่สำเร็จ')));
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: OnboardingColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap == null ? OnboardingColors.text : OnboardingColors.teal,
                  decoration: onTap == null ? null : TextDecoration.underline,
                ),
              ),
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
