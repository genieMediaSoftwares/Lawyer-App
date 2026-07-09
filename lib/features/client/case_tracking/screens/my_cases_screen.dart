import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../providers/chat_provider.dart';

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

    int allCount = 0;
    int progressCount = 0;
    int closedCount = 0;

    allCasesState.whenData((cases) {
      allCount = cases.length;
      progressCount = cases.where((c) => c.status == 'In Progress' || c.status == 'Awaiting Lawyer Acceptance').length;
      closedCount = cases.where((c) => c.status == 'Closed').length;
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        title: const Text(
          "My Cases",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE6B325),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE6B325),
          indicatorWeight: 2.0,
          tabs: [
            Tab(text: "All Cases ($allCount)"),
            Tab(text: "In Progress ($progressCount)"),
            Tab(text: "Closed ($closedCount)"),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filter Row + Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _buildSearchAndSortBar(),
                  const SizedBox(height: 12),
                  allCasesState.when(
                    data: (cases) => _buildStatisticsRow(cases),
                    loading: () => const ShimmerBox(width: double.infinity, height: 60),
                    error: (e, s) => const SizedBox(),
                  ),
                ],
              ),
            ),

            // Tab View Lists
            Expanded(
              child: filteredCasesState.when(
                data: (cases) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCaseList(cases, 0, "No cases posted yet."),
                      _buildCaseList(
                        cases.where((c) => c.status == 'In Progress' || c.status == 'Awaiting Lawyer Acceptance').toList(),
                        1,
                        "No cases are currently in progress.",
                      ),
                      _buildCaseList(
                        cases.where((c) => c.status == 'Closed').toList(),
                        2,
                        "No completed cases yet.",
                      ),
                    ],
                  );
                },
                loading: () => _buildShimmerLoading(),
                error: (err, stack) => _buildErrorWidget(err.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF282828)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(caseSearchProvider.notifier).state = val;
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: "Search by case title, lawyer or ID...",
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(caseSearchProvider.notifier).state = "";
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _showSortBottomSheet(context),
          child: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF282828)),
            ),
            child: const Center(
              child: Icon(Icons.tune, color: Color(0xFFE6B325), size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsRow(List<CaseModel> cases) {
    final total = cases.length;
    final inProgress = cases.where((c) => c.status == 'In Progress').length;
    final awaiting = cases.where((c) => c.status == 'Awaiting Lawyer Acceptance').length;
    final closed = cases.where((c) => c.status == 'Closed').length;

    String formatCount(int count) => count.toString().padLeft(2, '0');

    return Row(
      children: [
        Expanded(child: _buildStatItem("Total Cases", formatCount(total))),
        const SizedBox(width: 6),
        Expanded(child: _buildStatItem("In Progress", formatCount(inProgress))),
        const SizedBox(width: 6),
        Expanded(child: _buildStatItem("Awaiting", formatCount(awaiting))),
        const SizedBox(width: 6),
        Expanded(child: _buildStatItem("Closed", formatCount(closed))),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFE6B325),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF282828), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
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
                        color: const Color(0xFF282828),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        caseItem.category.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFE6B325),
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
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
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "#$caseId",
                      style: const TextStyle(
                        color: Colors.grey,
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
                          const Icon(Icons.gavel_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              caseItem.preferredCourt!,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
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
                        const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            caseItem.location,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
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
                  const Divider(color: Color(0xFF282828), height: 1),
                  const SizedBox(height: 14),
                  _buildInProgressDetails(caseItem),
                ],
                if (tabIndex == 2) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF282828), height: 1),
                  const SizedBox(height: 14),
                  _buildClosedDetails(caseItem),
                ],

                // Action Footer
                const SizedBox(height: 14),
                const Divider(color: Color(0xFF282828), height: 1),
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
                          style: TextStyle(color: Color(0xFFE6B325), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFFE6B325)),
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
          color: const Color(0xFF131314),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF282828)),
        ),
        child: Row(
          children: const [
            Icon(Icons.hourglass_empty, color: Color(0xFFE6B325), size: 14),
            SizedBox(width: 8),
            Text(
              "Awaiting lawyer acceptance...",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final lawyerName = caseItem.selectedLawyerName ?? caseItem.assignedLawyerName ?? "Advocate";
    final lawyerImage = caseItem.selectedLawyerImage ?? caseItem.assignedLawyerImage ?? "";
    final lawyerSpec = caseItem.selectedLawyerSpecialization ?? caseItem.assignedLawyerSpecialization ?? "Legal Expert";
    final lawyerRating = caseItem.selectedLawyerRating ?? caseItem.assignedLawyerRating ?? 4.8;
    final isVerified = caseItem.selectedLawyerVerified ?? caseItem.assignedLawyerVerified ?? true;
    final isOnline = caseItem.assignedLawyerOnline ?? true;

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2B2B2C),
              backgroundImage: lawyerImage.isNotEmpty
                  ? NetworkImage(lawyerImage)
                  : null,
              child: lawyerImage.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.grey)
                  : null,
            ),
            if (isOnline)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF181818), width: 1.5),
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
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Color(0xFFE6B325), size: 12),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                lawyerSpec,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFE6B325), size: 10),
                  const SizedBox(width: 3),
                  Text(
                    lawyerRating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                  if (chat != null) {
                    context.push('/chat/${chat.id}/$lawyerName');
                  }
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              color: const Color(0xFFE6B325),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF181818),
                    title: const Text("Call Advocate", style: TextStyle(color: Colors.white)),
                    content: Text("Do you want to initiate a secure voice call with $lawyerName?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Connecting call to $lawyerName...")),
                          );
                        },
                        child: const Text("Call Now", style: TextStyle(color: Color(0xFFE6B325))),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.phone_outlined),
              color: const Color(0xFFE6B325),
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
              color: const Color(0xFFE6B325),
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
        color: const Color(0xFF131314),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222223)),
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
            color: isCompleted ? const Color(0xFFE6B325) : const Color(0xFF2B2B2C),
            border: Border.all(
              color: isCompleted ? const Color(0xFFE6B325) : const Color(0xFF3B3B3C),
              width: 1.5,
            ),
          ),
          child: isCompleted 
              ? const Center(child: Icon(Icons.check, size: 8, color: Colors.black)) 
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCompleted ? Colors.white : Colors.grey,
            fontSize: 8,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateStr,
          style: const TextStyle(
            color: Colors.grey,
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
        color: isActive ? const Color(0xFFE6B325) : const Color(0xFF2B2B2C),
        margin: const EdgeInsets.only(bottom: 22),
      ),
    );
  }

  Widget _buildInProgressDetails(CaseModel caseItem) {
    final fee = caseItem.selectedLawyerFee ?? caseItem.assignedLawyerFee ?? 1500;
    final nextHearingStr = caseItem.nextHearing != null 
        ? DateFormat('dd MMM yyyy').format(caseItem.nextHearing!) 
        : "15 Jul 2026";
    final claimVal = (caseItem.claimAmount != null && caseItem.claimAmount!.isNotEmpty) ? caseItem.claimAmount! : "₹25,000";

    final completedCount = caseItem.milestones.where((m) => m.isCompleted).length;
    final totalMilestones = caseItem.milestones.isNotEmpty ? caseItem.milestones.length : 4;
    final progressPct = caseItem.status == 'Closed' 
        ? 1.0 
        : (completedCount > 0 ? completedCount / totalMilestones : 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Current Progress",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            Text(
              "${(progressPct * 100).toInt()}%",
              style: const TextStyle(color: Color(0xFFE6B325), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPct,
            backgroundColor: const Color(0xFF2B2B2C),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE6B325)),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131314),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF222223)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Consultation Fee",
                      style: TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹$fee",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131314),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF222223)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Next Hearing",
                      style: TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextHearingStr,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
            color: const Color(0xFF1C2237).withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2B3A67)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Colors.blue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Case Outcome",
                      style: TextStyle(color: Colors.grey, fontSize: 9),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      outcome,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                  backgroundColor: const Color(0xFF131314),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF282828)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _showReviewDialog(context, caseItem.id);
                },
                icon: Icon(
                  hasReview ? Icons.star : Icons.star_border,
                  color: const Color(0xFFE6B325),
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
                  backgroundColor: const Color(0xFF131314),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF282828)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _showCaseSummary(context, caseItem);
                },
                icon: const Icon(Icons.article_outlined, color: Colors.blue, size: 16),
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
              color: const Color(0xFF131314),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF222223)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rate_review_outlined, color: Color(0xFFE6B325), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text("Your Review", style: TextStyle(color: Colors.grey, fontSize: 9)),
                          const Spacer(),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < caseItem.rating! ? Icons.star : Icons.star_border,
                                color: const Color(0xFFE6B325),
                                size: 10,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caseItem.review ?? "",
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
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

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentSort = ref.watch(caseFilterProvider);
            final options = ["Newest", "Oldest", "Status", "Issue", "Lawyer", "Location"];
            
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sort Cases By",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option == currentSort;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            option,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFE6B325) : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected 
                              ? const Icon(Icons.check_circle, color: Color(0xFFE6B325)) 
                              : null,
                          onTap: () {
                            ref.read(caseFilterProvider.notifier).state = option;
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              backgroundColor: const Color(0xFF181818),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF282828)),
              ),
              title: const Text("Rate Advocate", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("How was your consultation experience with this advocate?", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return IconButton(
                        icon: Icon(
                          starNum <= localRating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFE6B325),
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
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write a detailed review of your experience...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      fillColor: const Color(0xFF131314),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF282828)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF282828)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE6B325)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE6B325),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final success = await ref.read(casesProvider.notifier).submitCaseReview(
                      caseId,
                      localRating,
                      reviewController.text,
                    );
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
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
      backgroundColor: const Color(0xFF181818),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "ID: #$idSuffix",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Description Summary",
                style: TextStyle(color: Color(0xFFE6B325), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                caseItem.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (caseItem.preferredCourt != null && caseItem.preferredCourt!.isNotEmpty) ...[
                const Text(
                  "Filing Court",
                  style: TextStyle(color: Color(0xFFE6B325), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  caseItem.preferredCourt!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF131314),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF282828)),
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
                color: const Color(0xFF181818),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF282828), width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.folder_open_outlined,
                  size: 56,
                  color: Color(0xFFE6B325),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Your legal journey starts here.",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Post your legal issue and connect with certified premium advocates immediately.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6B325),
                foregroundColor: Colors.black,
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
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF282828)),
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
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              "Error loading cases: $error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6B325),
                foregroundColor: Colors.black,
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
        return const Color(0xFFE6B325);
      case 'Submitted':
        return Colors.blue;
      case 'In Progress':
        return Colors.green;
      case 'Closed':
        return Colors.blue;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
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
              color: const Color(0xFF2B2B2C),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
