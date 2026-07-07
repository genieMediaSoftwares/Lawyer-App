import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class CaseProgressScreen extends ConsumerWidget {
  final String caseId;

  const CaseProgressScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesState = ref.watch(casesProvider);
    final appointmentsState = ref.watch(appointmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Case Details"),
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
                _buildHeaderCard(context, caseItem),
                const SizedBox(height: 20),

                // Case Progress
                Text("Case Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color)),
                const SizedBox(height: 12),
                _buildProgressTimeline(context, caseItem),
                const SizedBox(height: 24),

                // Next Consultation Card
                if (caseItem.assignedLawyerId != null) ...[
                  Text("Next Consultation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color)),
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

  Widget _buildHeaderCard(BuildContext context, CaseModel caseItem) {
    final formattedDate = DateFormat('dd MMM yyyy').format(caseItem.createdAt);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  caseItem.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleMedium?.color),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "In Progress",
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Case ID: ${caseItem.id.substring(Math.max(0, caseItem.id.length - 8)).toUpperCase()}",
              style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              "Posted on $formattedDate",
              style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTimeline(BuildContext context, CaseModel caseItem) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
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
                        color: milestone.isCompleted ? AppColors.success : theme.colorScheme.surface,
                        border: Border.all(
                          color: milestone.isCompleted ? AppColors.success : theme.colorScheme.outline,
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
                          color: milestone.isCompleted ? AppColors.success : theme.colorScheme.outline,
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
                            color: milestone.isCompleted ? theme.colorScheme.onSurface : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          milestone.isCompleted ? "Completed" : "Pending",
                          style: TextStyle(
                            fontSize: 12,
                            color: milestone.isCompleted ? AppColors.success : theme.textTheme.bodySmall?.color,
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
    final theme = Theme.of(context);
    final hasAppointment = appointment != null;
    final formattedDate = hasAppointment ? DateFormat('dd MMM yyyy').format(appointment.date) : "20 May 2025";
    final timeSlot = hasAppointment ? appointment.timeSlot : "06:00 PM";
    final mode = hasAppointment ? appointment.mode : "Video Call";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.titleMedium?.color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$formattedDate, $timeSlot",
                    style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                mode == "Audio Call" ? Icons.phone : Icons.videocam,
                color: theme.colorScheme.primary,
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
