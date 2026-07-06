import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../providers/case_provider.dart';
import '../widgets/calendar_widget.dart';
import '../providers/calendar_provider.dart';

// ─────────────────────────────────────────────────────────────
// Colors — extracted from the Figma reference image
// ─────────────────────────────────────────────────────────────
const _navy = Color(0xFF0B1F4D);
const _gold = Color(0xFFD4A537);
const _bg = Color(0xFFF9FAFC);
const _border = Color(0xFFE2E8F0);
const _textDark = Color(0xFF0F172A);

class ScheduleConsultationScreen extends ConsumerStatefulWidget {
  final String lawyerUserId;
  final String? caseId;

  const ScheduleConsultationScreen({
    super.key,
    required this.lawyerUserId,
    this.caseId,
  });

  @override
  ConsumerState<ScheduleConsultationScreen> createState() =>
      _ScheduleConsultationScreenState();
}

class _ScheduleConsultationScreenState
    extends ConsumerState<ScheduleConsultationScreen> {
  String? _selectedTimeSlot;
  String _selectedMode = 'Audio Call';

  final List<String> _timeSlots = [
    '11:00 AM',
    '01:00 PM',
    '03:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
  ];

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Navigator.of(context).pop(),
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
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──── Select Date heading ────
                  const Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ──── Calendar card ────
                  CalendarWidget(
                    disablePastDates: true,
                    lawyerUserId: widget.lawyerUserId,
                  ),
                  const SizedBox(height: 28),

                  // ──── Select Time heading ────
                  const Text(
                    'Select Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ──── Time slot grid ────
                  _buildTimeSlotGrid(),
                  const SizedBox(height: 28),

                  // ──── Consultation Mode heading ────
                  const Text(
                    'Consultation Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ──── Mode selector ────
                  _buildModeSelector(),
                ],
              ),
            ),
          ),

          // ──── Confirm button pinned at bottom ────
          _buildConfirmButton(),
        ],
      ),
    );
  }

  // ───────────────── TIME SLOT GRID ─────────────────
  Widget _buildTimeSlotGrid() {
    // 3 columns, 2 rows — reference shows equal-width rounded pill buttons
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 3;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
        const itemHeight = 44.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _timeSlots.map((slot) {
            final isSelected = _selectedTimeSlot == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedTimeSlot = slot),
              child: Container(
                width: itemWidth,
                height: itemHeight,
                decoration: BoxDecoration(
                  color: isSelected ? _navy : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _navy : _border,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  slot,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : _textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ───────────────── MODE SELECTOR ─────────────────
  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(child: _buildModeCard('Audio Call')),
        const SizedBox(width: 14),
        Expanded(child: _buildModeCard('Video Call')),
      ],
    );
  }

  Widget _buildModeCard(String label) {
    final isSelected = _selectedMode == label;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = label),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _navy : _border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            // Custom radio indicator matching the reference exactly
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _navy : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: isSelected
                  ? Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── CONFIRM BUTTON ─────────────────
  Widget _buildConfirmButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      color: _bg,
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _selectedTimeSlot == null ? null : _confirmBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _navy.withOpacity(0.5),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Confirm Appointment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────── BACKEND ─────────────────
  Future<void> _confirmBooking() async {
    final bookingNotifier = ref.read(appointmentsProvider.notifier);
    final caseNotifier = ref.read(casesProvider.notifier);
    final selectedDate = ref.read(selectedDateProvider);

    final success = await bookingNotifier.bookAppointment(
      lawyerId: widget.lawyerUserId,
      caseId: widget.caseId,
      date: selectedDate,
      timeSlot: _selectedTimeSlot!,
      mode: _selectedMode,
    );

    if (success) {
      if (widget.caseId != null) {
        await caseNotifier.acceptProposal(widget.caseId!, widget.lawyerUserId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Appointment scheduled successfully!')),
        );
        context.go('/my-cases');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to book appointment. Please try again.')),
        );
      }
    }
  }
}
