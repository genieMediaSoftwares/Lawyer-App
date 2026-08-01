import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminSupportTicketsScreen extends ConsumerStatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  ConsumerState<AdminSupportTicketsScreen> createState() => _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState extends ConsumerState<AdminSupportTicketsScreen> {
  String _selectedStatus = 'all';

  void _showStatusDialog(BuildContext context, String ticketId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Update Ticket Status', style: TextStyle(color: AppColors.primaryText, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(ctx, ticketId, 'Pending', AppColors.warning),
            _buildOption(ctx, ticketId, 'Assigned', AppColors.info),
            _buildOption(ctx, ticketId, 'Resolved', AppColors.success),
            _buildOption(ctx, ticketId, 'Closed', AppColors.mutedText),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String ticketId, String status, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 12),
      title: Text(status, style: const TextStyle(color: AppColors.primaryText)),
      onTap: () async {
        Navigator.pop(context);
        final repo = ref.read(adminRepositoryProvider);
        await repo.updateSupportTicket(ticketId, status);
        ref.invalidate(adminSupportTicketsProvider);
        ref.invalidate(adminStatsProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(adminSupportTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Support Tickets & Inquiries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminSupportTicketsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'Pending', 'Assigned', 'Resolved', 'Closed'].map((st) {
                  final isSelected = _selectedStatus == st;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st == 'all' ? 'All Tickets' : st),
                      selected: isSelected,
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedStatus = st);
                      },
                      selectedColor: AppColors.primaryGold,
                      backgroundColor: AppColors.cardBackground,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.onGold : AppColors.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(adminSupportTicketsProvider),
              color: AppColors.primaryGold,
              backgroundColor: AppColors.cardBackground,
              child: ticketsAsync.when(
                data: (tickets) {
                  final filtered = tickets.where((t) {
                    return _selectedStatus == 'all' || t.status.toLowerCase() == _selectedStatus.toLowerCase();
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No support tickets found', style: TextStyle(color: AppColors.secondaryText)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      final statusColor = t.status.toLowerCase().contains('resolved')
                          ? AppColors.success
                          : t.status.toLowerCase().contains('assigned')
                              ? AppColors.info
                              : t.status.toLowerCase().contains('closed')
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
                                  'TKT-#${t.id.substring(0, 6).toUpperCase()}',
                                  style: const TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    t.status,
                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(t.title, style: const TextStyle(color: AppColors.primaryText, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(t.description, style: const TextStyle(color: AppColors.mutedText, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Category: ${t.category}', style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondaryBackground,
                                    side: const BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _showStatusDialog(context, t.id),
                                  child: const Text('Update', style: TextStyle(color: AppColors.primaryGold, fontSize: 11)),
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
                error: (err, stack) => Center(child: Text('Error loading tickets: $err', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
