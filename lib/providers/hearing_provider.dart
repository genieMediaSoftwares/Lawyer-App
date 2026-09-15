import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../models/hearing_model.dart';
import 'auth_provider.dart';
import 'case_provider.dart';

/// Every hearing across the advocate's own cases.
///
/// Fetched from `/cases/hearings/mine` rather than derived from
/// [casesProvider]: that list also carries the open Submitted leads any lawyer
/// can see, none of which have hearings, and the server can select only the
/// cases that actually have one.
///
/// Watching [casesProvider] keeps this in step with the `/cases` socket without
/// a second subscription — adding, editing or removing a hearing emits
/// `case_updated`, which refreshes that provider, which re-runs this one.
final lawyerHearingsProvider = FutureProvider<List<HearingModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.role != UserRole.lawyer) return const [];

  final casesAsync = ref.watch(casesProvider);

  try {
    final response = await DioClient.dio.get('/cases/hearings/mine');
    if (response.data != null && response.data['success'] == true) {
      final raw = response.data['data'];
      final list = raw is List ? raw : List.from(raw as Iterable? ?? []);
      return list
          .map(
            (item) => HearingModel.fromJson(
              item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{},
            ),
          )
          .toList();
    }
  } catch (e) {
    // If backend endpoint is unavailable (e.g. 404 on unupdated server), fall
    // back gracefully to building hearings list from loaded cases.
    final cases = casesAsync.value ?? [];
    final fallbackHearings = <HearingModel>[];
    for (final c in cases) {
      for (final h in c.hearings) {
        fallbackHearings.add(
          HearingModel(
            id: h.id,
            date: h.date,
            timeSlot: h.timeSlot,
            court: h.court.isNotEmpty ? h.court : (c.preferredCourt ?? ''),
            purpose: h.purpose,
            status: h.status,
            notes: h.notes,
            caseId: c.id,
            caseTitle: c.title,
            caseCategory: c.category,
            caseStatus: c.status,
            clientId: c.clientId,
            clientName: c.clientName,
            clientImage: c.clientImage,
          ),
        );
      }
    }
    fallbackHearings.sort((a, b) => a.date.compareTo(b.date));
    return fallbackHearings;
  }

  return const [];
});

/// Hearings still ahead, earliest first.
final upcomingHearingsProvider = Provider<AsyncValue<List<HearingModel>>>((ref) {
  return ref
      .watch(lawyerHearingsProvider)
      .whenData((h) => h.where((x) => x.isUpcoming).toList());
});

/// Hearings already dealt with, most recent first.
final pastHearingsProvider = Provider<AsyncValue<List<HearingModel>>>((ref) {
  return ref.watch(lawyerHearingsProvider).whenData((hearings) {
    final past = hearings.where((h) => h.isPast).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return past;
  });
});

/// Writes against `/cases/:id/hearings`.
///
/// Not a StateNotifier: the hearings themselves live on the case, so after a
/// write the authoritative refresh is a case refetch. Each method asks
/// [CaseNotifier.caseChanged] to fan that out, which updates the case list, the
/// workspace counts and this provider in one pass.
class HearingRepository {
  const HearingRepository(this._ref);

  final Ref _ref;

  /// Surfaces the server's own message ("Hearing date is required.", "You are
  /// not assigned to this case.") rather than a Dio wrapper, so the sheet can
  /// tell the advocate what to fix.
  String _messageFrom(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      return error.message ?? 'Something went wrong.';
    }
    return error.toString();
  }

  Future<void> _refresh() async {
    await _ref.read(casesProvider.notifier).caseChanged();
    _ref.invalidate(lawyerHearingsProvider);
  }

  Future<String?> addHearing({
    required String caseId,
    required DateTime date,
    String timeSlot = '',
    String court = '',
    String purpose = '',
    String notes = '',
  }) async {
    try {
      final response = await DioClient.dio.post(
        '/cases/$caseId/hearings',
        data: {
          'date': date.toIso8601String(),
          'timeSlot': timeSlot,
          'court': court,
          'purpose': purpose,
          'notes': notes,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        await _refresh();
        return null;
      }
      return response.data?['message']?.toString() ?? 'Could not add the hearing.';
    } catch (e) {
      return _messageFrom(e);
    }
  }

  /// Only the named arguments that are non-null are sent, so a status change
  /// cannot blank out the court or the notes the advocate already recorded.
  Future<String?> updateHearing({
    required String caseId,
    required String hearingId,
    DateTime? date,
    String? timeSlot,
    String? court,
    String? purpose,
    String? status,
    String? notes,
  }) async {
    try {
      final response = await DioClient.dio.put(
        '/cases/$caseId/hearings/$hearingId',
        data: {
          if (date != null) 'date': date.toIso8601String(),
          'timeSlot': ?timeSlot,
          'court': ?court,
          'purpose': ?purpose,
          'status': ?status,
          'notes': ?notes,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        await _refresh();
        return null;
      }
      return response.data?['message']?.toString() ??
          'Could not update the hearing.';
    } catch (e) {
      return _messageFrom(e);
    }
  }

  Future<String?> deleteHearing({
    required String caseId,
    required String hearingId,
  }) async {
    try {
      final response = await DioClient.dio.delete(
        '/cases/$caseId/hearings/$hearingId',
      );
      if (response.data != null && response.data['success'] == true) {
        await _refresh();
        return null;
      }
      return response.data?['message']?.toString() ??
          'Could not remove the hearing.';
    } catch (e) {
      return _messageFrom(e);
    }
  }
}

final hearingRepositoryProvider = Provider<HearingRepository>(
  (ref) => HearingRepository(ref),
);
