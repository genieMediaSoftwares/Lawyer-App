import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

import '../../../../providers/favorite_provider.dart';

class LawyerProfileScreen extends ConsumerWidget {
  final String userId;
  final String? caseId;

  const LawyerProfileScreen({
    super.key,
    required this.userId,
    this.caseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Lawyer Profile"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ref.watch(favoritesProvider).maybeWhen(
            data: (favs) {
              final isFav = favs.any((f) => f.lawyerUserId == userId);
              return IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white),
                onPressed: () async {
                  await ref.read(favoritesProvider.notifier).toggleFavorite(userId);
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: lawyerState.when(
        data: (lawyer) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Card Header
                      _buildProfileHeader(lawyer),
                      const SizedBox(height: 24),

                      // About Me
                      Text("About Me", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                      const SizedBox(height: 8),
                      Text(
                        lawyer.bio.isNotEmpty
                            ? lawyer.bio
                            : "No bio available for this lawyer.",
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight, height: 1.6),
                      ),
                      const SizedBox(height: 24),

                      // Expertise
                      Text("Expertise", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildExpertiseChip(lawyer.specialization),
                          if (lawyer.specialization.toLowerCase() == "property disputes") ...[
                            _buildExpertiseChip("Civil Cases"),
                            _buildExpertiseChip("Injunction"),
                            _buildExpertiseChip("Title Verification"),
                            _buildExpertiseChip("RERA Matters"),
                          ] else if (lawyer.specialization.toLowerCase() == "divorce & family") ...[
                            _buildExpertiseChip("Family Law"),
                            _buildExpertiseChip("Child Custody"),
                            _buildExpertiseChip("Alimony"),
                            _buildExpertiseChip("Mediation"),
                          ] else ...[
                            _buildExpertiseChip("Criminal Defense"),
                            _buildExpertiseChip("Bail Matters"),
                            _buildExpertiseChip("Litigation"),
                          ]
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Education
                      if (lawyer.education.isNotEmpty) ...[
                        Text("Education", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                        const SizedBox(height: 8),
                        Text(
                          lawyer.education,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Bar Registration
                      if (lawyer.barCouncilNumber.isNotEmpty) ...[
                        Text("Bar Council Registration", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                        const SizedBox(height: 8),
                        Text(
                          lawyer.barCouncilNumber,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Languages
                      if (lawyer.languages.isNotEmpty) ...[
                        Text("Languages spoken", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                        const SizedBox(height: 8),
                        Text(
                          lawyer.languages.join(", "),
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Fees
                      Text("Fees", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Consultation Fee", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight)),
                            Text("₹${lawyer.consultationFee}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Action Buttons
              _buildBottomActions(context, ref, lawyer),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildProfileHeader(LawyerModel lawyer) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundImage: lawyer.profileImage.isNotEmpty ? NetworkImage(lawyer.profileImage) : null,
            child: lawyer.profileImage.isEmpty ? const Icon(Icons.person, size: 45) : null,
          ),
          const SizedBox(height: 16),
          Text(
            lawyer.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue),
          ),
          const SizedBox(height: 4),
          Text(
            lawyer.specialization,
            style: const TextStyle(color: AppColors.grey500, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                "${lawyer.rating}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                " (${lawyer.totalReviews} Reviews)",
                style: const TextStyle(color: AppColors.grey400, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.work, color: AppColors.navyBlue, size: 16),
              const SizedBox(width: 4),
              Text(
                "${lawyer.experience}+ Years Exp.",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpertiseChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(color: AppColors.navyBlue, fontSize: 12)),
      backgroundColor: AppColors.navyBlue.withOpacity(0.05),
      elevation: 0,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  Widget _buildBottomActions(BuildContext context, WidgetRef ref, LawyerModel lawyer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    // Initialize or retrieve chat session and navigate to ChatScreen
                    final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(lawyer.userId);
                    if (chat != null && context.mounted) {
                      context.push('/chat/${chat.id}/${lawyer.fullName}');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.navyBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Chat Now", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Initiating call with ${lawyer.fullName}..."), backgroundColor: AppColors.navyBlue),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.navyBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Call Now", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              // Navigate to Schedule Consultation passing lawyer user ID
              context.push('/schedule-consultation/${lawyer.userId}${caseId != null ? "?caseId=$caseId" : ""}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navyBlue,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Book Appointment", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}