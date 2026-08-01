import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminCasesScreen extends ConsumerStatefulWidget {
  const AdminCasesScreen({super.key});

  @override
  ConsumerState<AdminCasesScreen> createState() => _AdminCasesScreenState();
}

class _AdminCasesScreenState extends ConsumerState<AdminCasesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showUpdateStatusModal(BuildContext context, String caseId, String currentStatus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Update Case Status', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatusTile(bottomSheetCtx, caseId, 'Pending', AppColors.warning),
            _buildStatusTile(bottomSheetCtx, caseId, 'In Progress', AppColors.info),
            _buildStatusTile(bottomSheetCtx, caseId, 'Completed', AppColors.success),
            _buildStatusTile(bottomSheetCtx, caseId, 'Closed', AppColors.mutedText),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(BuildContext context, String caseId, String status, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(status, style: const TextStyle(color: AppColors.primaryText, fontSize: 15)),
      onTap: () async {
        Navigator.pop(context);
        final repo = ref.read(adminRepositoryProvider);
        await repo.updateCaseStatus(caseId, status);
        ref.invalidate(adminCasesProvider);
        ref.invalidate(adminStatsProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(adminCasesProvider);
    final filter = ref.watch(adminCaseFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Cases Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminCasesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.primaryText),
                  onChanged: (val) {
                    ref.read(adminCaseFilterProvider.notifier).state = AdminCaseFilter(search: val, status: filter.status);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search cases by title, case no, category...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.mutedText),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(adminCaseFilterProvider.notifier).state = AdminCaseFilter(search: '', status: filter.status);
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', filter.status),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'Pending', filter.status),
                      const SizedBox(width: 8),
                      _buildFilterChip('In Progress', 'In Progress', filter.status),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', 'Completed', filter.status),
                      const SizedBox(width: 8),
                      _buildFilterChip('Closed', 'Closed', filter.status),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cases List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(adminCasesProvider),
              color: AppColors.primaryGold,
              backgroundColor: AppColors.cardBackground,
              child: casesAsync.when(
                data: (cases) {
                  if (cases.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, color: AppColors.mutedText, size: 48),
                          SizedBox(height: 12),
                          Text('No cases found', style: TextStyle(color: AppColors.secondaryText)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: cases.length,
                    itemBuilder: (context, index) {
                      final c = cases[index];
                      final statusColor = c.status.toLowerCase().contains('progress')
                          ? AppColors.statInfo
                          : c.status.toLowerCase().contains('completed')
                              ? AppColors.statusSuccessFg
                              : c.status.toLowerCase().contains('closed')
                                  ? AppColors.mutedText
                                  : AppColors.warning;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'CASE-#${c.id.length >= 6 ? c.id.substring(0, 6).toUpperCase() : c.id}',
                                  style: const TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    c.status,
                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.title,
                              style: const TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Category: ${c.category}',
                              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: AppColors.secondaryText),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.clientName.isNotEmpty ? c.clientName : 'Client User',
                                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondaryBackground,
                                    side: const BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _showUpdateStatusModal(context, c.id, c.status),
                                  child: const Text('Update Status', style: TextStyle(color: AppColors.primaryGold, fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                error: (err, stack) => Center(
                  child: Text('Error loading cases: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentStatus) {
    final isSelected = currentStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          final filter = ref.read(adminCaseFilterProvider);
          ref.read(adminCaseFilterProvider.notifier).state = AdminCaseFilter(search: filter.search, status: value);
        }
      },
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.cardBackground,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onGold : AppColors.primaryGold,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
