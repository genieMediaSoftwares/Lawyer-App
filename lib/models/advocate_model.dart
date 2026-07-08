class AdvocateModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String mobile;
  final String profileImage;
  final String specialization;
  final int experience;
  final String education;
  final int consultationFee;
  final String bio;
  final double rating;
  final int totalReviews;
  final List<String> languages;
  final String location;

  AdvocateModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.profileImage,
    required this.specialization,
    required this.experience,
    required this.education,
    required this.consultationFee,
    required this.bio,
    required this.rating,
    required this.totalReviews,
    required this.languages,
    required this.location,
  });

  factory AdvocateModel.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] is Map<String, dynamic> ? json['user'] : {};
    final uId = json['user'] is String ? json['user'] : (userData['_id'] ?? '');

    return AdvocateModel(
      id: json['_id'] ?? '',
      userId: uId,
      fullName: userData['fullName'] ?? 'Advocate',
      email: userData['email'] ?? '',
      mobile: userData['mobile'] ?? '',
      profileImage: userData['profileImage'] ?? '',
      specialization: json['specialization'] ?? '',
      experience: json['experience'] ?? 0,
      education: json['education'] ?? '',
      consultationFee: json['consultationFee'] ?? 0,
      bio: json['bio'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] ?? 0,
      languages: List<String>.from(json['languages'] ?? []),
      location: userData['location'] ?? 'Hyderabad, Telangana',
    );
  }
}
