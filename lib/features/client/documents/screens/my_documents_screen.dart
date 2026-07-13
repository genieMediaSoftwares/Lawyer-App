import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/document_provider.dart';

class MyDocumentsScreen extends ConsumerStatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  ConsumerState<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends ConsumerState<MyDocumentsScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadFile() async {
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
        if (newDoc != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document uploaded successfully!")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload failed. Unsupported type or size limit.")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload error occurred.")));
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("My Documents", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        backgroundColor: theme.colorScheme.primary,
        icon: _isUploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.cloud_upload, color: Colors.black),
        label: Text(_isUploading ? "Uploading..." : "Upload Document", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                    Text("No Documents Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleMedium?.color)),
                    const SizedBox(height: 8),
                    Text("Upload case files, legal letters, or identity credentials for quick access.", textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
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
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(_getFileIcon(doc.mimeType), color: theme.colorScheme.primary),
                  ),
                  title: Text(doc.originalName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.titleMedium?.color)),
                  subtitle: Text("$sizeInKb KB | Uploaded: ${_formatDate(doc.uploadedAt)}", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
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
        error: (err, stack) => Center(child: Text("Error: $err")),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Document"),
        content: const Text("Are you sure you want to permanently delete this document?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(documentsProvider.notifier).deleteDocument(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document deleted successfully.")));
      }
    }
  }
}
