import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../models/case_model.dart';
import '../../../../models/document_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../features/documents/document_action_bar.dart';
import '../../../../features/documents/document_actions.dart';
import '../../../../routes/route_names.dart';
import '../../practice/screens/lawyer_case_detail_screen.dart'
    show openPracticeDocument;
import '../../practice/widgets/practice_widgets.dart';

/// The advocate's document library.
///
/// Enhanced in place rather than replaced by a second documents screen: this
/// one already existed, already used [documentsProvider], and is still reached
/// from the Profile tab. It now also appears in the practice section, so it
/// gained search, the case attachments it was previously blind to, and a way
/// to actually open a file.
///
/// Two sources feed it, and they are deliberately kept apart on screen because
/// they mean different things:
///   * client uploads — the `Document` collection, which the server already
///     scopes to the clients this advocate acts for;
///   * case attachments — the files filed with a case itself, which live on the
///     case record.
///
/// Uploaded documents open in the in-app viewer through [DocumentActions] —
/// the same component the client My Documents screen uses, so View, Rename,
/// Replace and Delete behave identically on both sides. Case attachments still
/// go through [openPracticeDocument], which opens the same in-app viewer via
/// the guarded /uploads mount: they are addressed by URL rather than by
/// document id, so they cannot yet reach the authenticated view endpoint.
/// Nothing here weakens access control: an advocate still only receives the documents the
/// server was already willing to give them.
class LawyerDocumentsScreen extends ConsumerStatefulWidget {
  const LawyerDocumentsScreen({super.key});

  @override
  ConsumerState<LawyerDocumentsScreen> createState() => _LawyerDocumentsScreenState();
}

class _LawyerDocumentsScreenState extends ConsumerState<LawyerDocumentsScreen> {
  bool _isUploading = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentActions.pickerExtensions,
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

    // Case attachments, flattened out of the advocate's own matters and
    // filtered by the same search box.
    final caseAttachments = ref
        .watch(lawyerCasesProvider)
        .maybeWhen(
          data: (cases) {
            final entries = <_CaseAttachment>[];
            for (final caseItem in cases) {
              for (final doc in caseItem.documents) {
                entries.add(
                  _CaseAttachment(document: doc, caseItem: caseItem),
                );
              }
            }
            return entries;
          },
          orElse: () => const <_CaseAttachment>[],
        )
        .where((a) => _matches(a.document.title))
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // Kept as a plain back action rather than context.pop(): this screen is
        // reached both by Navigator.push from the Profile tab and by a
        // GoRouter push from the practice grid, and Navigator.pop handles both.
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
      body: SafeArea(
        child: PracticeContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: PracticeSearchField(
                  controller: _searchController,
                  hintText: loc.search_documents_hint,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: documentsState.when(
                  data: (documents) {
                    final uploads = documents
                        .where((d) => _matches(d.originalName))
                        .toList();

                    if (uploads.isEmpty && caseAttachments.isEmpty) {
                      final filtering = _query.trim().isNotEmpty;
                      return PracticeEmptyState(
                        icon: filtering
                            ? Icons.search_off
                            : Icons.folder_open_outlined,
                        title: filtering
                            ? loc.no_documents_match
                            : loc.no_documents_found,
                        message: filtering ? null : loc.upload_documents_tip,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(documentsProvider.notifier)
                            .fetchDocuments();
                        await ref
                            .read(casesProvider.notifier)
                            .fetchCases(silent: true);
                      },
                      child: ListView(
                        // Clears the extended FAB so the last row is reachable.
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: [
                          if (caseAttachments.isNotEmpty) ...[
                            PracticeSectionHeader(
                              title: loc.case_attachments,
                              subtitle: loc.documents_count_label(
                                caseAttachments.length,
                              ),
                            ),
                            for (final attachment in caseAttachments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _CaseAttachmentTile(
                                  attachment: attachment,
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                          if (uploads.isNotEmpty) ...[
                            PracticeSectionHeader(
                              title: loc.client_uploads,
                              subtitle: loc.documents_count_label(
                                uploads.length,
                              ),
                            ),
                            for (final doc in uploads)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _UploadTile(
                                  document: doc,
                                  onDelete: () => _deleteDocument(doc.id),
                                ),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => PracticeErrorState(
                    onRetry: () =>
                        ref.read(documentsProvider.notifier).fetchDocuments(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matches(String name) {
    final query = _query.toLowerCase().trim();
    if (query.isEmpty) return true;
    return name.toLowerCase().contains(query);
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

/// A case attachment together with the matter it was filed on.
class _CaseAttachment {
  const _CaseAttachment({required this.document, required this.caseItem});

  final DocumentModel document;
  final CaseModel caseItem;
}

class _CaseAttachmentTile extends StatelessWidget {
  const _CaseAttachmentTile({required this.attachment});

  final _CaseAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PracticeCard(
      onTap: () => openPracticeDocument(
        context,
        attachment.document.url,
        name: attachment.document.name,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(
              _fileIcon(attachment.document.title),
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attachment.caseItem.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.folder_open_outlined,
              size: 18,
              color: AppColors.mutedText,
            ),
            tooltip: AppLocalizations.of(context)!.open_case,
            onPressed: () => context.push(
              RouteNames.lawyerCaseDetailPath(attachment.caseItem.id),
            ),
          ),
        ],
      ),
    );
  }
}

/// One document in the lawyer's list.
///
/// Consumes the shared [DocumentActions], so View, Rename, Replace and Delete
/// behave exactly as they do on the client My Documents screen — tapping a
/// document opens the in-app viewer rather than handing a protected URL to the
/// browser, which is what used to render a page of JSON.
class _UploadTile extends ConsumerStatefulWidget {
  const _UploadTile({required this.document, required this.onDelete});

  final DocumentRecord document;
  final VoidCallback onDelete;

  @override
  ConsumerState<_UploadTile> createState() => _UploadTileState();
}

class _UploadTileState extends ConsumerState<_UploadTile> {
  bool _busy = false;

  DocumentRecord get document => widget.document;

  DocumentActions get _actions => DocumentActions(
        ref: ref,
        context: context,
        onBusyChanged: (busy) {
          if (mounted) setState(() => _busy = busy);
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeInKb = (document.fileSize / 1024).toStringAsFixed(1);

    // Writes are owner-only server-side. A lawyer reading a client's evidence
    // is not offered actions that would be refused.
    final canModify = DocumentActions.canModify(
      document,
      ref.watch(authProvider).userId,
    );

    return PracticeCard(
      onTap: _busy ? null : () => _actions.view(document),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                _mimeIcon(document.mimeType),
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // The display name, which is what a rename changes.
                    // `originalName` never moves, so showing it meant a renamed
                    // document still displayed its old name here while the client
                    // screen showed the new one.
                    document.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${document.extensionLabel} · $sizeInKb KB · '
                    '${_formatDate(document.uploadedAt)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          // The same action bar the client's cards use, so View, Rename,
          // Replace and Delete read and behave identically on both sides of
          // the app. The owner-only actions are omitted entirely when this
          // advocate does not own the document — the server refuses those, and
          // a button that always fails is worse than no button.
          DocumentActionBar(
            busy: _busy,
            onView: () => _actions.view(document),
            onRename: canModify ? () => _actions.rename(document) : null,
            onReplace: canModify ? () => _actions.replace(document) : null,
            onDelete: canModify ? widget.onDelete : null,
          ),
        ],
      ),
    );
  }
}

IconData _mimeIcon(String mimeType) {
  if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
  if (mimeType.contains('image')) return Icons.image;
  return Icons.insert_drive_file;
}

/// Case attachments carry a filename rather than a MIME type, so the icon is
/// picked from the extension instead.
IconData _fileIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg')) {
    return Icons.image;
  }
  return Icons.insert_drive_file;
}

String _formatDate(DateTime dt) {
  return "${dt.day}/${dt.month}/${dt.year}";
}
