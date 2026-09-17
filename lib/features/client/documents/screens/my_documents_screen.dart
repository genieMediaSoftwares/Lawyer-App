import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/document_provider.dart';
import '../../../documents/document_action_bar.dart';
import '../../../documents/document_actions.dart';
import 'document_viewer_screen.dart';

/// The client's document manager: search, filter, sort, and per-document
/// view / rename / replace / delete.
///
/// Searching, filtering and sorting all happen server-side — see
/// [DocumentNotifier.fetchDocuments]. Filtering a page of results on the device
/// would only ever narrow what had already been downloaded, which stops being
/// a search the moment a client has more documents than one response carries.
class MyDocumentsScreen extends ConsumerStatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  ConsumerState<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends ConsumerState<MyDocumentsScreen> {
  final _searchController = TextEditingController();

  bool _isUploading = false;

  /// Ids with an operation in flight, so a card's buttons disable themselves
  /// rather than letting a second tap start a duplicate rename or delete.
  final Set<String> _busyIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  /// Unwraps the `Exception: ` prefix so the client reads the message the
  /// provider composed, not Dart's wrapper around it.
  String _describe(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _runExclusively(String docId, Future<void> Function() action) async {
    if (_busyIds.contains(docId)) return;
    setState(() => _busyIds.add(docId));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyIds.remove(docId));
    }
  }

  List<String> get _pickerExtensions => DocumentActions.pickerExtensions;

  // ── operations ───────────────────────────────────────────────────────────

  Future<void> _pickAndUploadFile() async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _pickerExtensions,
      withData: true,
    );

    final file = result?.files.single;
    if (file == null || (file.path == null && file.bytes == null)) return;

    setState(() => _isUploading = true);
    try {
      final newDoc = await ref.read(documentsProvider.notifier).uploadDocument(
            kIsWeb ? null : file.path,
            file.name,
            bytes: file.bytes,
          );
      if (!mounted) return;
      _toast(newDoc != null ? loc.doc_uploaded_success : loc.doc_upload_failed,
          isError: newDoc == null);
    } catch (e) {
      _toast(_describe(e), isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _renameDocument(DocumentRecord doc) async {
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // keeps the field above the keyboard
      backgroundColor: Colors.transparent,
      // The shared sheet, so the client and lawyer screens cannot drift apart
      // on validation or on how the extension is handled.
      builder: (_) => RenameDocumentSheet(document: doc),
    );

    if (newName == null || newName.trim().isEmpty) return;

    await _runExclusively(doc.id, () async {
      try {
        final updated =
            await ref.read(documentsProvider.notifier).renameDocument(doc.id, newName);
        if (updated != null) _toast('Renamed to "${updated.name}"');
      } catch (e) {
        _toast(_describe(e), isError: true);
      }
    });
  }

  Future<void> _replaceDocument(DocumentRecord doc) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _pickerExtensions,
      withData: true,
    );

    final file = picked?.files.single;
    if (file == null || (file.path == null && file.bytes == null)) return;
    if (!mounted) return;

    // Confirmed only after the file is chosen, so the sizes being compared are
    // the real ones rather than a promise.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace document?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current'),
            Text(
              '${doc.name} • ${doc.readableSize}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Replacement'),
            Text(
              '${file.name} • ${_formatBytes(file.size)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'The current file will be replaced. This cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(dialogContext).textTheme.bodySmall?.color,
              ),
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
            child: const Text('Replace document'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runExclusively(doc.id, () async {
      try {
        final updated = await ref.read(documentsProvider.notifier).replaceDocument(
              doc.id,
              kIsWeb ? null : file.path,
              file.name,
              bytes: file.bytes,
            );
        if (updated != null) _toast('Document replaced');
      } catch (e) {
        // The server commits only after the new file is stored, so the
        // original really is still intact when this fires.
        _toast(_describe(e), isError: true);
      }
    });
  }

  Future<void> _deleteDocument(DocumentRecord doc) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.delete_document),
        content: Text(
          'Are you sure you want to delete "${doc.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.delete, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runExclusively(doc.id, () async {
      try {
        final ok = await ref.read(documentsProvider.notifier).deleteDocument(doc.id);
        _toast(ok ? loc.doc_deleted_success : 'Unable to delete document.',
            isError: !ok);
      } catch (e) {
        _toast(_describe(e), isError: true);
      }
    });
  }

  void _openViewer(DocumentRecord doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(document: doc)),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final documentsState = ref.watch(documentsProvider);
    final query = ref.watch(documentQueryProvider);
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: loc.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(loc.my_documents,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        backgroundColor: theme.colorScheme.primary,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload, color: AppColors.onGold),
        label: Text(
          _isUploading ? loc.uploading : loc.upload_document,
          style: const TextStyle(
              color: AppColors.onGold, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildControls(theme, query),
          Expanded(
            child: documentsState.when(
              data: (documents) => _buildList(theme, loc, documents, query),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildError(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme, DocumentQuery query) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: ref.read(documentsProvider.notifier).search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search documents...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(documentsProvider.notifier).search('');
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Chips scroll horizontally so they never overflow a narrow phone.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in DocumentFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter.label),
                            selected: query.filter == filter,
                            onSelected: (_) => ref
                                .read(documentsProvider.notifier)
                                .setFilter(filter),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<DocumentSort>(
                tooltip: 'Sort documents',
                icon: const Icon(Icons.sort),
                onSelected: ref.read(documentsProvider.notifier).setSort,
                itemBuilder: (_) => [
                  for (final sort in DocumentSort.values)
                    PopupMenuItem(
                      value: sort,
                      child: Row(
                        children: [
                          Icon(
                            query.sort == sort
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(sort.label),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Unable to load your documents.',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(documentsProvider.notifier).fetchDocuments(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    ThemeData theme,
    AppLocalizations loc,
    List<DocumentRecord> documents,
    DocumentQuery query,
  ) {
    if (documents.isEmpty) {
      // "Nothing matched" and "nothing here yet" are different problems and
      // need different answers — one is solved by clearing the search.
      final isFiltered =
          query.search.trim().isNotEmpty || query.filter != DocumentFilter.all;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isFiltered ? Icons.search_off : Icons.folder_open_outlined,
                size: 72,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered ? 'No documents found' : loc.no_documents_found,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFiltered
                    ? 'Try a different search or filter.'
                    : loc.upload_documents_tip,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodySmall?.color),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(documentsProvider.notifier).fetchDocuments(showLoading: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // One column on a phone, two on a tablet, three on a wide window.
          final columns = constraints.maxWidth >= 1100
              ? 3
              : constraints.maxWidth >= 700
                  ? 2
                  : 1;

          final cards = [
            for (final doc in documents)
              _DocumentCard(
                document: doc,
                busy: _busyIds.contains(doc.id),
                onOpen: () => _openViewer(doc),
                onRename: () => _renameDocument(doc),
                onReplace: () => _replaceDocument(doc),
                onDelete: () => _deleteDocument(doc),
              ),
          ];

          if (columns == 1) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: cards,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            child: Wrap(
              spacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: (constraints.maxWidth - 32 - (columns - 1) * 12) /
                        columns,
                    child: card,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One document, with its actions.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.busy,
    required this.onOpen,
    required this.onRename,
    required this.onReplace,
    required this.onDelete,
  });

  final DocumentRecord document;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  IconData get _icon {
    if (document.isPdf) return Icons.picture_as_pdf;
    if (document.isImage) return Icons.image;
    if (document.isAudio) return Icons.audiotrack;
    if (document.isText) return Icons.article_outlined;
    return Icons.insert_drive_file;
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        // The whole card opens the viewer, which is the action people reach for
        // most and the hardest to hit if it were an icon.
        onTap: busy ? null : onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(_icon, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          // Long legal filenames wrap rather than overflowing.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${document.extensionLabel} • ${document.readableSize}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        Text(
                          'Uploaded ${_formatDate(document.uploadedAt)}'
                          '${document.contentUpdatedAt != null ? ' • Replaced ${_formatDate(document.contentUpdatedAt!)}' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Wraps onto a second line rather than clipping. See
              // [DocumentActionBar] for what this replaced and why.
              DocumentActionBar(
                busy: busy,
                onView: onOpen,
                onRename: onRename,
                onReplace: onReplace,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
