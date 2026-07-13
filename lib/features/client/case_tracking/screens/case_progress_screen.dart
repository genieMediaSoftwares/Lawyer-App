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
import '../../../../providers/chat_provider.dart';

class CaseProgressScreen extends ConsumerWidget {
  final String caseId;

  const CaseProgressScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseDetailsState = ref.watch(caseDetailsProvider(caseId));
    final appointmentsState = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Case Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: caseDetailsState.when(
        data: (caseItem) {
          if (caseItem == null) {
            return const Center(
              child: Text(
                "No case details found.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            );
          }

          // Safely search for confirmed appointments
          final nextAppointment = appointmentsState.maybeWhen(
            data: (appointments) {
              for (var a in appointments) {
                if (a.caseId == caseId && a.status == 'confirmed') {
                  return a;
                }
              }
              return null;
            },
            orElse: () => null,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(caseDetailsProvider(caseId));
            },
            color: const Color(0xFFE6B325),
            backgroundColor: const Color(0xFF181818),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary Case Info Header
                  _buildHeaderCard(context, caseItem),
                  const SizedBox(height: 20),

                  // Case Timeline Stepper progress tracker
                  const Text(
                    "Case Progress Tracker",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  _buildProgressTimeline(context, caseItem),
                  const SizedBox(height: 20),

                  // Assigned / Selected Lawyer Card
                  _buildCounselCard(context, caseItem, ref),
                  const SizedBox(height: 20),

                  // Next Consultation Card
                  if (caseItem.assignedLawyerId != null) ...[
                    const Text(
                      "Next Consultation",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    _buildNextConsultationCard(context, caseItem, nextAppointment),
                    const SizedBox(height: 20),
                  ],

                  // Documents Card
                  if (caseItem.documents.isNotEmpty) ...[
                    const Text(
                      "Supporting Documents",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    _buildDocumentsCard(context, caseItem),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => _buildShimmerLoading(),
        error: (err, stack) => _buildErrorWidget(ref, err.toString()),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, CaseModel caseItem) {
    final formattedDate = DateFormat('dd MMM yyyy').format(caseItem.createdAt);
    final statusColor = _getStatusColor(caseItem.status);
    final caseSuffix = caseItem.id.length > 6 
        ? caseItem.id.substring(caseItem.id.length - 6).toUpperCase() 
        : caseItem.id.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF282828),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  caseItem.category.toUpperCase(),
                  style: const TextStyle(color: Color(0xFFE6B325), fontWeight: FontWeight.bold, fontSize: 9),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  caseItem.status,
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            caseItem.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "Case ID: #$caseSuffix",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            "Posted on $formattedDate",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF282828), height: 1),
          const SizedBox(height: 12),
          const Text(
            "Description",
            style: TextStyle(color: Color(0xFFE6B325), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            caseItem.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(BuildContext context, CaseModel caseItem) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      padding: const EdgeInsets.all(18),
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
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: milestone.isCompleted ? const Color(0xFFE6B325) : const Color(0xFF181818),
                        border: Border.all(
                          color: milestone.isCompleted ? const Color(0xFFE6B325) : const Color(0xFF282828),
                          width: 2,
                        ),
                      ),
                      child: milestone.isCompleted
                          ? const Icon(Icons.check, color: Colors.black, size: 12)
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: milestone.isCompleted ? const Color(0xFFE6B325) : const Color(0xFF282828),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: milestone.isCompleted ? Colors.white : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          milestone.isCompleted ? "Completed" : "Pending",
                          style: TextStyle(
                            fontSize: 11,
                            color: milestone.isCompleted ? const Color(0xFFE6B325) : Colors.grey,
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

  Widget _buildCounselCard(BuildContext context, CaseModel caseItem, WidgetRef ref) {
    final hasLawyer = caseItem.selectedLawyerId != null || caseItem.assignedLawyerId != null;
    if (!hasLawyer) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF282828)),
        ),
        child: Row(
          children: const [
            Icon(Icons.hourglass_empty, color: Color(0xFFE6B325)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Awaiting counsel assignment...",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final lawyerName = caseItem.selectedLawyerName ?? caseItem.assignedLawyerName ?? "Advocate";
    final lawyerImage = caseItem.selectedLawyerImage ?? caseItem.assignedLawyerImage ?? "";
    final lawyerSpec = caseItem.selectedLawyerSpecialization ?? caseItem.assignedLawyerSpecialization ?? "Legal Expert";
    final isVerified = caseItem.selectedLawyerVerified ?? caseItem.assignedLawyerVerified ?? true;
    final rating = caseItem.selectedLawyerRating ?? caseItem.assignedLawyerRating ?? 4.8;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2B2B2C),
            backgroundImage: lawyerImage.isNotEmpty
                ? NetworkImage(lawyerImage)
                : null,
            child: lawyerImage.isEmpty
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        lawyerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFFE6B325), size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  lawyerSpec,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFE6B325), size: 12),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action nodes
          IconButton(
            onPressed: () async {
              final otherUserId = caseItem.selectedLawyerId ?? caseItem.assignedLawyerId;
              if (otherUserId != null) {
                final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(otherUserId);
                if (chat != null) {
                  context.push('/chat/${chat.id}/$lawyerName');
                }
              }
            },
            icon: const Icon(Icons.chat_bubble_outline),
            color: const Color(0xFFE6B325),
          ),
        ],
      ),
    );
  }

  Widget _buildNextConsultationCard(BuildContext context, CaseModel caseItem, dynamic appointment) {
    final hasAppointment = appointment != null;
    final formattedDate = hasAppointment ? DateFormat('dd MMM yyyy').format(appointment.date) : "TBD";
    final timeSlot = hasAppointment ? appointment.timeSlot : "Consultation Pending";
    final mode = hasAppointment ? appointment.mode : "Chat";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6B325).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today, color: Color(0xFFE6B325), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeSlot,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              mode,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard(BuildContext context, CaseModel caseItem) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Column(
        children: List.generate(caseItem.documents.length, (index) {
          final doc = caseItem.documents[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description, color: Color(0xFFE6B325)),
            title: Text(doc.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(doc.size ?? "Unknown Size", style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.download, color: Colors.grey),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Downloading ${doc.name}... (Simulated)")),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (c, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF282828)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerPulse(width: 80, height: 18, borderRadius: 6),
              SizedBox(height: 12),
              ShimmerPulse(width: 150, height: 20),
              SizedBox(height: 8),
              ShimmerPulse(width: double.infinity, height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              "Error loading details: $error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE6B325),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                ref.invalidate(caseDetailsProvider(caseId));
              },
              child: const Text("Retry", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Awaiting Lawyer Acceptance':
        return const Color(0xFFE6B325);
      case 'Submitted':
        return Colors.blue;
      case 'In Progress':
        return Colors.green;
      case 'Closed':
        return Colors.blue;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class ShimmerPulse extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPulse({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<ShimmerPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B2C),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
