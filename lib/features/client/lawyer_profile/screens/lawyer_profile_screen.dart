import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Lawyer Profile"),
        actions: [
          ref.watch(favoritesProvider).maybeWhen(
            data: (favs) {
              final isFav = favs.any((f) => f.lawyerUserId == userId);
              return IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? AppColors.error : theme.appBarTheme.iconTheme?.color),
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
                      _buildProfileHeader(context, lawyer),
                      const SizedBox(height: 24),

                      // About Me
                      Text("About Me", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                      const SizedBox(height: 8),
                      Text(
                        lawyer.bio.isNotEmpty
                            ? lawyer.bio
                            : "No bio available for this lawyer.",
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color, height: 1.6),
                      ),
                      const SizedBox(height: 24),

                      // Expertise
                      Text("Expertise", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildExpertiseChip(context, lawyer.specialization),
                          if (lawyer.specialization.toLowerCase() == "property disputes") ...[
                            _buildExpertiseChip(context, "Civil Cases"),
                            _buildExpertiseChip(context, "Injunction"),
                            _buildExpertiseChip(context, "Title Verification"),
                            _buildExpertiseChip(context, "RERA Matters"),
                          ] else if (lawyer.specialization.toLowerCase() == "divorce & family") ...[
                            _buildExpertiseChip(context, "Family Law"),
                            _buildExpertiseChip(context, "Child Custody"),
                            _buildExpertiseChip(context, "Alimony"),
                            _buildExpertiseChip(context, "Mediation"),
                          ] else ...[
                            _buildExpertiseChip(context, "Criminal Defense"),
                            _buildExpertiseChip(context, "Bail Matters"),
                            _buildExpertiseChip(context, "Litigation"),
                          ]
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Education
                      if (lawyer.education.isNotEmpty) ...[
                        Text("Education", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                        const SizedBox(height: 8),
                        Text(
                          lawyer.education,
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Bar Registration
                      if (lawyer.barCouncilNumber.isNotEmpty) ...[
                        Text("Bar Council Registration", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                        const SizedBox(height: 8),
                        Text(
                          lawyer.barCouncilNumber,
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Languages
                      if (lawyer.languages.isNotEmpty) ...[
                        Text("Languages spoken", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                        const SizedBox(height: 8),
                        Text(
                          lawyer.languages.join(", "),
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Fees
                      Text("Fees", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Consultation Fee", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                            Text("₹${lawyer.consultationFee}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
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

  Widget _buildProfileHeader(BuildContext context, LawyerModel lawyer) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleLarge?.color),
          ),
          const SizedBox(height: 4),
          Text(
            lawyer.specialization,
            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                lawyer.location.isNotEmpty ? lawyer.location : "Hyderabad, Telangana",
                style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
              ),
            ],
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
                style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.work, color: theme.colorScheme.primary, size: 16),
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

  Widget _buildExpertiseChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(label, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      side: BorderSide(color: theme.colorScheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }

  Widget _buildBottomActions(BuildContext context, WidgetRef ref, LawyerModel lawyer) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: theme.colorScheme.surface,
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
                  child: const Text("Chat Now"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Initiating call with ${lawyer.fullName}...")),
                    );
                  },
                  child: const Text("Call Now"),
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
            child: const Text("Book Appointment"),
          ),
        ],
      ),
    );
  }
}