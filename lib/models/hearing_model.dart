/// A court hearing listed on a case.
///
/// Deliberately distinct from [AppointmentModel], which is a lawyer-client
/// consultation booked through the app and synced to Google Calendar. The two
/// were kept apart on the server for the same reason and must stay apart here:
/// an advocate reading "3 events today" needs to know which of them is a court
/// appearance and which is a call with a client.
///
/// Hearings arrive from two shapes of response and this one model reads both:
///   * embedded in a case (`GET /cases/:id` -> `hearings[]`), where the case
///     context is already known and the `case*` fields below are absent;
///   * flattened across every case (`GET /cases/hearings/mine`), where the
///     server attaches the case and client it came from.
class HearingModel {
  final String id;
  final DateTime date;

  /// Free text as entered ("10:30 AM", "Item 42"). Courts do not publish
  /// precise slots, so this is never parsed as a time.
  final String timeSlot;
  final String court;
  final String purpose;

  /// One of `scheduled`, `completed`, `adjourned`, `cancelled`.
  final String status;
  final String notes;

  /// Populated only by the cross-case listing. Empty when the hearing was read
  /// from inside a case that the caller already has.
  final String caseId;
  final String caseTitle;
  final String caseCategory;
  final String caseStatus;
  final String clientId;
  final String clientName;
  final String clientImage;

  const HearingModel({
    required this.id,
    required this.date,
    this.timeSlot = '',
    this.court = '',
    this.purpose = '',
    this.status = 'scheduled',
    this.notes = '',
    this.caseId = '',
    this.caseTitle = '',
    this.caseCategory = '',
    this.caseStatus = '',
    this.clientId = '',
    this.clientName = '',
    this.clientImage = '',
  });

  /// True while the hearing is still ahead and has not been disposed of.
  ///
  /// Compared against the start of today rather than the current instant, so a
  /// hearing listed for 10:30 this morning still reads as upcoming at 2pm —
  /// an advocate checking their list after lunch has not finished with it.
  bool get isUpcoming {
    if (status != 'scheduled') return false;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return !date.isBefore(startOfToday);
  }

  bool get isPast => !isUpcoming;

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  /// Pulls an id out of a field that may be a bare string or a populated
  /// document, which is how the server returns refs depending on the endpoint.
  static String _id(dynamic value) {
    if (value == null) return '';
    if (value is Map) return value['_id']?.toString() ?? '';
    return value.toString();
  }

  factory HearingModel.fromJson(Map<String, dynamic> json) {
    return HearingModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      // A hearing cannot exist without a date on the server, where it is
      // `required`. Falling back to "now" rather than throwing keeps one
      // malformed record from taking down the whole list.
      date: _date(json['date']) ?? DateTime.now(),
      timeSlot: json['timeSlot']?.toString() ?? '',
      court: json['court']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      status: json['status']?.toString() ?? 'scheduled',
      notes: json['notes']?.toString() ?? '',
      caseId: _id(json['caseId']),
      caseTitle: json['caseTitle']?.toString() ?? '',
      caseCategory: json['caseCategory']?.toString() ?? '',
      caseStatus: json['caseStatus']?.toString() ?? '',
      clientId: _id(json['clientId']),
      clientName: json['clientName']?.toString() ?? '',
      clientImage: json['clientImage']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'timeSlot': timeSlot,
    'court': court,
    'purpose': purpose,
    'status': status,
    'notes': notes,
  };
}
