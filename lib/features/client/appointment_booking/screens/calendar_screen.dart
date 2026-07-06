import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/calendar_widget.dart';
import '../providers/calendar_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/appointment_model.dart';
import '../../../../models/lawyer_model.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  final String? lawyerUserId;
  const CalendarScreen({super.key, this.lawyerUserId});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    // Invalidate calendar appointments to load fresh data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(calendarAppointmentsProvider);
    });
  }

  void _showClientBookingDialog(BuildContext context, DateTime initialDate) {
    final lawyers = ref.read(lawyersProvider).value ?? [];
    if (lawyers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No lawyers available to book at the moment.")),
      );
      return;
    }

    String? selectedLawyerId = widget.lawyerUserId ?? lawyers.first.userId;
    DateTime selectedDate = initialDate;
    String selectedTimeSlot = "11:00 AM";
    String selectedMode = "Video Call";

    final List<String> timeSlots = [
      '09:00 AM',
      '11:00 AM',
      '01:00 PM',
      '03:00 PM',
      '05:00 PM',
      '07:00 PM',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Book Consultation",
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lawyer dropdown (if not already locked to a lawyer)
                    if (widget.lawyerUserId == null) ...[
                      const Text("Select Lawyer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.grey500)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedLawyerId,
                        dropdownColor: Colors.white,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: lawyers.map((lawyer) {
                          return DropdownMenuItem<String>(
                            value: lawyer.userId,
                            child: Text(lawyer.fullName, style: const TextStyle(fontSize: 13, color: AppColors.navyBlue)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedLawyerId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Date Picker Display
                    const Text("Consultation Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.grey500)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.grey300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(fontSize: 13, color: AppColors.navyBlue)),
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.navyBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time slot dropdown
                    const Text("Select Time Slot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.grey500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedTimeSlot,
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: timeSlots.map((slot) {
                        return DropdownMenuItem<String>(
                          value: slot,
                          child: Text(slot, style: const TextStyle(fontSize: 13, color: AppColors.navyBlue)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedTimeSlot = val!);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mode dropdown
                    const Text("Consultation Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.grey500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedMode,
                      dropdownColor: Colors.white,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Video Call", child: Text("Video Call", style: TextStyle(fontSize: 13, color: AppColors.navyBlue))),
                        DropdownMenuItem(value: "Audio Call", child: Text("Audio Call", style: TextStyle(fontSize: 13, color: AppColors.navyBlue))),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedMode = val!);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.grey500)),
                ),
                ElevatedButton(
                  onPressed: _isBooking
                      ? null
                      : () async {
                          setDialogState(() => _isBooking = true);
                          final success = await ref.read(appointmentsProvider.notifier).bookAppointment(
                                lawyerId: selectedLawyerId!,
                                date: selectedDate,
                                timeSlot: selectedTimeSlot,
                                mode: selectedMode,
                              );
                          setDialogState(() => _isBooking = false);
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (success) {
                              ref.invalidate(calendarAppointmentsProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Consultation booked successfully!")),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Failed to book appointment. Please try again.")),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, foregroundColor: Colors.white),
                  child: _isBooking
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Book"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final appointmentsState = ref.watch(calendarAppointmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navyBlue, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Calendar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navyBlue,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => _showClientBookingDialog(context, selectedDate),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navyBlue,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar Grid Card
              CalendarWidget(
                disablePastDates: true,
                lawyerUserId: widget.lawyerUserId,
              ),
              const SizedBox(height: 24),

              // Title Section: Appointments
              const Text(
                'Appointments',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.navyBlue,
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic Appointments Card matching reference layout
              appointmentsState.when(
                data: (appointments) {
                  final dailyAppts = appointments.where((appt) {
                    if (widget.lawyerUserId != null && appt.lawyerId != widget.lawyerUserId) {
                      return false;
                    }
                    final apptDate = DateTime(appt.date.year, appt.date.month, appt.date.day);
                    return (apptDate.isAtSameMomentAs(selectedDate) || apptDate.isAfter(selectedDate)) &&
                        appt.status != 'cancelled';
                  }).toList();

                  // Sort appointments by date & time slot
                  dailyAppts.sort((a, b) {
                    final dateCompare = a.date.compareTo(b.date);
                    if (dateCompare != 0) return dateCompare;
                    return a.timeSlot.compareTo(b.timeSlot);
                  });

                  if (dailyAppts.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.grey200),
                      ),
                      child: const Center(
                        child: Text(
                          'No upcoming appointments scheduled.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: AppColors.grey200),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dailyAppts.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 20),
                      itemBuilder: (context, index) {
                        final appt = dailyAppts[index];

                        String dateBadge = "";
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final apptDay = DateTime(appt.date.year, appt.date.month, appt.date.day);

                        if (apptDay.isAtSameMomentAs(today)) {
                          dateBadge = "Today";
                        } else {
                          dateBadge = DateFormat('d MMM').format(appt.date);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time
                              SizedBox(
                                width: 80,
                                child: Text(
                                  appt.timeSlot,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.navyBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Client/Lawyer Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appt.lawyerName.isNotEmpty ? appt.lawyerName : appt.clientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.navyBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      appt.caseTitle ?? (appt.mode.toLowerCase().contains("video") ? "Video Consultation" : "Voice Consultation"),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.grey400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Relative Date badge
                              Text(
                                dateBadge,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
