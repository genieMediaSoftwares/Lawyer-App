import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../models/appointment_model.dart';

class ConsultScreen extends ConsumerStatefulWidget {
  const ConsultScreen({super.key});

  @override
  ConsumerState<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends ConsumerState<ConsultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsState = ref.watch(appointmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("My Consultations", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Completed"),
            Tab(text: "Cancelled"),
          ],
        ),
      ),
      body: appointmentsState.when(
        data: (appointments) {
          final upcoming = appointments.where((a) => a.status == 'confirmed' || a.status == 'pending').toList();
          final completed = appointments.where((a) => a.status == 'completed').toList();
          final cancelled = appointments.where((a) => a.status == 'cancelled').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentsList(upcoming, isUpcoming: true),
              _buildAppointmentsList(completed),
              _buildAppointmentsList(cancelled),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildAppointmentsList(List<AppointmentModel> items, {bool isUpcoming = false}) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text("No Consultations Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color)),
              const SizedBox(height: 8),
              Text("Your booked consultations will appear here.", textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final appointment = items[index];
        return _buildAppointmentCard(appointment, isUpcoming);
      },
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment, bool isUpcoming) {
    final formattedDate = DateFormat('dd MMM yyyy').format(appointment.date);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: appointment.lawyerImage.isNotEmpty ? NetworkImage(appointment.lawyerImage) : null,
                  child: appointment.lawyerImage.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appointment.lawyerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.titleMedium?.color)),
                      const SizedBox(height: 4),
                      Text("Mode: ${appointment.mode}", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12)),
                      const SizedBox(height: 4),
                      if (appointment.caseTitle != null)
                        Text("Case: ${appointment.caseTitle}", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(color: _getStatusColor(appointment.status), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(formattedDate, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                const SizedBox(width: 20),
                Icon(Icons.access_time, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(appointment.timeSlot, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
            if (isUpcoming) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _cancelAppointment(appointment.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to chat
                      context.push('/chat/${appointment.id}/${appointment.lawyerName}');
                    },
                    child: const Text("Open Chat", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final theme = Theme.of(context);
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return theme.colorScheme.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return theme.disabledColor;
    }
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Consultation"),
        content: const Text("Are you sure you want to cancel this booked appointment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(appointmentsProvider.notifier).cancelAppointment(appointmentId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Consultation cancelled successfully.")));
      }
    }
  }
}
