class AppointmentModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientImage;
  final String lawyerId;
  final String lawyerName;
  final String lawyerImage;
  final String? caseId;
  final String? caseTitle;
  final DateTime date;
  final String timeSlot;
  final String mode;
  final String status;

  AppointmentModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientImage,
    required this.lawyerId,
    required this.lawyerName,
    required this.lawyerImage,
    this.caseId,
    this.caseTitle,
    required this.date,
    required this.timeSlot,
    required this.mode,
    required this.status,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final clientData = json['client'] is Map<String, dynamic> ? json['client'] : {};
    final cId = json['client'] is String ? json['client'] : (clientData['_id'] ?? '');

    final lawyerData = json['lawyer'] is Map<String, dynamic> ? json['lawyer'] : {};
    final lId = json['lawyer'] is String ? json['lawyer'] : (lawyerData['_id'] ?? '');

    final caseData = json['case'] is Map<String, dynamic> ? json['case'] : {};
    final csId = json['case'] is String ? json['case'] : (caseData['_id'] ?? '');

    return AppointmentModel(
      id: json['_id'] ?? '',
      clientId: cId,
      clientName: clientData['fullName'] ?? '',
      clientImage: clientData['profileImage'] ?? '',
      lawyerId: lId,
      lawyerName: lawyerData['fullName'] ?? '',
      lawyerImage: lawyerData['profileImage'] ?? '',
      caseId: csId.isNotEmpty ? csId : null,
      caseTitle: caseData['title'],
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      timeSlot: json['timeSlot'] ?? '',
      mode: json['mode'] ?? 'Chat',
      status: json['status'] ?? 'pending',
    );
  }
}
