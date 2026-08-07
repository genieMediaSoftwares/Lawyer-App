import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/case_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../post_case/widgets/premium_audio_player.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_circle_avatar.dart';

class MyCasesScreen extends ConsumerStatefulWidget {
  const MyCasesScreen({super.key});

  @override
  ConsumerState<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends ConsumerState<MyCasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Rebuild to sync tab stats filtering
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCasesState = ref.watch(filteredCasesProvider);
    final allCasesState = ref.watch(casesProvider);
    final unreadCount = ref.watch(notificationsProvider).unreadCount;
    final loc = AppLocalizations.of(context)!;

    int allCount = 0;
    int progressCount = 0;
    int closedCount = 0;

    allCasesState.whenData((cases) {
      allCount = cases.length;
      progressCount = cases.where((c) => c.status == 'In Progress' || c.status == 'Awaiting Lawyer Acceptance').length;
      closedCount = cases.where((c) => c.status == 'Closed').length;
    });

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        title: Text(
          loc.my_cases,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryText, fontSize: 20),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primaryText, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.primaryText),
                onPressed: () => context.push(RouteNames.notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryGold,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.primaryGold,
          indicatorWeight: 2.0,
          tabs: [
            Tab(text: loc.all_cases_tab_header(allCount)),
            Tab(text: loc.in_progress_tab_header(progressCount)),
            Tab(text: loc.closed_tab_header(closedCount)),
          ],
        ),
      ),
      body: SafeArea(
        child: filteredCasesState.when(
          data: (cases) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildCaseList(cases, 0, loc.no_cases_posted_empty),
                _buildCaseList(
                  cases.where((c) => c.status == 'In Progress' || c.status == 'Awaiting Lawyer Acceptance').toList(),
                  1,
                  loc.no_cases_in_progress_empty,
                ),
                _buildCaseList(
                  cases.where((c) => c.status == 'Closed').toList(),
                  2,
                  loc.no_completed_cases_empty,
                ),
              ],
            );
          },
          loading: () => _buildShimmerLoading(),
          error: (err, stack) => _buildErrorWidget(err.toString()),
        ),
      ),
    );
  }



  Widget _buildCaseList(List<CaseModel> casesList, int tabIndex, String emptyMessage) {
    if (casesList.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: casesList.length,
      separatorBuilder: (c, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final caseItem = casesList[index];
        return _buildCaseCard(caseItem, tabIndex);
      },
    );
  }

  Widget _buildCaseCard(CaseModel caseItem, int tabIndex) {
    final formattedDate = DateFormat('dd MMM yyyy').format(caseItem.createdAt);
    final statusColor = _getStatusColor(caseItem.status);
    final caseId = caseItem.id.length > 6 
        ? caseItem.id.substring(caseItem.id.length - 6).toUpperCase() 
        : caseItem.id.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            context.push('/case-progress/${caseItem.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Status Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        caseItem.category.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Text(
                        caseItem.status,
                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title and Case ID
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        caseItem.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "#$caseId",
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Location details
                Column(
                  children: [
                    if (caseItem.preferredCourt != null && caseItem.preferredCourt!.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.gavel_outlined, size: 13, color: AppColors.mutedText),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              caseItem.preferredCourt!,
                              style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            caseItem.location,
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.mutedText),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Stepper timeline
                _buildTimeline(caseItem),
                const SizedBox(height: 14),

                // Lawyer Section
                _buildLawyerSection(caseItem),

                // Tab-specific contents
                if (tabIndex == 1) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  _buildInProgressDetails(caseItem),
                ],
                if (tabIndex == 2) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  _buildClosedDetails(caseItem),
                ],

                // Action Footer
                const SizedBox(height: 14),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.push('/case-progress/${caseItem.id}');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "View Case Details",
                          style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primaryGold),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLawyerSection(CaseModel caseItem) {
    final hasLawyer = caseItem.selectedLawyerId != null || caseItem.assignedLawyerId != null;
    if (!hasLawyer) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: const [
            Icon(Icons.hourglass_empty, color: AppColors.primaryGold, size: 14),
            SizedBox(width: 8),
            Text(
              "Awaiting lawyer acceptance...",
              style: TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final lawyerName = caseItem.selectedLawyerName ?? caseItem.assignedLawyerName ?? "Advocate";
    final lawyerImage = caseItem.selectedLawyerImage ?? caseItem.assignedLawyerImage ?? "";
    final lawyerSpec = caseItem.selectedLawyerSpecialization ?? caseItem.assignedLawyerSpecialization ?? "";
    // Unknown rating stays unknown — `?? 4.8` invented a score for lawyers who
    // had never been rated.
    final lawyerRating = caseItem.selectedLawyerRating ?? caseItem.assignedLawyerRating;
    // Critically, these must default to false, not true. `?? true` presented
    // unverified lawyers as verified and offline lawyers as online.
    final isVerified = caseItem.selectedLawyerVerified ?? caseItem.assignedLawyerVerified ?? false;
    final isOnline = caseItem.assignedLawyerOnline ?? false;

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AppCircleAvatar(
              radius: 18,
              backgroundColor: AppColors.border,
              imageUrl: lawyerImage.isNotEmpty
                  ? AppConfig.getAttachmentUrl(lawyerImage)
                  : null,
              fallback: const Icon(Icons.person, size: 18, color: AppColors.mutedText),
            ),
            if (isOnline)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cardBackground, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      lawyerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: AppColors.primaryGold, size: 12),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                lawyerSpec,
                style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Omit the star row entirely for an unrated lawyer rather than
              // showing an invented score.
              if (lawyerRating != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.primaryGold, size: 10),
                    const SizedBox(width: 3),
                    Text(
                      lawyerRating.toStringAsFixed(1),
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () async {
                final otherUserId = caseItem.selectedLawyerId ?? caseItem.assignedLawyerId;
                if (otherUserId != null) {
                  final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(otherUserId);
                  // `mounted` on the State, not `context.mounted`: this is
                  // State.context, and the two are different checks.
                  if (chat != null && mounted) {
                    unawaited(context.push('/chat/${chat.id}/$lawyerName'));
                  }
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              color: AppColors.primaryGold,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {
                final otherUserId = caseItem.selectedLawyerId ?? caseItem.assignedLawyerId;
                if (otherUserId != null) {
                  context.push('/lawyer-profile/$otherUserId');
                }
              },
              icon: const Icon(Icons.assignment_ind_outlined),
              color: AppColors.primaryGold,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(CaseModel caseItem) {
    final status = caseItem.status;
    
    bool step1 = true;
    bool step2 = status == 'Awaiting Lawyer Acceptance' || status == 'In Progress' || status == 'Closed';
    bool step3 = status == 'In Progress' || status == 'Closed';
    bool step4 = status == 'Closed';
    
    final postedStr = DateFormat('dd MMM').format(caseItem.createdAt);
    final selectedStr = step2 ? DateFormat('dd MMM').format(caseItem.createdAt.add(const Duration(days: 1))) : "Pending";
    final consultStr = caseItem.consultationDate != null 
        ? DateFormat('dd MMM').format(caseItem.consultationDate!) 
        : (step3 ? DateFormat('dd MMM').format(caseItem.createdAt.add(const Duration(days: 2))) : "Pending");
    final resolvedStr = caseItem.closedDate != null 
        ? DateFormat('dd MMM').format(caseItem.closedDate!) 
        : (step4 ? DateFormat('dd MMM').format(caseItem.createdAt.add(const Duration(days: 4))) : "Pending");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surface),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimelineStep("Posted", postedStr, step1),
          _buildTimelineConnector(step2),
          _buildTimelineStep("Selected", selectedStr, step2),
          _buildTimelineConnector(step3),
          _buildTimelineStep("Consult", consultStr, step3),
          _buildTimelineConnector(step4),
          _buildTimelineStep("Resolved", resolvedStr, step4),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, String dateStr, bool isCompleted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? AppColors.primaryGold : AppColors.border,
            border: Border.all(
              color: isCompleted ? AppColors.primaryGold : AppColors.border,
              width: 1.5,
            ),
          ),
          child: isCompleted 
              ? const Center(child: Icon(Icons.check, size: 8, color: AppColors.onGold)) 
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCompleted ? AppColors.primaryText : AppColors.mutedText,
            fontSize: 8,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateStr,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 7,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 1.5,
        color: isActive ? AppColors.primaryGold : AppColors.border,
        margin: const EdgeInsets.only(bottom: 22),
      ),
    );
  }

  Widget _buildInProgressDetails(CaseModel caseItem) {
    // A court date must never be invented. This previously fell back to the
    // literal string "15 Jul 2026" whenever no hearing was scheduled, which
    // could send a client to court on a date that does not exist — or let them
    // miss the real one.
    final nextHearingStr = caseItem.nextHearing != null
        ? DateFormat('dd MMM yyyy').format(caseItem.nextHearing!)
        : "Not scheduled";

    final completedCount = caseItem.milestones.where((m) => m.isCompleted).length;
    // Only compute progress from real milestones. The old `?? 4` denominator
    // plus a 0.4 floor drew a progress bar for cases with no milestones at all.
    final totalMilestones = caseItem.milestones.length;
    final progressPct = caseItem.status == 'Closed'
        ? 1.0
        : (totalMilestones > 0 ? completedCount / totalMilestones : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Current Progress",
              style: TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
            Text(
              "${(progressPct * 100).toInt()}%",
              style: const TextStyle(color: AppColors.primaryGold, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPct,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 12),
        // The "Consultation Fee" tile that sat beside Next Hearing was removed;
        // Next Hearing now spans the row on its own.
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.surface),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Next Hearing",
                      style: TextStyle(color: AppColors.mutedText, fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextHearingStr,
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClosedDetails(CaseModel caseItem) {
    final outcome = (caseItem.caseOutcome != null && caseItem.caseOutcome!.isNotEmpty)
        ? caseItem.caseOutcome! 
        : _getDynamicOutcome(caseItem);
    final hasReview = caseItem.rating != null && caseItem.rating! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.aiCardBackgroundAlt.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: AppColors.info, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Case Outcome",
                      style: TextStyle(color: AppColors.mutedText, fontSize: 9),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      outcome,
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryBackground,
                  foregroundColor: AppColors.primaryText,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _showReviewDialog(context, caseItem.id);
                },
                icon: Icon(
                  hasReview ? Icons.star : Icons.star_border,
                  color: AppColors.primaryGold,
                  size: 16,
                ),
                label: Text(
                  hasReview ? "Edit Review" : "Rate & Review",
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryBackground,
                  foregroundColor: AppColors.primaryText,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _showCaseSummary(context, caseItem);
                },
                icon: const Icon(Icons.article_outlined, color: AppColors.info, size: 16),
                label: const Text(
                  "Case Summary",
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        if (hasReview) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surface),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rate_review_outlined, color: AppColors.primaryGold, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text("Your Review", style: TextStyle(color: AppColors.mutedText, fontSize: 9)),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < caseItem.rating! ? Icons.star : Icons.star_border,
                                color: AppColors.primaryGold,
                                size: 10,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caseItem.review ?? "",
                        style: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getDynamicOutcome(CaseModel caseItem) {
    final title = caseItem.title.toLowerCase();
    if (title.contains("fraud") || title.contains("theft") || title.contains("cyber")) {
      return "Refund Successfully Received";
    }
    if (title.contains("divorce") || title.contains("maintenance")) {
      return "Maintenance Order Granted";
    }
    return "Accused Acquitted";
  }



  void _showReviewDialog(BuildContext context, String caseId) {
    int localRating = 5;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Text("Rate Advocate", style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("How was your consultation experience with this advocate?", style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return IconButton(
                        icon: Icon(
                          starNum <= localRating ? Icons.star : Icons.star_border,
                          color: AppColors.primaryGold,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            localRating = starNum;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write a detailed review of your experience...",
                      hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                      fillColor: AppColors.secondaryBackground,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryGold),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.mutedText)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.onGold,
                  ),
                  onPressed: () async {
                    // Resolved before the await: this callback runs in the
                    // dialog's context, which is defunct once the dialog is
                    // popped, so looking either of these up afterwards is
                    // unsafe. Both resolve to the same state objects they
                    // would have before.
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    final success = await ref.read(casesProvider.notifier).submitCaseReview(
                      caseId,
                      localRating,
                      reviewController.text,
                    );
                    navigator.pop();
                    if (success) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text("Thank you for your rating & review!")),
                      );
                    }
                  },
                  child: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCaseSummary(BuildContext context, CaseModel caseItem) {
    final startIdx = caseItem.id.length > 6 ? caseItem.id.length - 6 : 0;
    final idSuffix = caseItem.id.substring(startIdx).toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    caseItem.title,
                    style: const TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "ID: #$idSuffix",
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Description Summary",
                style: TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                caseItem.description,
                style: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
              ),
              if (caseItem.voiceUrl != null && caseItem.voiceUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                PremiumAudioPlayer(source: caseItem.voiceUrl!),
              ],
              const SizedBox(height: 20),
              if (caseItem.preferredCourt != null && caseItem.preferredCourt!.isNotEmpty) ...[
                const Text(
                  "Filing Court",
                  style: TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  caseItem.preferredCourt!,
                  style: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.7), fontSize: 13),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryBackground,
                  foregroundColor: AppColors.primaryText,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.folder_open_outlined,
                  size: 56,
                  color: AppColors.primaryGold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Your legal journey starts here.",
              style: TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Post your legal issue and connect with certified premium advocates immediately.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.onGold,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                context.push('/post-case');
              },
              child: const Text(
                "Post Your First Case",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (c, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 80, height: 18, borderRadius: 6),
                  ShimmerBox(width: 60, height: 18, borderRadius: 20),
                ],
              ),
              SizedBox(height: 12),
              ShimmerBox(width: 150, height: 20),
              SizedBox(height: 8),
              ShimmerBox(width: double.infinity, height: 40),
              SizedBox(height: 14),
              ShimmerBox(width: double.infinity, height: 50, borderRadius: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              "Error loading cases: $error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.onGold,
              ),
              onPressed: () {
                ref.read(casesProvider.notifier).fetchCases();
              },
              child: const Text("Retry", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Awaiting Lawyer Acceptance':
        return AppColors.primaryGold;
      case 'Submitted':
        return AppColors.info;
      case 'In Progress':
        return AppColors.success;
      case 'Closed':
        return AppColors.info;
      case 'Rejected':
        return AppColors.error;
      default:
        return AppColors.mutedText;
    }
  }
}

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
