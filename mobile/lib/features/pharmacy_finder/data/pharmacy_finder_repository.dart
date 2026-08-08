import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/entities/nearby_pharmacy.dart';

/// Tried in order. The main instance rate-limits hard and goes down for
/// maintenance often enough that a single endpoint means the feature is simply
/// broken whenever it does; the mirrors run the same API over the same data.
const _overpassEndpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.osm.ch/api/interpreter',
];

/// Overpass's usage policy requires a request to identify the app behind it,
/// and the instances refuse an unidentified client outright rather than
/// throttling it — the default `Dart/3.x (dart:io)` agent came back HTTP 406
/// from a real device.
const _userAgent = 'MedTrack/0.1 (https://github.com/weerapatwngyu-ship-it/app-pain)';

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

    final response = await _postToFirstWorkingEndpoint(query);

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final elements = body['elements'] as List<dynamic>? ?? const [];

    final results = elements
        .map((element) => _toPharmacy(element as Map<String, dynamic>, lat, lng))
        .whereType<NearbyPharmacy>()
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  /// Walks the mirror list until one answers 200. Only the last failure is
  /// reported: if every mirror is refusing, the reason is the same for all of
  /// them and naming three hosts helps the user with nothing.
  Future<http.Response> _postToFirstWorkingEndpoint(String query) async {
    final body = 'data=${Uri.encodeComponent(query)}';
    Object? lastFailure;

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _httpClient.post(
          Uri.parse(endpoint),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
          body: body,
        );
        if (response.statusCode == 200) return response;
        lastFailure = response.statusCode;
      } catch (e) {
        // Network-level failure against this mirror — try the next one before
        // giving up, since the phone itself may still be online.
        lastFailure = e;
      }
    }

    throw PharmacyLookupException(
      lastFailure is int
          ? 'OpenStreetMap ตอบกลับไม่สำเร็จ (HTTP $lastFailure) — '
              'บริการนี้ฟรีและบางครั้งคนใช้เยอะ ลองใหม่อีกครั้ง'
          : 'เชื่อมต่อ OpenStreetMap ไม่ได้ — ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
    );
  }

  NearbyPharmacy? _toPharmacy(Map<String, dynamic> element, double originLat, double originLng) {
    // Nodes carry coordinates directly; ways report theirs under `center`.
    final center = element['center'] as Map<String, dynamic>?;
    final lat = (element['lat'] ?? center?['lat']) as num?;
    final lng = (element['lon'] ?? center?['lon']) as num?;
    if (lat == null || lng == null) return null;

    final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
    final kind = PlaceKind.fromTag(tags['amenity'] as String?);
    final address = [tags['addr:housenumber'], tags['addr:street'], tags['addr:city']]
        .whereType<String>()
        .join(' ');

    return NearbyPharmacy(
      placeId: '${element['type']}/${element['id']}',
      name: tags['name'] as String? ?? kind.label,
      address: address,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      distanceMeters:
          _haversineMeters(originLat, originLng, lat.toDouble(), lng.toDouble()).round(),
      // OSM's opening_hours tag is free-form text, not reliably parseable.
      openNow: null,
      kind: kind,
      phone: _firstTag(tags, const ['phone', 'contact:phone', 'contact:mobile']),
      openingHours: tags['opening_hours'] as String?,
      website: _firstTag(tags, const ['website', 'contact:website']),
    );
  }

  /// OSM records the same fact under several tag spellings; take whichever is
  /// present rather than showing nothing because a mapper picked the variant.
  String? _firstTag(Map<String, dynamic> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
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
