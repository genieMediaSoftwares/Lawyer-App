import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/review_provider.dart';

class LawyerReviewsScreen extends ConsumerWidget {
  const LawyerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(authProvider).userId ?? "";
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));
    final combinedReviewsState = ref.watch(combinedReviewsProvider(userId));
    final casesState = ref.watch(casesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Reviews & Feedback",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: lawyerState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error loading reviews: $err")),
        data: (lawyer) {
          return combinedReviewsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error loading reviews: $err")),
            data: (reviews) {
              final int totalReviewsCount = reviews.length;
              
              // Calculate dynamic average rating
              final double averageRating = totalReviewsCount == 0
                  ? 0.0
                  : double.parse((reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviewsCount).toStringAsFixed(1));

              // Calculate star percentages
              final double pct5 = totalReviewsCount == 0 ? 0.0 : reviews.where((r) => r.rating.round() == 5).length / totalReviewsCount;
              final double pct4 = totalReviewsCount == 0 ? 0.0 : reviews.where((r) => r.rating.round() == 4).length / totalReviewsCount;
              final double pct3 = totalReviewsCount == 0 ? 0.0 : reviews.where((r) => r.rating.round() == 3).length / totalReviewsCount;
              final double pct2 = totalReviewsCount == 0 ? 0.0 : reviews.where((r) => r.rating.round() == 2).length / totalReviewsCount;
              final double pct1 = totalReviewsCount == 0 ? 0.0 : reviews.where((r) => r.rating.round() == 1).length / totalReviewsCount;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Dynamic Rating Overview Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outline, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Big Score
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                totalReviewsCount == 0 ? "0.0" : "$averageRating",
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (index) {
                                  final isGold = index < averageRating.round();
                                  return Icon(
                                    Icons.star,
                                    color: isGold ? Colors.amber : theme.colorScheme.outline,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Based on $totalReviewsCount reviews",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          // Bar Breakdown
                          Expanded(
                            child: Column(
                              children: [
                                _buildStarBar(5, pct5, theme),
                                const SizedBox(height: 4),
                                _buildStarBar(4, pct4, theme),
                                const SizedBox(height: 4),
                                _buildStarBar(3, pct3, theme),
                                const SizedBox(height: 4),
                                _buildStarBar(2, pct2, theme),
                                const SizedBox(height: 4),
                                _buildStarBar(1, pct1, theme),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Review List Header
                    Text(
                      "CLIENT FEEDBACKS ($totalReviewsCount)",
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Empty State
                    if (reviews.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rate_review_outlined, size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                "No Reviews Yet",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Client reviews will appear here once your cases or consultations are resolved.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // 2. Dynamic Reviews List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final rev = reviews[index];
                          final dateStr = DateFormat('dd MMM yyyy').format(rev.createdAt);

                          // Find matching case to show case category type
                          final matchingCase = casesState.maybeWhen(
                            data: (casesList) => casesList.firstWhere(
                              (c) => (c.assignedLawyerId == userId || c.selectedLawyerId == userId) && c.clientId == rev.clientId,
                              orElse: () => null as dynamic, // Safe null return cast
                            ),
                            orElse: () => null,
                          );
                          final caseType = matchingCase != null ? matchingCase.category : "Consultation";

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color ?? theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outline, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rev.clientName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  caseType,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: List.generate(5, (starIdx) {
                                    final isGold = starIdx < rev.rating.round();
                                    return Icon(
                                      Icons.star,
                                      color: isGold ? Colors.amber : theme.colorScheme.outline,
                                      size: 14,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rev.comment,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.textTheme.bodyMedium?.color,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStarBar(int stars, double pct, ThemeData theme) {
    return Row(
      children: [
        Text(
          "$stars",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.star, color: Colors.amber, size: 10),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            "${(pct * 100).toInt()}%",
            style: TextStyle(
              fontSize: 10,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
