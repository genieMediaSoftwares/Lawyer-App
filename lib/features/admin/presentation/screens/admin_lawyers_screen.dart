import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminLawyersScreen extends ConsumerStatefulWidget {
  const AdminLawyersScreen({super.key});

  @override
  ConsumerState<AdminLawyersScreen> createState() => _AdminLawyersScreenState();
}

class _AdminLawyersScreenState extends ConsumerState<AdminLawyersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showActionDialog(BuildContext context, String lawyerId, String currentStatus) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Update Lawyer Verification Status', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select action for this advocate profile:', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Rejection/Suspension reason (optional)',
                labelText: 'Notes / Reason',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final repo = ref.read(adminRepositoryProvider);
              await repo.verifyLawyer(
                lawyerId: lawyerId,
                status: 'rejected',
                rejectionReason: reasonController.text,
              );
              ref.refresh(adminLawyersProvider);
              ref.refresh(adminPendingLawyersProvider);
              ref.refresh(adminStatsProvider);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final repo = ref.read(adminRepositoryProvider);
              await repo.verifyLawyer(
                lawyerId: lawyerId,
                status: 'verified',
              );
              ref.refresh(adminLawyersProvider);
              ref.refresh(adminPendingLawyersProvider);
              ref.refresh(adminStatsProvider);
            },
            child: const Text('Approve', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lawyersAsync = ref.watch(adminLawyersProvider);
    final filter = ref.watch(adminLawyerFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Lawyer Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminLawyersProvider),
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
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    ref.read(adminLawyerFilterProvider.notifier).state = filter.copyWith(search: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search lawyers by name, specialization, bar no...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(adminLawyerFilterProvider.notifier).state = filter.copyWith(search: '');
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
                      _buildFilterChip('All', 'all', filter.verificationStatus),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', 'verified', filter.verificationStatus),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending', filter.verificationStatus),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected', 'rejected', filter.verificationStatus),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lawyers List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(adminLawyersProvider),
              color: AppColors.primaryGold,
              backgroundColor: AppColors.cardBackground,
              child: lawyersAsync.when(
                data: (lawyers) {
                  if (lawyers.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gavel, color: AppColors.mutedText, size: 48),
                          SizedBox(height: 12),
                          Text('No lawyers found', style: TextStyle(color: AppColors.secondaryText)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: lawyers.length,
                    itemBuilder: (context, index) {
                      final lawyer = lawyers[index];
                      final statusColor = lawyer.verificationStatus == 'verified'
                          ? const Color(0xFF4ADE80)
                          : lawyer.verificationStatus == 'rejected'
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFFBBF24);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.secondaryBackground,
                              backgroundImage: lawyer.profileImage.isNotEmpty ? NetworkImage(lawyer.profileImage) : null,
                              child: lawyer.profileImage.isEmpty
                                  ? Text(
                                      lawyer.fullName.isNotEmpty ? lawyer.fullName[0].toUpperCase() : 'L',
                                      style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lawyer.fullName.startsWith('Adv.') ? lawyer.fullName : 'Adv. ${lawyer.fullName}',
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: statusColor.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          lawyer.verificationStatus.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${lawyer.specialization} • ${lawyer.experience} yrs Exp',
                                    style: const TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  if (lawyer.barCouncilNumber.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Bar No: ${lawyer.barCouncilNumber}',
                                      style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: AppColors.primaryGold, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${lawyer.rating.toStringAsFixed(1)} Rating',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondaryBackground,
                                          side: const BorderSide(color: AppColors.primaryGold, width: 0.8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showActionDialog(context, lawyer.id, lawyer.verificationStatus),
                                        child: const Text('Manage', style: TextStyle(color: AppColors.primaryGold, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                error: (err, stack) => Center(
                  child: Text('Error loading lawyers: $err', style: const TextStyle(color: AppColors.error)),
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
          final filter = ref.read(adminLawyerFilterProvider);
          ref.read(adminLawyerFilterProvider.notifier).state = filter.copyWith(verificationStatus: value);
        }
      },
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.cardBackground,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.primaryGold,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
