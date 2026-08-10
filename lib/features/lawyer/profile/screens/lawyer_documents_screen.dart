import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/document_provider.dart';

class LawyerDocumentsScreen extends ConsumerStatefulWidget {
  const LawyerDocumentsScreen({super.key});

  @override
  ConsumerState<LawyerDocumentsScreen> createState() => _LawyerDocumentsScreenState();
}

class _LawyerDocumentsScreenState extends ConsumerState<LawyerDocumentsScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadFile() async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result != null && (result.files.single.path != null || result.files.single.bytes != null)) {
      setState(() => _isUploading = true);
      try {
        final file = result.files.single;
        
        final newDoc = await ref.read(documentsProvider.notifier).uploadDocument(
              kIsWeb ? null : file.path,
              file.name,
              bytes: file.bytes,
            );
        if (!mounted) return;
        if (newDoc != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.doc_uploaded_success)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.doc_upload_failed)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.doc_upload_error)));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentsState = ref.watch(documentsProvider);
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.my_documents,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        backgroundColor: theme.colorScheme.primary,
        icon: _isUploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.cloud_upload, color: AppColors.onGold),
        label: Text(
          _isUploading ? loc.uploading : loc.upload_document,
          style: const TextStyle(color: AppColors.onGold, fontWeight: FontWeight.bold),
        ),
      ),
      body: documentsState.when(
        data: (documents) {
          if (documents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open_outlined, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      loc.no_documents_found,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleMedium?.color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.upload_documents_tip,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              final sizeInKb = (doc.fileSize / 1024).toStringAsFixed(1);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(_getFileIcon(doc.mimeType), color: theme.colorScheme.primary),
                  ),
                  title: Text(
                    doc.originalName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.titleMedium?.color),
                  ),
                  subtitle: Text(
                    "$sizeInKb KB | Uploaded: ${_formatDate(doc.uploadedAt)}",
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () => _deleteDocument(doc.id),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error loading documents: $err")),
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.contains("pdf")) {
      return Icons.picture_as_pdf;
    } else if (mimeType.contains("image")) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  Future<void> _deleteDocument(String id) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.delete_document),
        content: Text(loc.confirm_delete_document),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.delete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(documentsProvider.notifier).deleteDocument(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.doc_deleted_success)));
      }
    }
  }
}
