import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../routes/route_names.dart';

class CaseProgressScreen extends ConsumerWidget {
  final String caseId;

  const CaseProgressScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesState = ref.watch(casesProvider);
    final appointmentsState = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Case Details"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: casesState.when(
        data: (cases) {
          final caseItem = cases.firstWhere((c) => c.id == caseId, orElse: () => throw Exception("Case not found"));

          // Find if there is an appointment scheduled for this case
          final nextAppointment = appointmentsState.maybeWhen(
            data: (appointments) => appointments.firstWhere(
              (a) => a.caseId == caseId && a.status == 'confirmed',
              orElse: () => throw Exception(),
            ),
            orElse: () => null,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header details
                _buildHeaderCard(caseItem),
                const SizedBox(height: 20),

                // Case Progress
                const Text("Case Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                const SizedBox(height: 12),
                _buildProgressTimeline(caseItem),
                const SizedBox(height: 24),

                // Next Consultation Card
                if (caseItem.assignedLawyerId != null) ...[
                  const Text("Next Consultation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                  const SizedBox(height: 12),
                  _buildNextConsultationCard(context, caseItem, nextAppointment),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildHeaderCard(CaseModel caseItem) {
    final formattedDate = DateFormat('dd MMM yyyy').format(caseItem.createdAt);
    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  caseItem.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "In Progress",
                    style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Case ID: ${caseItem.id.substring(Math.max(0, caseItem.id.length - 8)).toUpperCase()}",
              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              "Posted on $formattedDate",
              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTimeline(CaseModel caseItem) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(caseItem.milestones.length, (index) {
          final milestone = caseItem.milestones[index];
          final isLast = index == caseItem.milestones.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: milestone.isCompleted ? AppColors.success : Colors.white,
                        border: Border.all(
                          color: milestone.isCompleted ? AppColors.success : AppColors.grey300,
                          width: 2,
                        ),
                      ),
                      child: milestone.isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: milestone.isCompleted ? AppColors.success : AppColors.grey300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: milestone.isCompleted ? AppColors.navyBlue : AppColors.grey400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          milestone.isCompleted ? "Completed" : "Pending",
                          style: TextStyle(
                            fontSize: 12,
                            color: milestone.isCompleted ? AppColors.success : AppColors.grey400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNextConsultationCard(BuildContext context, CaseModel caseItem, dynamic appointment) {
    final hasAppointment = appointment != null;
    final formattedDate = hasAppointment ? DateFormat('dd MMM yyyy').format(appointment.date) : "20 May 2025";
    final timeSlot = hasAppointment ? appointment.timeSlot : "06:00 PM";
    final mode = hasAppointment ? appointment.mode : "Video Call";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: caseItem.assignedLawyerImage != null && caseItem.assignedLawyerImage!.isNotEmpty
                  ? NetworkImage(caseItem.assignedLawyerImage!)
                  : null,
              child: caseItem.assignedLawyerImage == null || caseItem.assignedLawyerImage!.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caseItem.assignedLawyerName ?? "Assigned Lawyer",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$formattedDate, $timeSlot",
                    style: const TextStyle(color: AppColors.grey500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                mode == "Audio Call" ? Icons.phone : Icons.videocam,
                color: AppColors.navyBlue,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Math {
  static int max(int a, int b) => a > b ? a : b;
}
