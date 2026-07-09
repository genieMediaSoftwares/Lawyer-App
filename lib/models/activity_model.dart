class ActivityModel {
  final String title;
  final String description;
  final DateTime date;
  final String type;

  ActivityModel({
    required this.title,
    required this.description,
    required this.date,
    required this.type,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? 'profile',
    );
  }
}
