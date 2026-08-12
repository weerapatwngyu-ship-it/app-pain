import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/presentation/onboarding/onboarding_theme.dart';
import '../domain/entities/nearby_pharmacy.dart';
import '../../../shared/theme/app_palette.dart';

/// Embedded map (OpenStreetMap tiles — free, no API key/billing, unlike
/// Google Maps SDK) showing the user's location plus a pin for every
/// nearby pharmacy/clinic result.
class PharmacyMapView extends StatelessWidget {
  const PharmacyMapView({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.pharmacies,
    required this.onTapPharmacy,
  });

  final double userLat;
  final double userLng;
  final List<NearbyPharmacy> pharmacies;
  final ValueChanged<NearbyPharmacy> onTapPharmacy;

  @override
  Widget build(BuildContext context) {
    final userLocation = LatLng(userLat, userLng);
    return FlutterMap(
      options: MapOptions(initialCenter: userLocation, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.medtrack',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: userLocation,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            for (final pharmacy in pharmacies)
              Marker(
                point: LatLng(pharmacy.lat, pharmacy.lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => onTapPharmacy(pharmacy),
                  child: Icon(
                    pharmacy.isPharmacy ? Icons.local_pharmacy : Icons.medical_services,
                    color: pharmacy.isPharmacy ? OnboardingColors.teal : AppPalette.warning,
                    size: 34,
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors'),
        ),
      ],
    );
  }
}
