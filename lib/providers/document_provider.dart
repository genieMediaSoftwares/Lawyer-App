import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';

class DocumentRecord {
  final String id;
  final String clientId;
  final String? issueId;
  final String originalName;
  final String fileName;
  final String filePath;
  final String mimeType;
  final int fileSize;
  final DateTime uploadedAt;

  DocumentRecord({
    required this.id,
    required this.clientId,
    this.issueId,
    required this.originalName,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.fileSize,
    required this.uploadedAt,
  });

  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    return DocumentRecord(
      id: json['_id'] ?? '',
      clientId: json['clientId'] ?? '',
      issueId: json['issueId'],
      originalName: json['originalName'] ?? '',
      fileName: json['fileName'] ?? '',
      filePath: json['filePath'] ?? '',
      mimeType: json['mimeType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      uploadedAt: json['uploadedAt'] != null ? DateTime.parse(json['uploadedAt']) : DateTime.now(),
    );
  }
}

final documentsProvider = StateNotifierProvider<DocumentNotifier, AsyncValue<List<DocumentRecord>>>((ref) {
  return DocumentNotifier();
});

class DocumentNotifier extends StateNotifier<AsyncValue<List<DocumentRecord>>> {
  DocumentNotifier() : super(const AsyncValue.loading()) {
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/documents");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final docs = list.map((item) => DocumentRecord.fromJson(item)).toList();
        state = AsyncValue.data(docs);
      } else {
        state = AsyncValue.error("Failed to load documents", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<DocumentRecord?> uploadDocument(
    String? localPath,
    String fileName, {
    List<int>? bytes,
    String? issueId,
  }) async {
    try {
      MultipartFile filePayload;
      if (bytes != null) {
        filePayload = MultipartFile.fromBytes(
          bytes,
          filename: fileName,
        );
      } else if (localPath != null) {
        filePayload = await MultipartFile.fromFile(
          localPath,
          filename: fileName,
        );
      } else {
        return null;
      }

      final formData = FormData.fromMap({
        "issueId": issueId ?? "",
        "acknowledgement": filePayload,
      });

      final response = await DioClient.dio.post(
        "/documents/upload",
        data: formData,
      );

      if (response.data != null && response.data['success'] == true) {
        final newDoc = DocumentRecord.fromJson(response.data['data']);
        state.whenData((currentDocs) {
          state = AsyncValue.data([newDoc, ...currentDocs]);
        });
        return newDoc;
      }
    } catch (e) {
      if (e is DioException && e.response?.data != null && e.response?.data['message'] != null) {
        throw Exception(e.response!.data['message']);
      }
      rethrow;
    }
    return null;
  }

  Future<bool> deleteDocument(String docId) async {
    try {
      final response = await DioClient.dio.delete("/documents/$docId");
      if (response.data != null && response.data['success'] == true) {
        state.whenData((currentDocs) {
          state = AsyncValue.data(currentDocs.where((d) => d.id != docId).toList());
        });
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
