/// A private practice note an advocate keeps about a client, optionally filed
/// against one of that client's cases.
///
/// Privacy is enforced on the server, not here: `GET /clients/:id/notes`
/// returns only the notes authored by the requesting advocate, and the client
/// themselves has no endpoint that reads the array at all. Nothing in this
/// model should be taken as a reason to relax that — the UI never receives
/// another advocate's notes to begin with.
class CaseNoteModel {
  final String id;

  /// The client user this note is filed under. Supplied by the caller rather
  /// than the payload: the notes endpoint is already scoped to one client, so
  /// the server does not repeat the id on every row.
  final String clientId;

  /// Empty for a general note about the client that is not tied to one matter.
  final String caseId;
  final String title;
  final String text;
  final DateTime date;
  final DateTime updatedAt;

  const CaseNoteModel({
    required this.id,
    required this.clientId,
    this.caseId = '',
    this.title = '',
    required this.text,
    required this.date,
    required this.updatedAt,
  });

  /// A heading for the list. Notes written before titles existed have none, so
  /// the first line of the body stands in — trimmed, because an untitled note
  /// is usually a paragraph and the row only has space for a line of it.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = text.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled note';
    return firstLine.length <= 60 ? firstLine : '${firstLine.substring(0, 60)}…';
  }

  bool get isEdited => updatedAt.difference(date).inMinutes.abs() > 1;

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _id(dynamic value) {
    if (value == null) return '';
    if (value is Map) return value['_id']?.toString() ?? '';
    return value.toString();
  }

  factory CaseNoteModel.fromJson(
    Map<String, dynamic> json, {
    String clientId = '',
  }) {
    final created = _date(json['date']) ?? DateTime.now();
    return CaseNoteModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      clientId: clientId.isNotEmpty ? clientId : _id(json['clientId']),
      caseId: _id(json['case']),
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      date: created,
      // Notes written before this field existed have no updatedAt; treating
      // them as never edited is correct rather than a fallback.
      updatedAt: _date(json['updatedAt']) ?? created,
    );
  }
}
