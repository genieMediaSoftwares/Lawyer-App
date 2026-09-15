import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';
import '../models/case_note_model.dart';
import 'auth_provider.dart';
import 'case_provider.dart';

/// One client on an advocate's roster.
///
/// Sourced from `/clients`, which the server scopes to the clients this
/// advocate actually acts for — a case assigned to them, or a consultation
/// booked with them. There is no client-side filtering to get wrong.
class LawyerClientModel {
  final String id;
  final String fullName;
  final String email;
  final String mobile;
  final String profileImage;
  final String location;

  const LawyerClientModel({
    required this.id,
    required this.fullName,
    this.email = '',
    this.mobile = '',
    this.profileImage = '',
    this.location = '',
  });

  factory LawyerClientModel.fromJson(Map<String, dynamic> json) {
    return LawyerClientModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      profileImage: json['profileImage']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }

  /// Matches on every field an advocate might search by — a name, a phone
  /// number half-remembered, the city a matter is in.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return fullName.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q) ||
        mobile.toLowerCase().contains(q) ||
        location.toLowerCase().contains(q);
  }
}

/// The advocate's client roster.
///
/// Watches [casesProvider] so accepting a new matter adds its client here
/// without the advocate having to reopen the screen.
final lawyerClientsProvider = FutureProvider<List<LawyerClientModel>>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  if (auth.role != UserRole.lawyer) return const [];

  ref.watch(casesProvider);

  final response = await DioClient.dio.get('/clients');
  if (response.data == null || response.data['success'] != true) {
    return const [];
  }

  final raw = response.data['data'];
  final list = raw is List ? raw : List.from(raw as Iterable? ?? []);
  return list
      .map(
        (item) => LawyerClientModel.fromJson(
          item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{},
        ),
      )
      .toList();
});

final lawyerClientSearchProvider = StateProvider<String>((ref) => '');

final filteredLawyerClientsProvider =
    Provider<AsyncValue<List<LawyerClientModel>>>((ref) {
      final query = ref.watch(lawyerClientSearchProvider);
      return ref.watch(lawyerClientsProvider).whenData((clients) {
        final list = clients.where((c) => c.matches(query)).toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );
        return list;
      });
    });

/// The private notes this advocate has written about one client.
///
/// Keyed by client id. The server returns only the requesting advocate's own
/// notes, so nothing here needs to filter by author.
final clientNotesProvider =
    FutureProvider.family<List<CaseNoteModel>, String>((ref, clientId) async {
      if (clientId.isEmpty) return const [];

      final response = await DioClient.dio.get('/clients/$clientId/notes');
      if (response.data == null || response.data['success'] != true) {
        return const [];
      }

      final raw = response.data['data'];
      final list = raw is List ? raw : List.from(raw as Iterable? ?? []);
      return list
          .map(
            (item) => CaseNoteModel.fromJson(
              item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{},
              clientId: clientId,
            ),
          )
          .toList();
    });

/// Every note the advocate has written, across every client.
///
/// Built by fanning out over the roster rather than from a dedicated endpoint,
/// because no such endpoint exists and adding one to serve a single screen was
/// more API surface than the screen is worth. The requests run concurrently, so
/// this costs one round trip's latency rather than one per client.
final allLawyerNotesProvider = FutureProvider<List<CaseNoteModel>>((ref) async {
  final clients = await ref.watch(lawyerClientsProvider.future);
  if (clients.isEmpty) return const [];

  final results = await Future.wait(
    clients.map((c) => ref.watch(clientNotesProvider(c.id).future)),
  );

  final notes = results.expand((n) => n).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return notes;
});

/// Client id -> display name, for labelling a note with whose file it is in.
final lawyerClientNamesProvider = Provider<Map<String, String>>((ref) {
  return ref.watch(lawyerClientsProvider).maybeWhen(
    data: (clients) => {for (final c in clients) c.id: c.fullName},
    orElse: () => const {},
  );
});

/// Writes against `/clients/:id/notes`.
class ClientNoteRepository {
  const ClientNoteRepository(this._ref);

  final Ref _ref;

  String _messageFrom(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return error.message ?? 'Something went wrong.';
    }
    return error.toString();
  }

  void _refresh(String clientId) {
    _ref.invalidate(clientNotesProvider(clientId));
    _ref.invalidate(allLawyerNotesProvider);
  }

  Future<String?> addNote({
    required String clientId,
    required String text,
    String title = '',
    String caseId = '',
  }) async {
    try {
      final response = await DioClient.dio.post(
        '/clients/$clientId/notes',
        data: {
          'text': text,
          'title': title,
          // Omitted entirely rather than sent empty: the server treats a
          // present-but-empty caseId as "no case", but leaving it out keeps
          // the request honest about what was asked for.
          if (caseId.isNotEmpty) 'caseId': caseId,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        _refresh(clientId);
        return null;
      }
      return response.data?['message']?.toString() ?? 'Could not save the note.';
    } catch (e) {
      return _messageFrom(e);
    }
  }

  Future<String?> updateNote({
    required String clientId,
    required String noteId,
    String? text,
    String? title,
    String? caseId,
  }) async {
    try {
      final response = await DioClient.dio.put(
        '/clients/$clientId/notes/$noteId',
        data: {
          'text': ?text,
          'title': ?title,
          'caseId': ?caseId,
        },
      );
      if (response.data != null && response.data['success'] == true) {
        _refresh(clientId);
        return null;
      }
      return response.data?['message']?.toString() ??
          'Could not update the note.';
    } catch (e) {
      return _messageFrom(e);
    }
  }

  Future<String?> deleteNote({
    required String clientId,
    required String noteId,
  }) async {
    try {
      final response = await DioClient.dio.delete(
        '/clients/$clientId/notes/$noteId',
      );
      if (response.data != null && response.data['success'] == true) {
        _refresh(clientId);
        return null;
      }
      return response.data?['message']?.toString() ??
          'Could not delete the note.';
    } catch (e) {
      return _messageFrom(e);
    }
  }
}

final clientNoteRepositoryProvider = Provider<ClientNoteRepository>(
  (ref) => ClientNoteRepository(ref),
);
