import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/document_provider.dart';
import '../client/documents/screens/document_viewer_screen.dart';

/// The document operations, in one place, so the client and lawyer screens
/// behave identically.
///
/// Both screens read the same `documentsProvider` and the same API. What used
/// to differ was everything around it — the lawyer screen handed a URL to the
/// browser while the client screen opened the in-app viewer, and only the
/// client screen had rename or replace at all. Two implementations of the same
/// feature drift, and this one had already drifted into one working and one
/// not.
///
/// Permissions are NOT decided here. The backend allows a lawyer to read a
/// client's document but not to rename, replace or delete it, and answers 404
/// or 403 when they try. This surfaces that answer rather than second-guessing
/// it — see [canModify] for what the UI hides ahead of time.
class DocumentActions {
  const DocumentActions({
    required this.ref,
    required this.context,
    required this.onBusyChanged,
  });

  final WidgetRef ref;
  final BuildContext context;

  /// Called with true when an operation starts and false when it ends, so the
  /// caller can disable the card's buttons and show a spinner.
  final void Function(bool busy) onBusyChanged;

  /// Offered in the system file picker.
  ///
  /// Read from configuration rather than written here, so this list and the
  /// server's allowlist are changed in one place. See
  /// [AppConfig.documentPickerExtensions] for what the hardcoded list got
  /// wrong.
  static List<String> get pickerExtensions =>
      AppConfig.documentPickerExtensions;

  /// Whether [userId] may rename, replace or delete [document].
  ///
  /// Mirrors the backend's owner-only rule for writes. Used to hide actions
  /// that would be refused, so a lawyer viewing a client's evidence is not
  /// offered a Rename button that always fails.
  static bool canModify(DocumentRecord document, String? userId) {
    if (userId == null || userId.isEmpty) return false;
    return document.clientId == userId;
  }

  void _toast(String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  String _describe(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _run(Future<void> Function() action) async {
    onBusyChanged(true);
    try {
      await action();
    } finally {
      onBusyChanged(false);
    }
  }

  /// Opens the document in the in-app viewer.
  ///
  /// The viewer fetches the bytes through the authenticated client, so this
  /// works for any document the signed-in user is allowed to read — the
  /// lawyer's own uploads and their engaged clients' files alike.
  void view(DocumentRecord document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(document: document),
      ),
    );
  }

  Future<void> rename(DocumentRecord document) async {
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RenameDocumentSheet(document: document),
    );

    if (newName == null || newName.trim().isEmpty || !context.mounted) return;

    await _run(() async {
      try {
        final updated = await ref
            .read(documentsProvider.notifier)
            .renameDocument(document.id, newName);
        if (updated != null) _toast('Renamed to "${updated.name}"');
      } catch (e) {
        _toast(_describe(e), isError: true);
      }
    });
  }

  Future<void> replace(DocumentRecord document) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: pickerExtensions,
      withData: true,
    );

    final file = picked?.files.single;
    if (file == null || (file.path == null && file.bytes == null)) return;
    if (!context.mounted) return;

    // Confirmed after the file is chosen, so the sizes shown are the real ones.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace document?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current document'),
            Text(
              '${document.name} • ${document.readableSize}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('New document'),
            Text(
              '${file.name} • ${_formatBytes(file.size)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace Document'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(() async {
      try {
        final updated = await ref.read(documentsProvider.notifier).replaceDocument(
              document.id,
              kIsWeb ? null : file.path,
              file.name,
              bytes: file.bytes,
            );
        if (updated != null) _toast('Document replaced successfully.');
      } catch (e) {
        // The server commits only once the new file is stored, so the original
        // really is intact when this fires.
        _toast(_describe(e), isError: true);
      }
    });
  }

  Future<void> delete(DocumentRecord document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this document?'),
        content: Text(
          'Are you sure you want to delete "${document.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(() async {
      try {
        final ok =
            await ref.read(documentsProvider.notifier).deleteDocument(document.id);
        _toast(ok ? 'Document deleted.' : 'Unable to delete document.',
            isError: !ok);
      } catch (e) {
        _toast(_describe(e), isError: true);
      }
    });
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Rename sheet, shared by both screens.
///
/// Seeded with the name WITHOUT its extension: the extension is not the user's
/// to change, and the server re-applies the stored file's own extension either
/// way, so a .pdf cannot be renamed into something that presents as anything
/// else.
class RenameDocumentSheet extends StatefulWidget {
  const RenameDocumentSheet({super.key, required this.document});

  final DocumentRecord document;

  @override
  State<RenameDocumentSheet> createState() => _RenameDocumentSheetState();
}

class _RenameDocumentSheetState extends State<RenameDocumentSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final name = widget.document.name;
    final dot = name.lastIndexOf('.');
    _controller =
        TextEditingController(text: dot > 0 ? name.substring(0, dot) : name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter a document name.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dot = widget.document.name.lastIndexOf('.');
    final extension = dot > 0 ? widget.document.name.substring(dot) : '';

    return Padding(
      // Lifts the sheet clear of the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Rename document',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current: ${widget.document.name}',
              style:
                  TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'New name',
                suffixText: extension,
                errorText: _error,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
