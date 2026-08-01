import '../../../core/network/api_client.dart';
import '../domain/entities/nearby_pharmacy.dart';

class PharmacyFinderRepository {
  PharmacyFinderRepository(this._client);

  final ApiClient _client;

  Future<List<NearbyPharmacy>> findNearby({
    required double lat,
    required double lng,
    int radiusMeters = 1500,
  }) async {
    final json = await _client.get(
      '/pharmacies/nearby?lat=$lat&lng=$lng&radiusMeters=$radiusMeters',
    ) as List<dynamic>;
    return json.map((e) => NearbyPharmacy.fromJson(e as Map<String, dynamic>)).toList();
  }
}
