import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/case_model.dart';
import '../../../../models/case_note_model.dart';
import '../../../../models/document_model.dart';
import '../../../../models/hearing_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/hearing_provider.dart';
import '../../../../providers/lawyer_client_provider.dart';
import '../../../../routes/route_names.dart';
import '../widgets/hearing_editor_sheet.dart';
import '../widgets/note_editor_sheet.dart';
import '../widgets/practice_widgets.dart';

/// One matter, with everything attached to it: the client, the documents filed
/// with it, its hearings and the advocate's private notes on it.
///
/// This is the join between five of the six practice areas, which is why it
/// reads its case from [lawyerCasesProvider] rather than fetching `/cases/:id`
/// separately: that list is already live over the /cases socket, so adding a
/// hearing here updates the card behind it without a refetch, and the screen
/// cannot show a case in a state the list disagrees with.
class LawyerCaseDetailScreen extends ConsumerWidget {
  const LawyerCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final casesState = ref.watch(lawyerCasesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.case_details,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: casesState.when(
          data: (cases) {
            CaseModel? caseItem;
            for (final c in cases) {
              if (c.id == caseId) {
                caseItem = c;
                break;
              }
            }

            if (caseItem == null) {
              // Reached by a stale deep link, or by a case that has since been
              // reassigned. Neither is an error worth a red screen.
              return PracticeEmptyState(
                icon: Icons.folder_off_outlined,
                title: loc.no_cases_match,
                message: loc.no_cases_match_desc,
              );
            }

            return _CaseDetailBody(caseItem: caseItem);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => PracticeErrorState(
            onRetry: () => ref.read(casesProvider.notifier).fetchCases(),
          ),
        ),
      ),
    );
  }
}

class _CaseDetailBody extends ConsumerWidget {
  const _CaseDetailBody({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    // Only the notes filed against this case. The server already returns just
    // this advocate's own notes for the client, so this narrows by matter, not
    // by author.
    final notesState = ref
        .watch(clientNotesProvider(caseItem.clientId))
        .whenData(
          (notes) => notes.where((n) => n.caseId == caseItem.id).toList(),
        );

    final hearings = List<HearingModel>.from(caseItem.hearings)
      ..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(casesProvider.notifier).fetchCases(silent: true);
        ref.invalidate(clientNotesProvider(caseItem.clientId));
      },
      child: PracticeContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _OverviewSection(caseItem: caseItem),
            const SizedBox(height: 24),
            _ClientSection(caseItem: caseItem),
            const SizedBox(height: 24),
            _HearingsSection(caseItem: caseItem, hearings: hearings),
            const SizedBox(height: 24),
            _DocumentsSection(documents: caseItem.documents),
            const SizedBox(height: 24),
            _NotesSection(caseItem: caseItem, notesState: notesState),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${loc.filed_on} '
                '${DateFormat('dd MMM yyyy').format(caseItem.createdAt)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Overview ────────────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return PracticeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  caseItem.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PracticeStatusPill(
                label: caseItem.status,
                color: practiceCaseStatusColor(caseItem.status),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(icon: Icons.category_outlined, label: caseItem.category),
              if ((caseItem.subcategory ?? '').isNotEmpty)
                _Tag(
                  icon: Icons.label_outline,
                  label: caseItem.subcategory!,
                ),
              if (caseItem.location.isNotEmpty)
                _Tag(
                  icon: Icons.location_on_outlined,
                  label: caseItem.location,
                ),
              if ((caseItem.preferredCourt ?? '').isNotEmpty)
                _Tag(
                  icon: Icons.account_balance_outlined,
                  label: caseItem.preferredCourt!,
                ),
            ],
          ),

          if (caseItem.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              loc.case_description,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              caseItem.description,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.gavel_outlined,
                  size: 16,
                  color: AppColors.primaryGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    caseItem.nextHearing == null
                        ? loc.no_hearing_scheduled
                        : '${loc.next_hearing_label}: '
                              '${DateFormat('EEEE, dd MMM yyyy').format(caseItem.nextHearing!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.mutedText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

// ─── Client ──────────────────────────────────────────────────────────────────

class _ClientSection extends StatelessWidget {
  const _ClientSection({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PracticeSectionHeader(title: loc.client_profile),
        PracticeCard(
          // Case -> Client. The reverse leg lives on the client detail screen,
          // so an advocate can move between the two without going back to a
          // list in between.
          onTap: caseItem.clientId.isEmpty
              ? null
              : () => context.push(
                  RouteNames.lawyerClientDetailPath(caseItem.clientId),
                ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.surface,
                backgroundImage: caseItem.clientImage.isNotEmpty
                    ? NetworkImage(
                        AppConfig.getAttachmentUrl(caseItem.clientImage),
                      )
                    : null,
                child: caseItem.clientImage.isEmpty
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  caseItem.clientName.isNotEmpty ? caseItem.clientName : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (caseItem.clientId.isNotEmpty)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.mutedText,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Hearings ────────────────────────────────────────────────────────────────

class _HearingsSection extends ConsumerWidget {
  const _HearingsSection({required this.caseItem, required this.hearings});

  final CaseModel caseItem;
  final List<HearingModel> hearings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PracticeSectionHeader(
          title: loc.practice_hearings_title,
          subtitle: loc.hearings_consultation_note,
          action: TextButton.icon(
            onPressed: () => _addHearing(context),
            icon: const Icon(Icons.add, size: 16),
            label: Text(loc.add_hearing, style: const TextStyle(fontSize: 12)),
          ),
        ),
        if (hearings.isEmpty)
          PracticeCard(
            child: Row(
              children: [
                const Icon(
                  Icons.event_busy_outlined,
                  size: 18,
                  color: AppColors.mutedText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.no_hearings_yet_desc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final hearing in hearings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HearingTile(caseItem: caseItem, hearing: hearing),
            ),
      ],
    );
  }

  Future<void> _addHearing(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showHearingEditorSheet(
      context,
      caseId: caseItem.id,
      caseTitle: caseItem.title,
    );

    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.hearing_saved)));
    }
  }
}

class _HearingTile extends ConsumerWidget {
  const _HearingTile({required this.caseItem, required this.hearing});

  final CaseModel caseItem;
  final HearingModel hearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final statusColor = practiceHearingStatusColor(hearing.status);

    return PracticeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(hearing.date),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(hearing.date).toUpperCase(),
                  style: TextStyle(fontSize: 9, color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hearing.purpose.isNotEmpty
                            ? hearing.purpose
                            : DateFormat('EEEE').format(hearing.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    PracticeStatusPill(
                      label: practiceHearingStatusLabel(loc, hearing.status),
                      color: statusColor,
                    ),
                  ],
                ),
                if (hearing.timeSlot.isNotEmpty || hearing.court.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (hearing.timeSlot.isNotEmpty) hearing.timeSlot,
                      if (hearing.court.isNotEmpty) hearing.court,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
                if (hearing.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    hearing.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (value) => value == 'edit'
                ? _edit(context)
                : _delete(context, ref),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(loc.edit, style: const TextStyle(fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  loc.delete,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showHearingEditorSheet(
      context,
      caseId: caseItem.id,
      caseTitle: caseItem.title,
      existing: hearing,
    );

    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.hearing_saved)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.delete_hearing),
        content: Text(loc.confirm_delete_hearing),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.delete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final failure = await ref
        .read(hearingRepositoryProvider)
        .deleteHearing(caseId: caseItem.id, hearingId: hearing.id);

    messenger.showSnackBar(
      SnackBar(content: Text(failure ?? loc.hearing_deleted)),
    );
  }
}

// ─── Documents ───────────────────────────────────────────────────────────────

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.documents});

  final List<DocumentModel> documents;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PracticeSectionHeader(
          title: loc.case_attachments,
          subtitle: documents.isEmpty
              ? null
              : loc.documents_count_label(documents.length),
        ),
        if (documents.isEmpty)
          PracticeCard(
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: AppColors.mutedText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.no_documents_found,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final doc in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DocumentTile(document: doc),
            ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final DocumentModel document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PracticeCard(
      onTap: () => openPracticeDocument(context, document.url),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.insert_drive_file_outlined,
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
                  document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (document.size.isNotEmpty)
                  Text(
                    document.size,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new,
            size: 16,
            color: AppColors.mutedText,
          ),
        ],
      ),
    );
  }
}

/// Opens a stored file in the platform handler.
///
/// The URL goes through [AppConfig.getAttachmentUrl], which resolves it against
/// the API host and appends the session token for the protected upload folders.
/// That is what the server's file authorization middleware expects — a raw
/// path would be refused, and building the URL any other way here would mean
/// two places that have to agree about how private files are reached.
Future<void> openPracticeDocument(BuildContext context, String url) async {
  final loc = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  final resolved = AppConfig.getAttachmentUrl(url);
  if (resolved.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(loc.could_not_open_document)),
    );
    return;
  }

  final uri = Uri.tryParse(resolved);
  final launched =
      uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!launched) {
    messenger.showSnackBar(
      SnackBar(content: Text(loc.could_not_open_document)),
    );
  }
}

// ─── Notes ───────────────────────────────────────────────────────────────────

class _NotesSection extends ConsumerWidget {
  const _NotesSection({required this.caseItem, required this.notesState});

  final CaseModel caseItem;
  final AsyncValue<List<CaseNoteModel>> notesState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PracticeSectionHeader(
          title: loc.practice_notes_title,
          subtitle: loc.notes_private_note,
          action: caseItem.clientId.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: () => _addNote(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    loc.add_note,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
        ),
        notesState.when(
          data: (notes) {
            if (notes.isEmpty) {
              return PracticeCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.no_notes_yet_desc,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PracticeNoteTile(
                      note: note,
                      lockedCaseId: caseItem.id,
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => PracticeCard(
            child: Text(
              loc.something_went_wrong,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addNote(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showNoteEditorSheet(
      context,
      clientId: caseItem.clientId,
      lockedCaseId: caseItem.id,
    );

    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.note_saved)));
    }
  }
}

/// One note, with edit and delete. Shared with the Notes and client screens so
/// a note looks and behaves the same wherever it is met.
class PracticeNoteTile extends ConsumerWidget {
  const PracticeNoteTile({
    super.key,
    required this.note,
    this.lockedCaseId,
    this.subtitle,
  });

  final CaseNoteModel note;
  final String? lockedCaseId;

  /// Extra context line, used by the cross-client Notes screen to say whose
  /// file the note is in.
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return PracticeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) => value == 'edit'
                    ? _edit(context)
                    : _delete(context, ref),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(loc.edit, style: const TextStyle(fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      loc.delete,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (note.title.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (subtitle != null) ...[
                const Icon(
                  Icons.person_outline,
                  size: 11,
                  color: AppColors.mutedText,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                DateFormat('dd MMM yyyy').format(note.date),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedText,
                ),
              ),
              if (note.isEdited) ...[
                const SizedBox(width: 6),
                Text(
                  '· ${loc.edited_label}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showNoteEditorSheet(
      context,
      clientId: note.clientId,
      lockedCaseId: lockedCaseId,
      existing: note,
    );

    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.note_saved)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.delete_note),
        content: Text(loc.confirm_delete_note),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.delete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final failure = await ref
        .read(clientNoteRepositoryProvider)
        .deleteNote(clientId: note.clientId, noteId: note.id);

    messenger.showSnackBar(
      SnackBar(content: Text(failure ?? loc.note_deleted)),
    );
  }
}
