import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/document_model.dart';
import '../../../../providers/admin_provider.dart';

class AdminDocumentsScreen extends ConsumerStatefulWidget {
  const AdminDocumentsScreen({super.key});

  @override
  ConsumerState<AdminDocumentsScreen> createState() => _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends ConsumerState<AdminDocumentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDocument(DocumentModel doc) async {
    if (doc.url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This document has no file attached.')),
      );
      return;
    }

    final uri = Uri.parse(Environment.getAttachmentUrl(doc.url));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${doc.fileName}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(adminDocumentsProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Documents Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminDocumentsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.primaryText),
                  onChanged: (val) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search uploaded legal documents...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primaryGold),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'Property', 'Civil', 'Criminal', 'Corporate'].map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat == 'all' ? 'All' : cat),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedCategory = cat);
                          },
                          selectedColor: AppColors.primaryGold,
                          backgroundColor: AppColors.cardBackground,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.onGold : AppColors.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(adminDocumentsProvider),
              color: AppColors.primaryGold,
              backgroundColor: AppColors.cardBackground,
              child: docsAsync.when(
                data: (docs) {
                  final filteredDocs = docs.where((doc) {
                    final matchesSearch = _searchController.text.isEmpty ||
                        doc.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                        doc.fileName.toLowerCase().contains(_searchController.text.toLowerCase());
                    final matchesCat = _selectedCategory == 'all' || doc.docCategory.toLowerCase() == _selectedCategory.toLowerCase();
                    return matchesSearch && matchesCat;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text('No documents found in vault', style: TextStyle(color: AppColors.secondaryText)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.statusErrorBg.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.statusErrorFg.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.picture_as_pdf, color: AppColors.statusErrorFg, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.title, style: const TextStyle(color: AppColors.primaryText, fontSize: 15, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text('${doc.fileSize} • Uploaded by ${doc.docUploadedBy}', style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('Category: ${doc.docCategory}', style: const TextStyle(color: AppColors.primaryGold, fontSize: 11)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download, color: AppColors.primaryGold),
                              tooltip: 'Open document',
                              // Previously this only showed a "Downloading…"
                              // message and did nothing. It now opens the real
                              // file; getAttachmentUrl attaches the auth token
                              // the protected /uploads route requires.
                              onPressed: () => _openDocument(doc),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                error: (err, stack) => Center(child: Text('Error loading documents: $err', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
