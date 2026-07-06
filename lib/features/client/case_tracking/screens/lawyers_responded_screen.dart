import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class LawyersRespondedScreen extends ConsumerWidget {
  final String caseId;

  const LawyersRespondedScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesState = ref.watch(casesProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Lawyers Responded"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: casesState.when(
        data: (cases) {
          final caseItem = cases.firstWhere((c) => c.id == caseId, orElse: () => throw Exception("Case not found"));
          final proposals = caseItem.proposals;

          return Column(
            children: [
              // Case Summary Header Card
              _buildCaseHeaderCard(caseItem),
              Expanded(
                child: proposals.isEmpty
                    ? const Center(child: Text("No proposals received yet."))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: proposals.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final proposal = proposals[index];
                          return _buildLawyerProposalCard(context, proposal, caseItem.id);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildCaseHeaderCard(CaseModel caseItem) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: AppColors.navyBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                caseItem.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Case ID: ${caseItem.id.substring(Math.max(0, caseItem.id.length - 8)).toUpperCase()}",
            style: const TextStyle(color: AppColors.grey400, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            "${caseItem.proposals.length} Proposals Received",
            style: const TextStyle(color: AppColors.grey500, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLawyerProposalCard(BuildContext context, CaseProposalModel proposal, String caseId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: proposal.profileImage.isNotEmpty ? NetworkImage(proposal.profileImage) : null,
              child: proposal.profileImage.isEmpty ? const Icon(Icons.person, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposal.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        "4.8", // Static for rating in proposal
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "10+ Years Exp.",
                        style: TextStyle(color: AppColors.grey500, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${proposal.feeProposal} Consultation Fee",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue),
                  ),
                  if (proposal.message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        proposal.message,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          // Navigate to lawyer profile page passing lawyer's user ID
                          context.push('/lawyer-profile/${proposal.lawyerId}?caseId=$caseId');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.navyBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text("View Profile", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  )
                ],
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
