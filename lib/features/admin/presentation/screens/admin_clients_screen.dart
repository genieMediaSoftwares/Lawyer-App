import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/admin_provider.dart';

class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(adminClientsProvider);
    final filter = ref.watch(adminClientFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Clients Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminClientsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.primaryText),
                  onChanged: (val) {
                    ref.read(adminClientFilterProvider.notifier).state = filter.copyWith(search: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search clients by name, email, or phone...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGold),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.mutedText),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(adminClientFilterProvider.notifier).state = filter.copyWith(search: '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip('All', 'all', filter.status),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active', 'active', filter.status),
                    const SizedBox(width: 8),
                    _buildFilterChip('Inactive', 'inactive', filter.status),
                  ],
                ),
              ],
            ),
          ),

          // Clients List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(adminClientsProvider),
              color: AppColors.primaryGold,
              backgroundColor: AppColors.cardBackground,
              child: clientsAsync.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, color: AppColors.mutedText, size: 48),
                          SizedBox(height: 12),
                          Text('No clients found', style: TextStyle(color: AppColors.secondaryText)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.secondaryBackground,
                              backgroundImage: client.profileImage.isNotEmpty ? NetworkImage(client.profileImage) : null,
                              child: client.profileImage.isEmpty
                                  ? Text(
                                      client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : 'C',
                                      style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          client.fullName,
                                          style: const TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: client.isActive ? AppColors.statusSuccessBg : AppColors.statusErrorBg,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          client.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: client.isActive ? AppColors.statusSuccessFg : AppColors.statusErrorFg,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    client.email,
                                    style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                                  ),
                                  if (client.mobile.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      client.mobile,
                                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildBadge('${client.casesCount} Cases', Icons.folder_open),
                                      const SizedBox(width: 8),
                                      _buildBadge('${client.documentsCount} Docs', Icons.description_outlined),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                error: (err, stack) => Center(
                  child: Text('Error loading clients: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentStatus) {
    final isSelected = currentStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          final filter = ref.read(adminClientFilterProvider);
          ref.read(adminClientFilterProvider.notifier).state = filter.copyWith(status: value);
        }
      },
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.cardBackground,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onGold : AppColors.primaryGold,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryGold, size: 12),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
        ],
      ),
    );
  }
}
