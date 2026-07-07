import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class MyCasesScreen extends ConsumerStatefulWidget {
  const MyCasesScreen({super.key});

  @override
  ConsumerState<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends ConsumerState<MyCasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casesState = ref.watch(casesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("My Cases", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: theme.appBarTheme.iconTheme?.color, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: "All Cases"),
            Tab(text: "Active"),
            Tab(text: "In Progress"),
            Tab(text: "Closed"),
          ],
        ),
      ),
      body: casesState.when(
        data: (cases) {
          if (cases.isEmpty) {
            return const Center(child: Text("No cases posted yet."));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildCaseList(cases),
              _buildCaseList(cases.where((c) => c.status == 'active').toList()),
              _buildCaseList(cases.where((c) => c.status == 'in_progress').toList()),
              _buildCaseList(cases.where((c) => c.status == 'closed').toList()),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildCaseList(List<CaseModel> casesList) {
    if (casesList.isEmpty) {
      return const Center(child: Text("No cases in this category."));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: casesList.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final caseItem = casesList[index];
        return _buildCaseCard(caseItem);
      },
    );
  }

  Widget _buildCaseCard(CaseModel caseItem) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('dd MMM yyyy').format(caseItem.createdAt);
    final statusColor = _getStatusColor(context, caseItem.status);
    final statusLabel = _getStatusLabel(caseItem.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: () {
          if (caseItem.status == 'active') {
            context.push('/lawyers-responded/${caseItem.id}');
          } else {
            context.push('/case-progress/${caseItem.id}');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      caseItem.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Case ID: ${caseItem.id.substring(Math.max(0, caseItem.id.length - 8)).toUpperCase()}",
                style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(caseItem.location, style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13)),
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined, size: 16, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text("Posted on $formattedDate", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (caseItem.status == 'active') ...[
                    Text(
                      "${caseItem.proposals.length} Proposals Received",
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: theme.textTheme.bodySmall?.color),
                  ] else if (caseItem.status == 'in_progress') ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: caseItem.assignedLawyerImage != null && caseItem.assignedLawyerImage!.isNotEmpty
                              ? NetworkImage(caseItem.assignedLawyerImage!)
                              : null,
                          child: caseItem.assignedLawyerImage == null || caseItem.assignedLawyerImage!.isEmpty
                              ? const Icon(Icons.person, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          caseItem.assignedLawyerName ?? "Assigned Lawyer",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textTheme.titleMedium?.color),
                        ),
                      ],
                    ),
                    Text("Track Progress", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ] else ...[
                    Text("Case Closed", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold, fontSize: 13)),
                    const Text("Completed", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    switch (status) {
      case 'active':
        return AppColors.warning;
      case 'in_progress':
        return theme.colorScheme.primary;
      case 'closed':
        return AppColors.success;
      default:
        return theme.textTheme.bodySmall?.color ?? AppColors.mutedText;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return "Active";
      case 'in_progress':
        return "In Progress";
      case 'closed':
        return "Closed";
      default:
        return status;
    }
  }
}

class Math {
  static int max(int a, int b) => a > b ? a : b;
}
