class PlaceSuggestionModel {
  final String description;
  final String placeId;

  const PlaceSuggestionModel({
    required this.description,
    required this.placeId,
  });

  factory PlaceSuggestionModel.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestionModel(
      description: json['description'] ?? '',
      placeId: json['placeId'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceSuggestionModel && other.placeId == placeId;

  @override
  int get hashCode => placeId.hashCode;
}

class PlaceDetailsModel {
  final String description;
  final String city;
  final String district;
  final String state;
  final String country;

  /// Nullable on purpose.
  ///
  /// The India Post provider returns no coordinates at all, and Google can omit
  /// geometry. These were previously defaulted to `0.0`, which is a real point
  /// in the Gulf of Guinea — so a PIN-code selection silently placed the user
  /// off the coast of Africa and would corrupt any distance-based lawyer
  /// matching. Absent stays absent; callers must handle null.
  final double? latitude;
  final double? longitude;

  final String placeId;

  const PlaceDetailsModel({
    required this.description,
    required this.city,
    required this.district,
    required this.state,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Short label for compact UI, e.g. "Gachibowli, Telangana".
  String get shortLabel => [city, state].where((p) => p.isNotEmpty).join(', ');

  factory PlaceDetailsModel.fromJson(Map<String, dynamic> json) {
    return PlaceDetailsModel(
      description: json['description'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeId: json['placeId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'city': city,
        'district': district,
        'state': state,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'placeId': placeId,
      };
}
