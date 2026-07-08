class PlaceSuggestionModel {
  final String description;
  final String placeId;

  PlaceSuggestionModel({
    required this.description,
    required this.placeId,
  });

  factory PlaceSuggestionModel.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestionModel(
      description: json['description'] ?? '',
      placeId: json['placeId'] ?? '',
    );
  }
}

class PlaceDetailsModel {
  final String description;
  final String city;
  final String district;
  final String state;
  final String country;
  final double latitude;
  final double longitude;
  final String placeId;

  PlaceDetailsModel({
    required this.description,
    required this.city,
    required this.district,
    required this.state,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  factory PlaceDetailsModel.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsModel(
      description: json['description'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      placeId: json['placeId'] ?? '',
    );
  }
}
