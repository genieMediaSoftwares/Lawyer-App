import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/appointment_model.dart';
import '../../../../providers/admin_provider.dart';

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  ConsumerState<AdminAppointmentsScreen> createState() => _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends ConsumerState<AdminAppointmentsScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String _getMonthYearString(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return const Color(0xFF4ADE80);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFFCA5A5);
      default:
        return AppColors.primaryGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(adminAppointmentsProvider);

    // Calculate 7 days centered on selected date
    final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final daysOfWeek = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Appointments Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminAppointmentsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(adminAppointmentsProvider),
        color: AppColors.primaryGold,
        backgroundColor: AppColors.cardBackground,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Calendar Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getMonthYearString(_selectedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: AppColors.primaryGold),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: AppColors.primaryGold),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = _selectedDate.add(const Duration(days: 7));
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                          .map((day) => Text(day, style: const TextStyle(color: AppColors.mutedText, fontSize: 13, fontWeight: FontWeight.bold)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: daysOfWeek.map((d) {
                        final isSelected = d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDate = d),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryGold : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SCHEDULED CONSULTATIONS',
                style: TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              appointmentsAsync.when(
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_outlined, color: AppColors.mutedText, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No scheduled consultations found',
                            style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Bookings will automatically appear here once scheduled by clients.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appt = appointments[index];
                      return _buildAppointmentTile(
                        time: appt.timeSlot.isNotEmpty ? appt.timeSlot : 'N/A',
                        clientName: appt.clientName.isNotEmpty ? appt.clientName : 'Client',
                        lawyerName: appt.lawyerName.isNotEmpty ? 'Adv. ${appt.lawyerName}' : 'Assigned Advocate',
                        type: appt.caseTitle ?? appt.mode,
                        status: appt.status,
                        statusColor: _getStatusColor(appt.status),
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                ),
                error: (err, stack) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Error loading consultations: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentTile({
    required String time,
    required String clientName,
    required String lawyerName,
    required String type,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              time,
              style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  lawyerName,
                  style: const TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Topic: $type',
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
