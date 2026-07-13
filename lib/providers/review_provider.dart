import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import 'case_provider.dart';

class ReviewRecord {
  final String id;
  final String lawyerId;
  final String clientId;
  final String clientName;
  final String clientPhoto;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ReviewRecord({
    required this.id,
    required this.lawyerId,
    required this.clientId,
    required this.clientName,
    required this.clientPhoto,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewRecord.fromJson(Map<String, dynamic> json) {
    final clientData = json['client'] is Map<String, dynamic> ? json['client'] : {};
    final clientName = clientData['fullName'] ?? 'Client';
    final clientPhoto = clientData['profileImage'] ?? '';
    return ReviewRecord(
      id: json['_id'] ?? '',
      lawyerId: json['lawyer'] ?? '',
      clientId: clientData['_id'] ?? (json['client'] is String ? json['client'] : ''),
      clientName: clientName,
      clientPhoto: clientPhoto,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['review'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}

final lawyerReviewsProvider = FutureProvider.family<List<ReviewRecord>, String>((ref, lawyerId) async {
  final response = await DioClient.dio.get("/reviews?lawyerId=$lawyerId");
  if (response.data != null && response.data['success'] == true) {
    final list = response.data['data'] as List;
    return list.map((item) => ReviewRecord.fromJson(item)).toList();
  }
  return [];
});

final combinedReviewsProvider = Provider.family<AsyncValue<List<ReviewRecord>>, String>((ref, lawyerId) {
  final reviewsAsync = ref.watch(lawyerReviewsProvider(lawyerId));
  final casesAsync = ref.watch(casesProvider);

  return reviewsAsync.when(
    data: (apiReviews) {
      return casesAsync.when(
        data: (cases) {
          final List<ReviewRecord> merged = [...apiReviews];
          
          for (final c in cases) {
            final isLawyerCase = c.assignedLawyerId == lawyerId || c.selectedLawyerId == lawyerId;
            final hasCaseReview = c.rating != null && c.rating! > 0 && c.review != null && c.review!.trim().isNotEmpty;
            if (isLawyerCase && hasCaseReview) {
              final exists = apiReviews.any((r) => r.comment.trim() == c.review!.trim() && r.clientId == c.clientId);
              if (!exists) {
                merged.add(ReviewRecord(
                  id: c.id,
                  lawyerId: lawyerId,
                  clientId: c.clientId,
                  clientName: c.clientName,
                  clientPhoto: c.clientImage,
                  rating: c.rating!,
                  comment: c.review!,
                  createdAt: c.completedAt ?? c.createdAt,
                ));
              }
            }
          }
          
          merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return AsyncValue.data(merged);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});
