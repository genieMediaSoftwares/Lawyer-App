import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../routes/route_names.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel, color: AppColors.primaryGold, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAWYER CONSULTATION',
                  style: TextStyle(color: AppColors.primaryGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                Text(
                  'ADMIN PANEL',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => context.push(RouteNames.adminNotifications),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
        },
        color: AppColors.primaryGold,
        backgroundColor: AppColors.cardBackground,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Day, Admin 👋',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Here's what's happening today",
                        style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Live Engine',
                          style: TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Metrics Grid
              statsAsync.when(
                data: (stats) => Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _buildStatTile(
                          context,
                          title: 'Total Clients',
                          value: '${stats.totalClients}',
                          subtext: '${stats.activeClients} Active',
                          icon: Icons.people_alt,
                          iconBg: const Color(0xFF1E293B),
                          iconColor: const Color(0xFF38BDF8),
                          onTap: () => context.push(RouteNames.adminClients),
                        ),
                        _buildStatTile(
                          context,
                          title: 'Total Lawyers',
                          value: '${stats.totalLawyers}',
                          subtext: '${stats.approvedLawyers} Approved',
                          icon: Icons.gavel,
                          iconBg: const Color(0xFF064E3B),
                          iconColor: const Color(0xFF34D399),
                          onTap: () => context.push(RouteNames.adminLawyers),
                        ),
                        _buildStatTile(
                          context,
                          title: 'Active Cases',
                          value: '${stats.activeCases}',
                          subtext: '${stats.closedCases} Closed',
                          icon: Icons.work_history,
                          iconBg: const Color(0xFF312E81),
                          iconColor: const Color(0xFF818CF8),
                          onTap: () => context.push(RouteNames.adminCases),
                        ),
                        _buildStatTile(
                          context,
                          title: 'Pending Verifications',
                          value: '${stats.pendingVerifications}',
                          subtext: 'Action Required',
                          icon: Icons.verified_user_outlined,
                          iconBg: const Color(0xFF78350F),
                          iconColor: const Color(0xFFFBBF24),
                          onTap: () => context.push(RouteNames.adminLawyerVerification),
                        ),
                        _buildStatTile(
                          context,
                          title: 'Appointments',
                          value: '${stats.totalAppointments}',
                          subtext: '${stats.openAppointments} Upcoming',
                          icon: Icons.calendar_month,
                          iconBg: const Color(0xFF581C87),
                          iconColor: const Color(0xFFC084FC),
                          onTap: () => context.push(RouteNames.adminAppointments),
                        ),
                        _buildStatTile(
                          context,
                          title: 'Support Tickets',
                          value: '${stats.totalSupportTickets}',
                          subtext: '${stats.openSupportTickets} Open',
                          icon: Icons.confirmation_number_outlined,
                          iconBg: const Color(0xFF701A75),
                          iconColor: const Color(0xFFF472B6),
                          onTap: () => context.push(RouteNames.adminSupportTickets),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cases Overview Distribution Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cases Overview',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Icon(Icons.pie_chart_outline, color: AppColors.primaryGold, size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primaryGold, width: 4),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${stats.totalCases}',
                                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const Text(
                                        'Total Cases',
                                        style: TextStyle(color: AppColors.mutedText, fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildLegendRow('Pending', '${stats.casesOverview['pending'] ?? 0}', const Color(0xFFF59E0B)),
                                    const SizedBox(height: 6),
                                    _buildLegendRow('In Progress', '${stats.casesOverview['inProgress'] ?? 0}', const Color(0xFF38BDF8)),
                                    const SizedBox(height: 6),
                                    _buildLegendRow('Completed', '${stats.casesOverview['completed'] ?? 0}', const Color(0xFF4ADE80)),
                                    const SizedBox(height: 6),
                                    _buildLegendRow('Closed', '${stats.casesOverview['closed'] ?? 0}', Colors.grey),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primaryGold),
                  ),
                ),
                error: (err, stack) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Failed to load live metrics: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.mutedText, size: 12),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtext,
                        style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(String label, String value, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 13)),
          ],
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
