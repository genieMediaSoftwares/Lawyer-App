import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/dio_client.dart';

/// How the document list is ordered. Values match the backend's `sort` query.
enum DocumentSort {
  recent('recent', 'Recently uploaded'),
  modified('modified', 'Recently modified'),
  nameAsc('name_asc', 'Name (A–Z)'),
  nameDesc('name_desc', 'Name (Z–A)'),
  sizeDesc('size_desc', 'Largest first'),
  sizeAsc('size_asc', 'Smallest first');

  const DocumentSort(this.query, this.label);
  final String query;
  final String label;
}

/// Type families the list can be narrowed to. Values match the backend's
/// `type` query, which filters on a MIME family rather than an exact type so a
/// new image format needs no client release.
enum DocumentFilter {
  all('all', 'All'),
  pdf('pdf', 'PDF'),
  doc('doc', 'DOC'),
  image('image', 'Images'),
  text('text', 'Text');

  const DocumentFilter(this.query, this.label);
  final String query;
  final String label;
}

/// A stored document, as the backend describes it.
///
/// [name] is the display name the owner chose; the server resolves it from its
/// own `name`/`originalName` pair, so the app never has to know a document was
/// never renamed.
class DocumentRecord {
  final String id;
  final String clientId;
  final String? issueId;

  /// The filename as uploaded. Kept so the client can still recognise a
  /// document they have since retitled.
  final String originalName;

  /// The display name, renamable, always carrying the real file extension.
  final String name;

  final String fileName;
  final String filePath;
  final String mimeType;
  final int fileSize;
  final DateTime uploadedAt;

  /// Last write of any kind, including a rename.
  final DateTime? updatedAt;

  /// Last time the stored bytes were replaced. Null if never replaced — which
  /// is what distinguishes "renamed" from "a different file now".
  final DateTime? contentUpdatedAt;

  const DocumentRecord({
    required this.id,
    required this.clientId,
    this.issueId,
    required this.originalName,
    required this.name,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.fileSize,
    required this.uploadedAt,
    this.updatedAt,
    this.contentUpdatedAt,
  });

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    final original = (json['originalName'] ?? '').toString();
    return DocumentRecord(
      id: (json['_id'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      issueId: json['issueId']?.toString(),
      originalName: original,
      // The server sends a resolved display name, but older builds of it did
      // not — falling back keeps this working against either.
      name: (json['name'] ?? '').toString().trim().isNotEmpty
          ? json['name'].toString().trim()
          : original,
      fileName: (json['fileName'] ?? '').toString(),
      filePath: (json['filePath'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      fileSize: (json['fileSize'] is num) ? (json['fileSize'] as num).toInt() : 0,
      uploadedAt: _date(json['uploadedAt']) ?? DateTime.now(),
      updatedAt: _date(json['updatedAt']),
      contentUpdatedAt: _date(json['contentUpdatedAt']),
    );
  }

  /// Uppercase extension without the dot — "PDF", "DOCX" — for the type badge.
  String get extensionLabel {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return 'FILE';
    return name.substring(dot + 1).toUpperCase();
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
  bool get isText => mimeType.startsWith('text/');
  bool get isAudio => mimeType.startsWith('audio/');

  /// True when the app can render this in place rather than handing it off.
  ///
  /// PDFs render through pdfrx, images and text natively. Only DOC/DOCX are
  /// left without a renderer.
  bool get canPreviewInApp => isPdf || isImage || isText;

  /// "3.8 KB", "1.2 MB" — the size as the list shows it.
  String get readableSize {
    if (fileSize <= 0) return '—';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// The query the list is currently showing.
class DocumentQuery {
  final String search;
  final DocumentFilter filter;
  final DocumentSort sort;

  const DocumentQuery({
    this.search = '',
    this.filter = DocumentFilter.all,
    this.sort = DocumentSort.recent,
  });

  DocumentQuery copyWith({
    String? search,
    DocumentFilter? filter,
    DocumentSort? sort,
  }) =>
      DocumentQuery(
        search: search ?? this.search,
        filter: filter ?? this.filter,
        sort: sort ?? this.sort,
      );
}

/// The active query, watched by the screen so its controls stay in step with
/// what is actually displayed.
final documentQueryProvider =
    StateProvider<DocumentQuery>((ref) => const DocumentQuery());

final documentsProvider =
    StateNotifierProvider<DocumentNotifier, AsyncValue<List<DocumentRecord>>>(
  (ref) => DocumentNotifier(ref),
);

class DocumentNotifier extends StateNotifier<AsyncValue<List<DocumentRecord>>> {
  DocumentNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchDocuments();
  }

  final Ref _ref;

  /// Debounces typing in the search field, so a five-letter word is one
  /// request rather than five.
  Timer? _searchDebounce;

  /// Invalidates the results of a fetch that a newer one has superseded. Without
  /// it, a slow request for "div" can land after a fast one for "divorce" and
  /// repopulate the list with the wrong results.
  int _fetchToken = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  DocumentQuery get _query => _ref.read(documentQueryProvider);

  Future<void> fetchDocuments({bool showLoading = true}) async {
    final token = ++_fetchToken;
    if (showLoading) state = const AsyncValue.loading();

    try {
      final query = _query;
      final response = await DioClient.dio.get(
        '/documents',
        queryParameters: {
          if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
          if (query.filter != DocumentFilter.all) 'type': query.filter.query,
          'sort': query.sort.query,
        },
      );

      if (token != _fetchToken || !mounted) return;

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is List) {
        final docs = (data['data'] as List)
            .whereType<Map>()
            .map((item) => DocumentRecord.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        state = AsyncValue.data(docs);
      } else {
        state = AsyncValue.error('Failed to load documents', StackTrace.current);
      }
    } catch (e, stack) {
      if (token != _fetchToken || !mounted) return;
      state = AsyncValue.error(e, stack);
    }
  }

  /// Applies a new search term, debounced.
  void search(String term) {
    _ref.read(documentQueryProvider.notifier).update((q) => q.copyWith(search: term));
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      // The list is kept on screen while re-querying: blanking it on every
      // keystroke makes the screen flash and loses the scroll position.
      fetchDocuments(showLoading: false);
    });
  }

  void setFilter(DocumentFilter filter) {
    _ref.read(documentQueryProvider.notifier).update((q) => q.copyWith(filter: filter));
    fetchDocuments(showLoading: false);
  }

  void setSort(DocumentSort sort) {
    _ref.read(documentQueryProvider.notifier).update((q) => q.copyWith(sort: sort));
    fetchDocuments(showLoading: false);
  }

  /// Pulls the server's message out of a Dio failure so the screen can show
  /// something specific ("File size exceeds the allowed limit") rather than a
  /// generic apology. Falls back to [fallback] when there is nothing useful.
  String _messageFrom(Object error, String fallback) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return 'Your session has expired. Please sign in again.';
      if (status == 403) return "You don't have permission to access this document.";
      if (status == 404) return 'Document not found.';
      if (status == 413) return 'File size exceeds the allowed limit.';

      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    }
    return fallback;
  }

  Future<DocumentRecord?> uploadDocument(
    String? localPath,
    String fileName, {
    List<int>? bytes,
    String? issueId,
  }) async {
    try {
      final MultipartFile filePayload;
      if (bytes != null) {
        filePayload = MultipartFile.fromBytes(bytes, filename: fileName);
      } else if (localPath != null) {
        filePayload = await MultipartFile.fromFile(localPath, filename: fileName);
      } else {
        return null;
      }

      final response = await DioClient.dio.post(
        '/documents/upload',
        data: FormData.fromMap({
          'issueId': issueId ?? '',
          'acknowledgement': filePayload,
        }),
      );

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final newDoc =
            DocumentRecord.fromJson(Map<String, dynamic>.from(data['data'] as Map));
        // Refetched rather than prepended: the active search, filter and sort
        // decide whether this document belongs in the visible list at all, and
        // where. Prepending put it at the top of a Z–A list, and showed it
        // under a filter it did not match.
        await fetchDocuments(showLoading: false);
        return newDoc;
      }
    } catch (e) {
      throw Exception(_messageFrom(e, 'Unable to upload document. Please try again.'));
    }
    return null;
  }

  /// Renames a document. Server-side, so the new name survives a restart, a
  /// re-login and a redeploy.
  Future<DocumentRecord?> renameDocument(String docId, String newName) async {
    try {
      final response = await DioClient.dio.patch(
        '/documents/$docId',
        data: {'name': newName},
      );

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final updated =
            DocumentRecord.fromJson(Map<String, dynamic>.from(data['data'] as Map));
        _replaceInState(updated);
        return updated;
      }
    } catch (e) {
      throw Exception(_messageFrom(e, 'Unable to rename document. Please try again.'));
    }
    return null;
  }

  /// Swaps the stored file, keeping the document's id and its place in the list.
  ///
  /// The server only commits once the new file is safely stored, so a failure
  /// here leaves the existing document untouched — which is what the error
  /// message promises.
  Future<DocumentRecord?> replaceDocument(
    String docId,
    String? localPath,
    String fileName, {
    List<int>? bytes,
  }) async {
    try {
      final MultipartFile filePayload;
      if (bytes != null) {
        filePayload = MultipartFile.fromBytes(bytes, filename: fileName);
      } else if (localPath != null) {
        filePayload = await MultipartFile.fromFile(localPath, filename: fileName);
      } else {
        return null;
      }

      final response = await DioClient.dio.post(
        '/documents/$docId/replace',
        data: FormData.fromMap({'acknowledgement': filePayload}),
      );

      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final updated =
            DocumentRecord.fromJson(Map<String, dynamic>.from(data['data'] as Map));
        _replaceInState(updated);
        return updated;
      }
    } catch (e) {
      throw Exception(_messageFrom(
        e,
        'Document replacement failed. Your existing document is still safe.',
      ));
    }
    return null;
  }

  /// Fetches a document's bytes through the authenticated client.
  ///
  /// The view endpoint is protected, so the bytes cannot be reached by handing
  /// a URL to a browser — the session token travels as a header on this
  /// request, and nothing is written to disk or to a URL along the way.
  Future<List<int>> fetchDocumentBytes(String docId) async {
    try {
      final response = await DioClient.dio.get<List<int>>(
        '/documents/$docId/view',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? const [];
    } catch (e) {
      throw Exception(_messageFrom(e, 'Unable to open this document.'));
    }
  }

  Future<bool> deleteDocument(String docId) async {
    try {
      final response = await DioClient.dio.delete('/documents/$docId');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        state.whenData((docs) {
          if (!mounted) return;
          state = AsyncValue.data(docs.where((d) => d.id != docId).toList());
        });
        return true;
      }
    } catch (e) {
      throw Exception(_messageFrom(e, 'Unable to delete document.'));
    }
    return false;
  }

  /// Swaps one document in place, so a rename or replace updates the card
  /// without reordering the list under the client's finger.
  void _replaceInState(DocumentRecord updated) {
    state.whenData((docs) {
      if (!mounted) return;
      state = AsyncValue.data([
        for (final doc in docs) doc.id == updated.id ? updated : doc,
      ]);
    });
  }
}
