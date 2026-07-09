class ClientStatsModel {
  final int activeCases;
  final int totalCases;
  final int totalAppointments;
  final int totalDocuments;

  ClientStatsModel({
    required this.activeCases,
    required this.totalCases,
    required this.totalAppointments,
    required this.totalDocuments,
  });

  factory ClientStatsModel.fromJson(Map<String, dynamic> json) {
    return ClientStatsModel(
      activeCases: json['activeCases'] ?? 0,
      totalCases: json['totalCases'] ?? 0,
      totalAppointments: json['totalAppointments'] ?? 0,
      totalDocuments: json['totalDocuments'] ?? 0,
    );
  }
}
