import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../providers/case_provider.dart';

class ScheduleConsultationScreen extends ConsumerStatefulWidget {
  final String lawyerUserId;
  final String? caseId;

  const ScheduleConsultationScreen({
    super.key,
    required this.lawyerUserId,
    this.caseId,
  });

  @override
  ConsumerState<ScheduleConsultationScreen> createState() => _ScheduleConsultationScreenState();
}

class _ScheduleConsultationScreenState extends ConsumerState<ScheduleConsultationScreen> {
  DateTime _selectedDate = DateTime(2025, 5, 20); // Default to May 2025 as in Figma
  String? _selectedTimeSlot;
  String _selectedMode = "Video Call";

  final List<String> _timeSlots = [
    "11:00 AM",
    "01:00 PM",
    "03:00 PM",
    "05:00 PM",
    "06:00 PM",
    "07:00 PM"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Schedule Consultation"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selector Section
                    const Text("Select Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                    const SizedBox(height: 12),
                    _buildCalendarHeader(),
                    const SizedBox(height: 8),
                    _buildCalendarGrid(),
                    const SizedBox(height: 24),

                    // Time Slot Section
                    const Text("Select Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                    const SizedBox(height: 12),
                    _buildTimeSlotGrid(),
                    const SizedBox(height: 24),

                    // Consultation Mode Section
                    const Text("Consultation Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                    const SizedBox(height: 12),
                    _buildModeSelector(),
                  ],
                ),
              ),
            ),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        DateFormat('MMMM yyyy').format(_selectedDate),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // Generate dates for May 2025
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstDayOfWeek = DateTime(_selectedDate.year, _selectedDate.month, 1).weekday; // 1 = Monday, 7 = Sunday

    final weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays
                .map((d) => Text(d, style: const TextStyle(color: AppColors.grey400, fontWeight: FontWeight.bold, fontSize: 12)))
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + (firstDayOfWeek % 7),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final offsetIndex = firstDayOfWeek % 7;
              if (index < offsetIndex) {
                return const SizedBox.shrink();
              }

              final dayNum = index - offsetIndex + 1;
              final isSelected = _selectedDate.day == dayNum;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.navyBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$dayNum",
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.navyBlue,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _timeSlots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final slot = _timeSlots[index];
        final isSelected = _selectedTimeSlot == slot;

        return InkWell(
          onTap: () => setState(() => _selectedTimeSlot = slot),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.navyBlue : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppColors.navyBlue : AppColors.grey200),
            ),
            alignment: Alignment.center,
            child: Text(
              slot,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.navyBlue,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(child: _buildModeCard("Audio Call", Icons.phone)),
        const SizedBox(width: 16),
        Expanded(child: _buildModeCard("Video Call", Icons.videocam)),
      ],
    );
  }

  Widget _buildModeCard(String modeName, IconData icon) {
    final isSelected = _selectedMode == modeName;
    return InkWell(
      onTap: () => setState(() => _selectedMode = modeName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.navyBlue : AppColors.grey200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.navyBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              modeName,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: _selectedTimeSlot == null ? null : _confirmBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Confirm Appointment", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final bookingNotifier = ref.read(appointmentsProvider.notifier);
    final caseNotifier = ref.read(casesProvider.notifier);

    // Book the appointment
    final success = await bookingNotifier.bookAppointment(
      lawyerId: widget.lawyerUserId,
      caseId: widget.caseId,
      date: _selectedDate,
      timeSlot: _selectedTimeSlot!,
      mode: _selectedMode,
    );

    if (success) {
      // If booked from the case proposals screen, accept proposal and assign the lawyer
      if (widget.caseId != null) {
        await caseNotifier.acceptProposal(widget.caseId!, widget.lawyerUserId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment scheduled successfully!")),
        );
        // Go back to the dashboard/shell
        context.go('/my-cases');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to book appointment. Please try again.")),
        );
      }
    }
  }
}
