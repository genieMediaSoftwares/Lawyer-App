import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminLawyerVerificationScreen extends ConsumerWidget {
  const AdminLawyerVerificationScreen({super.key});

  void _rejectLawyer(BuildContext context, WidgetRef ref, String lawyerId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Reject Lawyer Verification', style: TextStyle(color: AppColors.primaryText, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a reason for rejecting this bar verification:', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppColors.primaryText),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Invalid Bar Council ID / Document Unclear',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final repo = ref.read(adminRepositoryProvider);
              await repo.verifyLawyer(
                lawyerId: lawyerId,
                status: 'rejected',
                rejectionReason: reasonController.text,
              );
              ref.invalidate(adminPendingLawyersProvider);
              ref.invalidate(adminLawyersProvider);
              ref.invalidate(adminStatsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lawyer verification rejected')),
                );
              }
            },
            child: const Text('Confirm Reject', style: TextStyle(color: AppColors.primaryText)),
          ),
        ],
      ),
    );
  }

  void _approveLawyer(BuildContext context, WidgetRef ref, String lawyerId) async {
    final repo = ref.read(adminRepositoryProvider);
    final success = await repo.verifyLawyer(
      lawyerId: lawyerId,
      status: 'verified',
    );
    if (success) {
      ref.invalidate(adminPendingLawyersProvider);
      ref.invalidate(adminLawyersProvider);
      ref.invalidate(adminStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lawyer verified and approved successfully! 🎉')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(adminPendingLawyersProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Lawyer Verification Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminPendingLawyersProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(adminPendingLawyersProvider),
        color: AppColors.primaryGold,
        backgroundColor: AppColors.cardBackground,
        child: pendingAsync.when(
          data: (pendingLawyers) {
            if (pendingLawyers.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
                    SizedBox(height: 14),
                    Text('No Pending Verifications', style: TextStyle(color: AppColors.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('All advocate profiles have been processed', style: TextStyle(color: AppColors.mutedText, fontSize: 13)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingLawyers.length,
              itemBuilder: (context, index) {
                final lawyer = pendingLawyers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.secondaryBackground,
                            backgroundImage: lawyer.profileImage.isNotEmpty ? NetworkImage(lawyer.profileImage) : null,
                            child: lawyer.profileImage.isEmpty
                                ? Text(
                                    lawyer.fullName.isNotEmpty ? lawyer.fullName[0].toUpperCase() : 'L',
                                    style: const TextStyle(color: AppColors.primaryGold, fontSize: 18, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lawyer.fullName.startsWith('Adv.') ? lawyer.fullName : 'Adv. ${lawyer.fullName}',
                                  style: const TextStyle(color: AppColors.primaryText, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${lawyer.specialization} • ${lawyer.experience} yrs Exp',
                                  style: const TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bar Council ID: ${lawyer.barCouncilNumber.isNotEmpty ? lawyer.barCouncilNumber : "BAR-${lawyer.id.substring(0, 6).toUpperCase()}"}',
                                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.divider),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primaryGold),
                            label: const Text('View Credentials', style: TextStyle(color: AppColors.primaryGold, fontSize: 12)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.cardBackground,
                                  title: Text(lawyer.fullName, style: const TextStyle(color: AppColors.primaryText)),
                                  content: Text(
                                    'Email: ${lawyer.email}\nPhone: ${lawyer.mobile}\nSpecialization: ${lawyer.specialization}\nBar Council No: ${lawyer.barCouncilNumber}',
                                    style: const TextStyle(color: AppColors.secondaryText),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close', style: TextStyle(color: AppColors.primaryGold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () => _rejectLawyer(context, ref, lawyer.id),
                                child: const Text('Reject', style: TextStyle(color: AppColors.error, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () => _approveLawyer(context, ref, lawyer.id),
                                child: const Text('Approve', style: TextStyle(color: AppColors.onGold, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
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
            child: Text('Failed to load pending queue: $err', style: const TextStyle(color: AppColors.error)),
          ),
        ),
      ),
    );
  }
}
