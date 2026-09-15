import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/case_note_model.dart';
import '../../../../providers/lawyer_client_provider.dart';
import 'lawyer_case_detail_screen.dart' show PracticeNoteTile;
import '../widgets/note_editor_sheet.dart';
import '../widgets/practice_widgets.dart';

/// Every private note the advocate has written, newest first, searchable.
///
/// Notes are stored per client, so this is a flattened view across the roster
/// rather than its own collection. Each row says whose file it belongs to,
/// since the same note text can mean very different things depending on that.
class LawyerNotesScreen extends ConsumerStatefulWidget {
  const LawyerNotesScreen({super.key});

  @override
  ConsumerState<LawyerNotesScreen> createState() => _LawyerNotesScreenState();
}

class _LawyerNotesScreenState extends ConsumerState<LawyerNotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final notesState = ref.watch(allLawyerNotesProvider);
    final clientNames = ref.watch(lawyerClientNamesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.practice_notes_title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickClientAndAddNote,
        icon: const Icon(Icons.add, color: AppColors.onGold),
        label: Text(
          loc.add_note,
          style: const TextStyle(
            color: AppColors.onGold,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: PracticeContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 12,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc.notes_private_note,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: PracticeSearchField(
                  controller: _searchController,
                  hintText: loc.search_notes_hint,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: notesState.when(
                  data: (allNotes) {
                    final notes = _filter(allNotes, clientNames);

                    if (notes.isEmpty) {
                      final filtering = _query.trim().isNotEmpty;
                      return PracticeEmptyState(
                        icon: filtering
                            ? Icons.search_off
                            : Icons.sticky_note_2_outlined,
                        title: filtering ? loc.no_notes_match : loc.no_notes_yet,
                        message: filtering ? null : loc.no_notes_yet_desc,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(lawyerClientsProvider);
                        ref.invalidate(allLawyerNotesProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: notes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return PracticeNoteTile(
                            note: note,
                            subtitle: clientNames[note.clientId],
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => PracticeErrorState(
                    onRetry: () {
                      ref.invalidate(lawyerClientsProvider);
                      ref.invalidate(allLawyerNotesProvider);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Searches the title, the body and the client's name — an advocate looking
  /// for "that note about the Sharma matter" may remember any of the three.
  List<CaseNoteModel> _filter(
    List<CaseNoteModel> notes,
    Map<String, String> clientNames,
  ) {
    final query = _query.toLowerCase().trim();
    if (query.isEmpty) return notes;

    return notes.where((note) {
      final client = (clientNames[note.clientId] ?? '').toLowerCase();
      return note.text.toLowerCase().contains(query) ||
          note.title.toLowerCase().contains(query) ||
          client.contains(query);
    }).toList();
  }

  /// A note has to belong to someone, so the client is chosen first.
  Future<void> _pickClientAndAddNote() async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final clients = ref.read(lawyerClientsProvider).valueOrNull ?? const [];

    if (clients.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(loc.no_clients_yet_desc)));
      return;
    }

    final selected = await showModalBottomSheet<LawyerClientModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientPickerSheet(clients: clients),
    );

    if (selected == null || !mounted) return;

    final saved = await showNoteEditorSheet(context, clientId: selected.id);
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.note_saved)));
    }
  }
}

class _ClientPickerSheet extends StatelessWidget {
  const _ClientPickerSheet({required this.clients});

  final List<LawyerClientModel> clients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.practice_clients_title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: clients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return PracticeCard(
                    onTap: () => Navigator.of(context).pop(client),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.surface,
                          child: const Icon(Icons.person, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            client.fullName.isNotEmpty ? client.fullName : '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
