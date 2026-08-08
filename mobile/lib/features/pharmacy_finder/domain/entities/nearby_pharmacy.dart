/// Which kind of place a result is, and what the filter chips select on.
enum PlaceKind {
  pharmacy,
  clinic;

  static PlaceKind fromTag(String? amenity) =>
      amenity == 'pharmacy' ? PlaceKind.pharmacy : PlaceKind.clinic;

  String get label => this == PlaceKind.pharmacy ? 'ร้านขายยา' : 'คลินิก';
}

class NearbyPharmacy {
  const NearbyPharmacy({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.openNow,
    required this.kind,
    this.phone,
    this.openingHours,
    this.website,
  });

  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int distanceMeters;
  final bool? openNow;
  final PlaceKind kind;

  /// From OpenStreetMap's `phone`/`opening_hours`/`website` tags — often
  /// absent, since they are filled in by volunteers rather than the business.
  final String? phone;
  final String? openingHours;
  final String? website;

  bool get isPharmacy => kind == PlaceKind.pharmacy;

  String get formattedDistance => distanceMeters < 1000
      ? '$distanceMeters ม.'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} กม.';
}
