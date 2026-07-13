import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/calendar_widget.dart';
import '../providers/calendar_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../core/theme/app_colors.dart';
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
    String selectedMode = "Chat";

    final List<String> timeSlots = [
      '09:00 AM',
      '11:00 AM',
      '01:00 PM',
      '03:00 PM',
      '05:00 PM',
      '07:00 PM',
      '09:00 PM',
    ];

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Book Consultation",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lawyer dropdown (if not already locked to a lawyer)
                    if (widget.lawyerUserId == null) ...[
                      Text("Select Lawyer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedLawyerId,
                        dropdownColor: theme.colorScheme.surface,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: lawyers.map((lawyer) {
                          return DropdownMenuItem<String>(
                            value: lawyer.userId,
                            child: Text(lawyer.fullName, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedLawyerId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Date Picker Display
                    Text("Consultation Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.textTheme.bodySmall?.color)),
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
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(selectedDate), style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                            Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time slot dropdown
                    Text("Select Time Slot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedTimeSlot,
                      dropdownColor: theme.colorScheme.surface,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: timeSlots.map((slot) {
                        return DropdownMenuItem<String>(
                          value: slot,
                          child: Text(slot, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedTimeSlot = val!);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mode dropdown
                    Text("Consultation Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedMode,
                      dropdownColor: theme.colorScheme.surface,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: "Chat", child: Text("Chat", style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color))),
                        DropdownMenuItem(value: "In-Person", child: Text("In-Person", style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color))),
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
                  child: Text("Cancel", style: TextStyle(color: theme.textTheme.bodySmall?.color)),
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
                  child: _isBooking
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Calendar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.appBarTheme.titleTextStyle?.color,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
                child: const Icon(Icons.add, color: Colors.black, size: 20),
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
              Text(
                'Appointments',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: textTheme.titleLarge?.color,
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
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Center(
                        child: Text(
                          'No upcoming appointments scheduled.',
                          style: TextStyle(color: textTheme.bodySmall?.color, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: colorScheme.outline),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dailyAppts.length,
                      separatorBuilder: (context, index) => Divider(color: theme.dividerTheme.color, height: 20),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: colorScheme.primary,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textTheme.titleMedium?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      appt.caseTitle ?? (appt.mode.toLowerCase().contains("video") ? "Video Consultation" : "Voice Consultation"),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Relative Date badge
                              Text(
                                dateBadge,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textTheme.bodySmall?.color,
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
