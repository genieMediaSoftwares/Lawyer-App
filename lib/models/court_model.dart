class CourtModel {
  final String courtName;
  final String courtType;
  final String city;
  final String? district;
  final String state;
  final String country;
  final String courtAddress;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  CourtModel({
    required this.courtName,
    required this.courtType,
    required this.city,
    this.district,
    required this.state,
    required this.country,
    required this.courtAddress,
    this.pincode,
    this.latitude,
    this.longitude,
    required this.isActive,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      courtName: json['courtName'] ?? '',
      courtType: json['courtType'] ?? '',
      city: json['city'] ?? '',
      district: json['district'],
      state: json['state'] ?? '',
      country: json['country'] ?? '',
      courtAddress: json['courtAddress'] ?? '',
      pincode: json['pincode'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }
}
