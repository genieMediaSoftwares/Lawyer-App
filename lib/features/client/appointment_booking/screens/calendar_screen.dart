import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/calendar_widget.dart';
import '../providers/calendar_provider.dart';

const _navy = Color(0xFF0B1F4D);
const _bg = Color(0xFFF9FAFC);

class CalendarScreen extends ConsumerWidget {
  final String? lawyerUserId;

  const CalendarScreen({
    super.key,
    this.lawyerUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final appointmentsState = ref.watch(calendarAppointmentsProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navy, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Schedule Consultation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Date',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              CalendarWidget(
                disablePastDates: true,
                lawyerUserId: lawyerUserId,
              ),
              const SizedBox(height: 24),
              Text(
                'Appointments on ${DateFormat('dd MMMM yyyy').format(selectedDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              appointmentsState.when(
                data: (appointments) {
                  final dailyAppts = appointments.where((appt) {
                    if (lawyerUserId != null && appt.lawyerId != lawyerUserId) {
                      return false;
                    }
                    return appt.date.day == selectedDate.day &&
                        appt.date.month == selectedDate.month &&
                        appt.date.year == selectedDate.year &&
                        appt.status != 'cancelled';
                  }).toList();

                  if (dailyAppts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No consultations scheduled for this day.',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dailyAppts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final appt = dailyAppts[index];
                      final isVideo =
                          appt.mode.toLowerCase().contains('video');
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: _navy.withOpacity(0.08),
                            child: Icon(
                              isVideo ? Icons.videocam : Icons.phone,
                              color: _navy,
                            ),
                          ),
                          title: Text(
                            appt.clientName.isNotEmpty
                                ? appt.clientName
                                : 'Client Consultation',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _navy,
                            ),
                          ),
                          subtitle: Text('${appt.timeSlot} • ${appt.mode}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              appt.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
