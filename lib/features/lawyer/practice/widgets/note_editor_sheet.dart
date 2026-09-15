import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/case_model.dart';
import '../../../../models/case_note_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/lawyer_client_provider.dart';

/// Writes or edits one private practice note.
///
/// The note is stored against a client and may optionally be filed against one
/// of that client's cases. Both the client detail screen and the Notes screen
/// open this, so the two cannot ask for different fields.
///
/// Returns true when a write succeeded.
Future<bool> showNoteEditorSheet(
  BuildContext context, {
  required String clientId,
  String? lockedCaseId,
  CaseNoteModel? existing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _NoteEditorSheet(
      clientId: clientId,
      lockedCaseId: lockedCaseId,
      existing: existing,
    ),
  );
  return result ?? false;
}

class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({
    required this.clientId,
    this.lockedCaseId,
    this.existing,
  });

  final String clientId;

  /// Set when the sheet is opened from inside a case, so the note is filed
  /// against that case and the picker is not offered at all.
  final String? lockedCaseId;
  final CaseNoteModel? existing;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  String _caseId = '';
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _textController = TextEditingController(text: widget.existing?.text ?? '');
    _caseId = widget.lockedCaseId ?? widget.existing?.caseId ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final text = _textController.text.trim();

    if (text.isEmpty) {
      setState(() => _error = loc.note_content_required);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(clientNoteRepositoryProvider);
    final failure = _isEditing
        ? await repo.updateNote(
            clientId: widget.clientId,
            noteId: widget.existing!.id,
            text: text,
            title: _titleController.text.trim(),
            caseId: _caseId,
          )
        : await repo.addNote(
            clientId: widget.clientId,
            text: text,
            title: _titleController.text.trim(),
            caseId: _caseId,
          );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    // Only this client's own matters are offered, so a note cannot be filed
    // against someone else's case. The server rejects that too; this keeps the
    // wrong option off the screen in the first place.
    final cases = ref
        .watch(lawyerCasesProvider)
        .maybeWhen(
          data: (all) =>
              all.where((c) => c.clientId == widget.clientId).toList(),
          orElse: () => const <CaseModel>[],
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  _isEditing ? loc.edit_note : loc.add_note,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        loc.notes_private_note,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _titleController,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: loc.note_title_label,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _textController,
                  enabled: !_saving,
                  maxLines: 6,
                  autofocus: !_isEditing,
                  decoration: InputDecoration(
                    labelText: loc.note_content_label,
                    alignLabelWithHint: true,
                  ),
                ),

                if (widget.lockedCaseId == null && cases.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _caseId.isEmpty ? '' : _caseId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: loc.link_to_case,
                      isDense: true,
                      prefixIcon: const Icon(Icons.folder_outlined, size: 18),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          loc.no_case_linked,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                      ...cases.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _caseId = value ?? ''),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 15,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(loc.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(loc.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
