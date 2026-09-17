import 'dart:convert';
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
  const DocumentViewerScreen({super.key, required this.document})
      : uploadPath = null;

  /// Opens an attachment addressed by its stored upload PATH.
  ///
  /// Case attachments live on `Case.documents[]`, which records only
  /// `{name, url, size}` — no document id — so they cannot use the
  /// `/documents/:id/view` endpoint the client's own documents use. They are
  /// read through the guarded `/uploads` mount instead, which authorises each
  /// request against the case the file belongs to.
  ///
  /// Before this they were handed to the device browser, which attaches no
  /// session token — so a private attachment either refused to open or showed
  /// a page of JSON where the document should have been.
  DocumentViewerScreen.fromUpload({
    super.key,
    required String path,
    required String name,
    String mimeType = '',
    int size = 0,
  })  : uploadPath = path,
        document = DocumentRecord(
          // Synthesised for display only — nothing here is sent anywhere.
          id: path,
          clientId: '',
          originalName: name,
          name: name,
          fileName: name,
          filePath: path,
          mimeType: mimeType.isNotEmpty ? mimeType : _guessMime(name),
          fileSize: size,
          uploadedAt: DateTime.now(),
        );

  /// Non-null when this viewer was opened from a stored path rather than a
  /// document record, which decides how the bytes are fetched.
  final String? uploadPath;

  final DocumentRecord document;

  /// Case attachments carry no MIME type, so it is inferred from the
  /// extension purely to choose a renderer. Nothing security-relevant depends
  /// on it — the server decides what it will serve.
  ///
  /// Delegates to [DocumentRecord.mimeTypeForName] so there is one extension
  /// table in the app rather than one here and another in the record.
  static String _guessMime(String name) => DocumentRecord.mimeTypeForName(name);

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  Uint8List? _bytes;

  /// Set instead of [_bytes] for a format the server converts for us (.docx).
  DocumentPreview? _preview;

  String? _error;
  bool _loading = false;

  /// Filled once the PDF opens, so the header can show "Page 2 of 14".
  int? _pageCount;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    if (widget.document.isViewable) {
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
      // .docx has no renderer for its raw bytes, so the server converts it into
      // typed blocks instead. Same authenticated client, same permissions.
      if (widget.uploadPath == null &&
          !widget.document.canPreviewInApp &&
          widget.document.canPreviewViaConversion) {
        final preview = await ref
            .read(documentsProvider.notifier)
            .fetchDocumentPreview(widget.document.id);

        if (!mounted) return;
        setState(() {
          _preview = preview;
          _loading = false;
        });
        return;
      }

      final uploadPath = widget.uploadPath;
      final bytes = uploadPath != null
          // Addressed by path: the guarded /uploads mount.
          ? await ref.read(documentsProvider.notifier).fetchUploadBytes(uploadPath)
          // Addressed by id: the document API.
          : await ref
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

    if (!doc.isViewable) {
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

    final preview = _preview;
    if (preview != null) {
      return _ConvertedDocument(preview: preview);
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (doc.isPdf) return _buildPdf(bytes, theme);
    if (doc.isImage) return _buildImage(bytes, doc.name);
    if (doc.isText) return _buildText(bytes);

    // Anything else reaching here has bytes we have no renderer for — a .docx
    // opened by path (no document id, so the server-side conversion endpoint
    // is not addressable), or a legacy binary .doc. This used to fall through
    // to _buildText, which spelled the file's raw bytes out as characters and
    // filled the screen with mojibake. An honest "cannot preview" with a way
    // to open it elsewhere is better than pretending to have rendered it.
    return _NoRendererAvailable(document: doc);
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
    // Decoded as UTF-8, which is what the files actually are.
    //
    // `String.fromCharCodes` reads each BYTE as a code unit, so it is only
    // correct for pure ASCII. Every multi-byte character came out as two or
    // three Latin-1 letters: a Telugu or Hindi note — and this app takes case
    // descriptions in both — was unreadable, and so was any English document
    // containing a rupee sign, a curly quote or an accented name.
    //
    // `allowMalformed` keeps a file that is not valid UTF-8 (a Windows-1252
    // export, say) rendering with replacement characters instead of throwing
    // and showing an error page for a document that is mostly readable.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        utf8.decode(bytes, allowMalformed: true),
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }
}

/// Renders a server-converted document — today, a .docx.
///
/// Drawn with ordinary Flutter widgets from typed blocks, so the result
/// inherits the app's own typography and dark theme. Nothing here interprets
/// markup: the blocks carry text and flags, never HTML, which is what keeps a
/// hostile upload from being able to render anything it likes.
class _ConvertedDocument extends StatelessWidget {
  const _ConvertedDocument({required this.preview});

  final DocumentPreview preview;

  TextStyle _headingStyle(ThemeData theme, int level) {
    const sizes = {1: 22.0, 2: 19.0, 3: 17.0, 4: 15.5, 5: 14.5, 6: 14.0};
    return TextStyle(
      fontSize: sizes[level] ?? 15.0,
      fontWeight: FontWeight.bold,
      height: 1.3,
      color: theme.textTheme.titleMedium?.color,
    );
  }

  /// One paragraph, with each run carrying its own bold/italic/underline.
  Widget _runs(ThemeData theme, PreviewBlock block) {
    final base = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: theme.textTheme.bodyMedium?.color,
    );

    // A block with no run detail still has its text — fall back to it rather
    // than rendering nothing.
    if (block.runs.isEmpty) {
      return SelectableText(block.text, style: base);
    }

    return SelectableText.rich(
      TextSpan(
        children: [
          for (final run in block.runs)
            TextSpan(
              text: run.text,
              style: base.copyWith(
                fontWeight: run.bold ? FontWeight.bold : null,
                fontStyle: run.italic ? FontStyle.italic : null,
                decoration: run.underline ? TextDecoration.underline : null,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (preview.blocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This document has no readable content.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      itemCount: preview.blocks.length + (preview.truncated ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == preview.blocks.length) {
          // Said plainly, so nobody reads a partial document believing it whole.
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              'This document is very long — only the first part is shown. '
              'Download it to read the rest.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          );
        }

        final block = preview.blocks[index];

        switch (block.type) {
          case 'spacer':
            return const SizedBox(height: 14);

          case 'heading':
            return Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: SelectableText(
                block.text,
                style: _headingStyle(theme, block.level),
              ),
            );

          case 'listItem':
            return Padding(
              padding: EdgeInsets.only(
                left: 8.0 + block.indent * 18.0,
                bottom: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  Expanded(child: _runs(theme, block)),
                ],
              ),
            );

          case 'table':
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SingleChildScrollView(
                // Wide tables scroll rather than overflowing a phone.
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: block.rows.length > 1 ? 40 : 0,
                  columns: [
                    for (final cell in block.rows.first)
                      DataColumn(
                        label: Text(
                          cell,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                  rows: [
                    for (final row in block.rows.skip(1))
                      DataRow(
                        cells: [
                          for (var i = 0; i < block.rows.first.length; i++)
                            DataCell(
                              Text(
                                i < row.length ? row[i] : '',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );

          default:
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _runs(theme, block),
            );
        }
      },
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
              'Preview is not available for ${document.extensionLabel} files. '
              'Your document is stored safely and can be downloaded unchanged.',
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
