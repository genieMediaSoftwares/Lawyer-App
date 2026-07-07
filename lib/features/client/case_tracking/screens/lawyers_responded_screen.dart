import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Lawyers Responded"),
      ),
      body: casesState.when(
        data: (cases) {
          final caseItem = cases.firstWhere((c) => c.id == caseId, orElse: () => throw Exception("Case not found"));
          final proposals = caseItem.proposals;

          return Column(
            children: [
              // Case Summary Header Card
              _buildCaseHeaderCard(context, caseItem),
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

  Widget _buildCaseHeaderCard(BuildContext context, CaseModel caseItem) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                caseItem.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Case ID: ${caseItem.id.substring(Math.max(0, caseItem.id.length - 8)).toUpperCase()}",
            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            "${caseItem.proposals.length} Proposals Received",
            style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLawyerProposalCard(BuildContext context, CaseProposalModel proposal, String caseId) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.titleMedium?.color),
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
                        style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹${proposal.feeProposal} Consultation Fee",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                  ),
                  if (proposal.message.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        proposal.message,
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color, height: 1.4),
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
                        child: const Text("View Profile"),
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
