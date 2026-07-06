import 'document_model.dart';

class IssueModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final String urgency;
  final String preferredLanguage;
  final String location;
  final String preferredMode;
  final List<DocumentModel> documents;
  final List<DocumentModel> images;
  final String clientId;
  final DateTime createdAt;
  final DateTime updatedAt;

  IssueModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.urgency,
    required this.preferredLanguage,
    required this.location,
    required this.preferredMode,
    required this.documents,
    required this.images,
    required this.clientId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    var docsList = json['documents'] as List? ?? [];
    var imgsList = json['images'] as List? ?? [];
    
    final clientVal = json['clientId'] is Map ? (json['clientId']['_id'] ?? '') : (json['clientId'] ?? '');

    return IssueModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      status: json['status'] ?? 'Pending',
      urgency: json['urgency'] ?? 'Flexible',
      preferredLanguage: json['preferredLanguage'] ?? 'English',
      location: json['location'] ?? '',
      preferredMode: json['preferredMode'] ?? 'Video',
      documents: docsList.map((d) => DocumentModel.fromJson(d)).toList(),
      images: imgsList.map((d) => DocumentModel.fromJson(d)).toList(),
      clientId: clientVal,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'urgency': urgency,
      'preferredLanguage': preferredLanguage,
      'location': location,
      'preferredMode': preferredMode,
      'documents': documents.map((d) => d.toJson()).toList(),
      'images': images.map((d) => d.toJson()).toList(),
    };
  }
}
