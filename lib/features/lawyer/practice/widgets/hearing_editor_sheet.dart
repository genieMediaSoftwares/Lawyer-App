import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/hearing_model.dart';
import '../../../../providers/hearing_provider.dart';

/// Adds or edits one court hearing on a case.
///
/// Opened from the case detail screen and from the Hearings screen, so the two
/// cannot drift into asking for different fields. Returns true when a write
/// succeeded, so the caller can show its own confirmation.
///
/// This is deliberately not the appointment dialog from the lawyer dashboard:
/// that books a client consultation into a fixed 30-minute slot and syncs it to
/// Google Calendar. A court date is not a slot the advocate chooses, so the
/// time here is free text and nothing is written to any calendar.
Future<bool> showHearingEditorSheet(
  BuildContext context, {
  required String caseId,
  required String caseTitle,
  HearingModel? existing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HearingEditorSheet(
      caseId: caseId,
      caseTitle: caseTitle,
      existing: existing,
    ),
  );
  return result ?? false;
}

class _HearingEditorSheet extends ConsumerStatefulWidget {
  const _HearingEditorSheet({
    required this.caseId,
    required this.caseTitle,
    this.existing,
  });

  final String caseId;
  final String caseTitle;
  final HearingModel? existing;

  @override
  ConsumerState<_HearingEditorSheet> createState() => _HearingEditorSheetState();
}

class _HearingEditorSheetState extends ConsumerState<_HearingEditorSheet> {
  late final TextEditingController _timeController;
  late final TextEditingController _courtController;
  late final TextEditingController _purposeController;
  late final TextEditingController _notesController;

  DateTime? _date;
  late String _status;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _timeController = TextEditingController(text: existing?.timeSlot ?? '');
    _courtController = TextEditingController(text: existing?.court ?? '');
    _purposeController = TextEditingController(text: existing?.purpose ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _date = existing?.date;
    _status = existing?.status ?? 'scheduled';
  }

  @override
  void dispose() {
    _timeController.dispose();
    _courtController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      // Past dates are allowed: an advocate may be recording a hearing that
      // already happened, which is the whole point of the "past" list.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;

    if (_date == null) {
      setState(() => _error = loc.hearing_date_required);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(hearingRepositoryProvider);
    final failure = _isEditing
        ? await repo.updateHearing(
            caseId: widget.caseId,
            hearingId: widget.existing!.id,
            date: _date,
            timeSlot: _timeController.text.trim(),
            court: _courtController.text.trim(),
            purpose: _purposeController.text.trim(),
            status: _status,
            notes: _notesController.text.trim(),
          )
        : await repo.addHearing(
            caseId: widget.caseId,
            date: _date!,
            timeSlot: _timeController.text.trim(),
            court: _courtController.text.trim(),
            purpose: _purposeController.text.trim(),
            notes: _notesController.text.trim(),
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

    return Padding(
      // Lifts the sheet clear of the keyboard, so the notes field at the
      // bottom is still reachable while typing into it.
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
                  _isEditing ? loc.edit_hearing : loc.add_hearing,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.caseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Date ──────────────────────────────────────────────────
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: loc.hearing_date,
                      isDense: true,
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      _date == null
                          ? '—'
                          : DateFormat('EEEE, dd MMM yyyy').format(_date!),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _timeController,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: loc.hearing_time,
                    hintText: loc.hearing_time_hint,
                    isDense: true,
                    prefixIcon: const Icon(Icons.schedule, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _courtController,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: loc.hearing_court,
                    isDense: true,
                    prefixIcon: const Icon(Icons.account_balance, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _purposeController,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: loc.hearing_purpose,
                    hintText: loc.hearing_purpose_hint,
                    isDense: true,
                    prefixIcon: const Icon(Icons.subject, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                // Status is offered only when editing: a hearing is created
                // scheduled, and marking it completed at the moment it is
                // added would be meaningless.
                if (_isEditing) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: loc.hearing_status,
                      isDense: true,
                      prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text(loc.hearing_status_scheduled),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text(loc.hearing_status_completed),
                      ),
                      DropdownMenuItem(
                        value: 'adjourned',
                        child: Text(loc.hearing_status_adjourned),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text(loc.hearing_status_cancelled),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _status = value ?? 'scheduled'),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _notesController,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: loc.hearing_notes,
                    alignLabelWithHint: true,
                  ),
                ),

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
