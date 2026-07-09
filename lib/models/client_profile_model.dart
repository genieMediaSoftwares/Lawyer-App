class ClientProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String profileImage;
  final String location;
  final String dob;
  final String gender;
  final List<String> languages;
  final bool isVerified;

  ClientProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.profileImage,
    required this.location,
    required this.dob,
    required this.gender,
    required this.languages,
    required this.isVerified,
  });

  factory ClientProfileModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    final list = user['languages'] as List?;
    final langs = list != null ? list.map((e) => e.toString()).toList() : <String>[];
    return ClientProfileModel(
      id: user['_id'] ?? '',
      fullName: user['fullName'] ?? '',
      email: user['email'] ?? '',
      mobile: user['mobile'] ?? '',
      profileImage: user['profileImage'] ?? '',
      location: user['location'] ?? '',
      dob: user['dob'] ?? '',
      gender: user['gender'] ?? '',
      languages: langs,
      isVerified: user['isVerified'] ?? false,
    );
  }

  ClientProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? mobile,
    String? profileImage,
    String? location,
    String? dob,
    String? gender,
    List<String>? languages,
    bool? isVerified,
  }) {
    return ClientProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      profileImage: profileImage ?? this.profileImage,
      location: location ?? this.location,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      languages: languages ?? this.languages,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
