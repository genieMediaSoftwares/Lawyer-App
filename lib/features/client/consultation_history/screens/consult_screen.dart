import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../models/appointment_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

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

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("My Consultations", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.gold,
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
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 64, color: AppColors.grey300),
              const SizedBox(height: 16),
              const Text("No Consultations Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
              const SizedBox(height: 8),
              const Text("Your booked consultations will appear here.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey400)),
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
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.grey200),
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
                      Text(appointment.lawyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue)),
                      const SizedBox(height: 4),
                      Text("Mode: ${appointment.mode}", style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                      const SizedBox(height: 4),
                      if (appointment.caseTitle != null)
                        Text("Case: ${appointment.caseTitle}", style: const TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.w600, fontSize: 12)),
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
                const Icon(Icons.calendar_today, size: 16, color: AppColors.grey500),
                const SizedBox(width: 6),
                Text(formattedDate, style: const TextStyle(fontSize: 13, color: AppColors.navyBlue)),
                const SizedBox(width: 20),
                const Icon(Icons.access_time, size: 16, color: AppColors.grey500),
                const SizedBox(width: 6),
                Text(appointment.timeSlot, style: const TextStyle(fontSize: 13, color: AppColors.navyBlue)),
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
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return AppColors.navyBlue;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.grey500;
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
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))),
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
