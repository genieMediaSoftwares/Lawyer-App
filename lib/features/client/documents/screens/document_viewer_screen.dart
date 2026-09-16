import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/document_provider.dart';

/// Views a document in the app.
///
/// The bytes are fetched through the authenticated API client, never by handing
/// a URL to a browser: the view endpoint is protected, and a browser attaches
/// no session token — that is what produced a page of raw JSON where the
/// document should have been. Nothing is written to disk on the way.
///
/// Images and text render here. Everything else is offered as a download,
/// because the app carries no renderer for it — see the note on
/// [_UnsupportedPreview], which says so plainly rather than showing a broken
/// frame.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.document});

  final DocumentRecord document;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.document.canPreviewInApp) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await ref
          .read(documentsProvider.notifier)
          .fetchDocumentBytes(widget.document.id);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = widget.document;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${doc.extensionLabel} • ${doc.readableSize}',
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final doc = widget.document;

    if (!doc.canPreviewInApp) {
      return _UnsupportedPreview(document: doc);
    }

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document…'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) {
      return const Center(child: Text('This document appears to be empty.'));
    }

    if (doc.isImage) {
      // Pinch to zoom and drag to pan, without a dependency: InteractiveViewer
      // is what Flutter ships for exactly this.
      return InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            semanticLabel: doc.name,
            errorBuilder: (context, error, stack) => const Center(
              child: Text('This image could not be displayed.'),
            ),
          ),
        ),
      );
    }

    // Text-family documents render as selectable text.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        String.fromCharCodes(bytes),
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }
}

/// Shown for a document the app has no renderer for — PDF, DOCX and the like.
///
/// Deliberately explicit. The alternative considered was opening the protected
/// URL in a browser, which cannot attach the session token and therefore shows
/// the client a page of JSON saying their token is invalid. Saying "open it
/// with your device's viewer" is honest; showing a broken frame is not.
class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview({required this.document});

  final DocumentRecord document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                document.isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.description_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              document.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${document.extensionLabel} • ${document.readableSize}',
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 20),
            Text(
              'Previewing ${document.extensionLabel} files in the app is not '
              'available yet. Your document is stored safely and can be opened '
              'with your device’s document viewer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.4,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
