class NearbyPharmacy {
  const NearbyPharmacy({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.openNow,
  });

  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int distanceMeters;
  final bool? openNow;

  factory NearbyPharmacy.fromJson(Map<String, dynamic> json) {
    return NearbyPharmacy(
      placeId: json['placeId'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distanceMeters: json['distanceMeters'] as int,
      openNow: json['openNow'] as bool?,
    );
  }

  String get formattedDistance =>
      distanceMeters < 1000 ? '$distanceMeters ม.' : '${(distanceMeters / 1000).toStringAsFixed(1)} กม.';
}
