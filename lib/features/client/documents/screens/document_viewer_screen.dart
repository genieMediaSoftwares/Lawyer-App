import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/document_provider.dart';

/// Renders a stored document in the app.
///
/// PDFs are rendered page by page by pdfrx; images render with pinch-zoom;
/// text renders as selectable text. Nothing here is a placeholder — a document
/// the app genuinely cannot render says so and offers a download, which is only
/// reached by formats with no renderer (DOC/DOCX).
///
/// The bytes are fetched once, through the authenticated API client, and handed
/// to the renderer from memory. This is deliberate: the view endpoint is
/// protected, and neither a browser nor a PDF widget pointed at a bare URL
/// attaches the session token — that is what produced a page of JSON where the
/// document should have been. Fetching first means the token travels as a
/// header on a normal API call, and the renderer never touches the network.
///
/// Uploads are capped at 10MB server-side (upload.middleware), so holding one
/// document in memory is bounded and well within budget.
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

  /// Filled once the PDF opens, so the header can show "Page 2 of 14".
  int? _pageCount;
  int _currentPage = 1;

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

      if (bytes.isEmpty) {
        setState(() {
          _error = 'This document is empty.';
          _loading = false;
        });
        return;
      }

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

    final subtitle = [
      doc.extensionLabel,
      doc.readableSize,
      if (_pageCount != null) 'Page $_currentPage of $_pageCount',
    ].join(' • ');

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
              subtitle,
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
      return _NoRendererAvailable(document: doc);
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
      return _ViewerError(message: _error!, onRetry: _load);
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (doc.isPdf) return _buildPdf(bytes, theme);
    if (doc.isImage) return _buildImage(bytes, doc.name);
    return _buildText(bytes);
  }

  Widget _buildPdf(Uint8List bytes, ThemeData theme) {
    return PdfViewer.data(
      bytes,
      // Identifies this document to the renderer's cache. The id is stable and
      // unique; the display name is neither, and two documents may share one.
      sourceName: widget.document.id,
      params: PdfViewerParams(
        margin: 6,
        backgroundColor: theme.scaffoldBackgroundColor,
        onViewerReady: (document, controller) {
          if (!mounted) return;
          setState(() => _pageCount = document.pages.length);
        },
        onPageChanged: (pageNumber) {
          if (!mounted || pageNumber == null) return;
          setState(() => _currentPage = pageNumber);
        },
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
            const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Rendering document…'),
            ],
          ),
        ),
        // A PDF that will not parse — corrupt, or encrypted with a password we
        // do not have. Reported as itself rather than as a blank page.
        errorBannerBuilder: (context, error, stackTrace, documentRef) =>
            _ViewerError(
          message: 'This PDF could not be displayed. '
              'It may be damaged or password-protected.',
          onRetry: _load,
        ),
      ),
    );
  }

  Widget _buildImage(Uint8List bytes, String name) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          semanticLabel: name,
          errorBuilder: (context, error, stack) => const Center(
            child: Text('This image could not be displayed.'),
          ),
        ),
      ),
    );
  }

  Widget _buildText(Uint8List bytes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        String.fromCharCodes(bytes),
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }
}

/// Error state with a way out of it.
class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Unable to load document',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only for formats with no Flutter renderer — DOC and DOCX.
///
/// PDFs and images no longer reach this: they render above. Converting DOCX
/// server-side would need a converter (LibreOffice headless) on the EC2 box,
/// which is an infrastructure decision, not a code one.
class _NoRendererAvailable extends StatelessWidget {
  const _NoRendererAvailable({required this.document});

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
                Icons.description_outlined,
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
              '${document.extensionLabel} files open with your device’s '
              'document app. Your file is stored safely and unchanged.',
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
