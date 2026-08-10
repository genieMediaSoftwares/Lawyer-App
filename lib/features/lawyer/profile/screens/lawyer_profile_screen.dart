import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_circle_avatar.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import 'lawyer_my_profile_screen.dart';
import 'lawyer_professional_details_screen.dart';
import 'lawyer_documents_screen.dart';

import '../../../../providers/review_provider.dart';
import '../../../../providers/case_provider.dart';

class LawyerProfileScreen extends ConsumerStatefulWidget {
  const LawyerProfileScreen({super.key});

  @override
  ConsumerState<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends ConsumerState<LawyerProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final userId = authState.userId ?? "";
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));
    final casesState = ref.watch(casesProvider);
    final reviewsState = ref.watch(combinedReviewsProvider(userId));
    final loc = AppLocalizations.of(context)!;

    int dynamicCasesHandled = 0;
    int dynamicWinPercentage = 0;
    double dynamicRating = 0.0;

    casesState.whenData((cases) {
      final lawyerCases = cases.where((c) => c.assignedLawyerId == userId || c.selectedLawyerId == userId).toList();
      dynamicCasesHandled = lawyerCases.where((c) => 
        c.status == 'Accepted' || c.status == 'In Progress' || c.status == 'Closed' || c.status == 'Completed'
      ).length;
      
      final completedCases = lawyerCases.where((c) => c.status == 'Closed' || c.status == 'Completed').toList();
      final wonCases = completedCases.where((c) => 
        c.caseOutcome != null && 
        c.caseOutcome!.isNotEmpty && 
        !c.caseOutcome!.toLowerCase().contains('lost') && 
        !c.caseOutcome!.toLowerCase().contains('defeat')
      ).toList();
      
      dynamicWinPercentage = completedCases.isEmpty ? 0 : ((wonCases.length / completedCases.length) * 100).round();
    });

    reviewsState.whenData((reviews) {
      dynamicRating = reviews.isEmpty 
          ? 0.0 
          : double.parse((reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length).toStringAsFixed(1));
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lawyerDetailsProvider(userId));
          ref.invalidate(casesProvider);
          ref.invalidate(lawyerReviewsProvider(userId));
          try {
            await ref.read(lawyerDetailsProvider(userId).future);
          } catch (_) {}
        },
        color: theme.colorScheme.primary,
        backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
        child: lawyerState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      loc.failed_to_load_profile,
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(lawyerDetailsProvider(userId)),
                      child: Text(loc.retry),
                    )
                  ],
                ),
              ),
            ),
          ),
          data: (lawyer) => _buildProfileContent(
            lawyer: lawyer,
            casesHandled: dynamicCasesHandled,
            winPercentage: dynamicWinPercentage,
            rating: dynamicRating,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent({
    required LawyerModel lawyer,
    required int casesHandled,
    required int winPercentage,
    required double rating,
  }) {
    final theme = Theme.of(context);
    final completionPct = _calculateCompletion(lawyer);
    final loc = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Premium Minimal Profile Summary (Tapping navigates to My Profile)
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const LawyerMyProfileScreen()),
            ),
            child: _buildMinimalProfileHeader(lawyer),
          ),
          const SizedBox(height: 16),

          // 2. Profile Completion Progress Bar
          _buildCompletionCard(completionPct),
          const SizedBox(height: 20),

          // 3. Statistics Row
          _buildStatisticsRow(
            casesHandled: casesHandled,
            winPercentage: winPercentage,
            rating: rating,
          ),
          const SizedBox(height: 24),

          // Header for Account Management
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              loc.account_professional_details_header,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? AppColors.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // 4. Account Details Section
          Material(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline, width: 1),
            ),
            child: Column(
              children: [
                _buildMenuRow(
                  icon: Icons.person_outline,
                  title: loc.my_profile,
                  subtitle: loc.profile_photo_subtitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LawyerMyProfileScreen()),
                  ),
                ),
                Divider(color: theme.colorScheme.outline, height: 1),
                _buildMenuRow(
                  icon: Icons.gavel_outlined,
                  title: loc.professional_details,
                  subtitle: loc.professional_info_subtitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LawyerProfessionalDetailsScreen()),
                  ),
                ),
                Divider(color: theme.colorScheme.outline, height: 1),
                _buildMenuRow(
                  icon: Icons.description_outlined,
                  title: loc.my_documents,
                  subtitle: loc.documents_subtitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LawyerDocumentsScreen()),
                  ),
                ),
                Divider(color: theme.colorScheme.outline, height: 1),
                _buildMenuRow(
                  icon: Icons.settings_outlined,
                  title: loc.settings,
                  subtitle: loc.settings_subtitle,
                  onTap: () => context.push(RouteNames.lawyerSettings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 6. Red Logout Button Card
          InkWell(
            onTap: () => ref.read(authProvider.notifier).logout(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.error, width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    loc.logout,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMinimalProfileHeader(LawyerModel lawyer) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          AppCircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.outline,
            imageUrl: lawyer.profileImage.isNotEmpty
                ? AppConfig.getAttachmentUrl(lawyer.profileImage)
                : null,
            fallback: Text(
              lawyer.fullName.isNotEmpty ? lawyer.fullName[0].toUpperCase() : 'A',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${loc.advocate_prefix} ${lawyer.fullName}",
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color ?? AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      lawyer.isVerified ? Icons.verified : Icons.pending_actions,
                      color: lawyer.isVerified ? theme.colorScheme.primary : AppColors.mutedText,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lawyer.isVerified ? loc.verified_advocate : loc.verification_pending,
                      style: TextStyle(
                        color: lawyer.isVerified ? theme.colorScheme.primary : AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(double percentage) {
    final theme = Theme.of(context);
    final isDone = percentage >= 1.0;
    final loc = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.profile_completion,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                "${(percentage * 100).toInt()}%",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isDone
                ? loc.profile_complete_tip
                : loc.profile_incomplete_tip,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow({
    required int casesHandled,
    required int winPercentage,
    required double rating,
  }) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: loc.cases_handled,
            value: "$casesHandled",
            icon: Icons.cases_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            label: loc.win_rate,
            value: "$winPercentage%",
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            label: loc.rating,
            value: rating == 0.0 ? "N/A" : "$rating",
            icon: Icons.star,
            iconColor: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: theme.colorScheme.primary, size: 24),
      title: Text(
        title,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 20),
    );
  }

  double _calculateCompletion(LawyerModel lawyer) {
    int total = 14;
    int filled = 0;

    if (lawyer.fullName.isNotEmpty) filled++;
    if (lawyer.email.isNotEmpty) filled++;
    if (lawyer.mobile.isNotEmpty) filled++;
    if (lawyer.profileImage.isNotEmpty) filled++;
    if (lawyer.specialization.isNotEmpty) filled++;
    if (lawyer.experience > 0) filled++;
    if (lawyer.education.isNotEmpty) filled++;
    if (lawyer.consultationFee > 0) filled++;
    if (lawyer.bio.isNotEmpty) filled++;
    if (lawyer.barCouncilNumber.isNotEmpty) filled++;
    if (lawyer.location.isNotEmpty) filled++;
    if (lawyer.officeAddress.isNotEmpty) filled++;
    if (lawyer.upiId.isNotEmpty) filled++;

    // check bank details
    final bank = lawyer.bankDetails;
    final hasBank = bank['bankName']?.toString().isNotEmpty == true ||
        bank['accountNumber']?.toString().isNotEmpty == true;
    if (hasBank) filled++;

    return filled / total;
  }
}
