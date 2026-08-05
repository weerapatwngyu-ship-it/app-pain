import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/entities/nearby_pharmacy.dart';

const _overpassUrl = 'https://overpass-api.de/api/interpreter';
const _earthRadiusMeters = 6371000.0;

/// Looks up nearby pharmacies and clinics straight from OpenStreetMap's
/// Overpass API — it is public and needs no key, so there is nothing for a
/// server of ours to add here beyond a hop.
class PharmacyFinderRepository {
  PharmacyFinderRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<NearbyPharmacy>> findNearby({
    required double lat,
    required double lng,
    int radiusMeters = 1500,
  }) async {
    final around = 'around:$radiusMeters,$lat,$lng';
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="pharmacy"]($around);
  way["amenity"="pharmacy"]($around);
  node["amenity"="clinic"]($around);
  way["amenity"="clinic"]($around);
  node["amenity"="doctors"]($around);
  way["amenity"="doctors"]($around);
);
out center tags;
''';

    final response = await _httpClient.post(
      Uri.parse(_overpassUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    );

    if (response.statusCode != 200) {
      throw PharmacyLookupException(
        'OpenStreetMap ตอบกลับไม่สำเร็จ (HTTP ${response.statusCode}) — '
        'บริการนี้ฟรีและบางครั้งคนใช้เยอะ ลองใหม่อีกครั้ง',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final elements = body['elements'] as List<dynamic>? ?? const [];

    final results = elements
        .map((element) => _toPharmacy(element as Map<String, dynamic>, lat, lng))
        .whereType<NearbyPharmacy>()
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  NearbyPharmacy? _toPharmacy(Map<String, dynamic> element, double originLat, double originLng) {
    // Nodes carry coordinates directly; ways report theirs under `center`.
    final center = element['center'] as Map<String, dynamic>?;
    final lat = (element['lat'] ?? center?['lat']) as num?;
    final lng = (element['lon'] ?? center?['lon']) as num?;
    if (lat == null || lng == null) return null;

    final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
    final isPharmacy = tags['amenity'] == 'pharmacy';
    final address = [tags['addr:housenumber'], tags['addr:street'], tags['addr:city']]
        .whereType<String>()
        .join(' ');

    return NearbyPharmacy(
      placeId: '${element['type']}/${element['id']}',
      name: tags['name'] as String? ?? (isPharmacy ? 'ร้านขายยา' : 'คลินิก'),
      address: address,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      distanceMeters:
          _haversineMeters(originLat, originLng, lat.toDouble(), lng.toDouble()).round(),
      // OSM's opening_hours tag is free-form text, not reliably parseable.
      openNow: null,
      type: isPharmacy ? 'pharmacy' : 'clinic',
    );
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    double toRad(double deg) => deg * math.pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return _earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class PharmacyLookupException implements Exception {
  PharmacyLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}
