import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../models/case_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/lawyer_client_provider.dart';
import '../../../../routes/route_names.dart';
import 'lawyer_case_detail_screen.dart' show PracticeNoteTile;
import '../widgets/note_editor_sheet.dart';
import '../widgets/practice_widgets.dart';

/// One client: who they are, the matters they have brought, and the advocate's
/// private notes on them.
///
/// The client record and their cases both come from providers the app already
/// keeps live, so this screen issues no request of its own beyond the notes.
class LawyerClientDetailScreen extends ConsumerWidget {
  const LawyerClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final clientsState = ref.watch(lawyerClientsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.client_profile,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNote(context, ref),
        icon: const Icon(Icons.note_add_outlined, color: AppColors.onGold),
        label: Text(
          loc.add_note,
          style: const TextStyle(
            color: AppColors.onGold,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: clientsState.when(
          data: (clients) {
            LawyerClientModel? client;
            for (final c in clients) {
              if (c.id == clientId) {
                client = c;
                break;
              }
            }

            if (client == null) {
              return PracticeEmptyState(
                icon: Icons.person_off_outlined,
                title: loc.no_clients_match,
                message: loc.no_clients_yet_desc,
              );
            }

            return _ClientDetailBody(client: client);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => PracticeErrorState(
            onRetry: () => ref.invalidate(lawyerClientsProvider),
          ),
        ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showNoteEditorSheet(context, clientId: clientId);
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.note_saved)));
    }
  }
}

class _ClientDetailBody extends ConsumerWidget {
  const _ClientDetailBody({required this.client});

  final LawyerClientModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;

    final cases = ref
        .watch(lawyerCasesProvider)
        .maybeWhen(
          data: (all) => all.where((c) => c.clientId == client.id).toList(),
          orElse: () => const <CaseModel>[],
        );

    final notesState = ref.watch(clientNotesProvider(client.id));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(casesProvider.notifier).fetchCases(silent: true);
        ref.invalidate(clientNotesProvider(client.id));
      },
      child: PracticeContentWidth(
        child: ListView(
          // Bottom padding clears the extended FAB, which would otherwise sit
          // on top of the last note.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _ProfileCard(client: client),
            const SizedBox(height: 24),

            PracticeSectionHeader(
              title: loc.client_cases,
              subtitle: cases.isEmpty ? null : loc.cases_count_label(cases.length),
            ),
            if (cases.isEmpty)
              PracticeCard(
                child: Text(
                  loc.no_cases_yet,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              )
            else
              for (final caseItem in cases)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ClientCaseTile(caseItem: caseItem),
                ),

            const SizedBox(height: 24),
            PracticeSectionHeader(
              title: loc.practice_notes_title,
              subtitle: loc.notes_private_note,
            ),
            notesState.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return PracticeCard(
                    child: Text(
                      loc.no_notes_yet_desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedText,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final note in notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PracticeNoteTile(note: note),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.client});

  final LawyerClientModel client;

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
            children: [
              UserAvatar(
                imagePath: client.profileImage,
                radius: 26,
                name: client.fullName,
                subtitle: 'Client',
                backgroundColor: theme.colorScheme.surface,
                openOnTap: true,
                heroTag: 'client-detail-avatar-${client.id}',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  client.fullName.isNotEmpty ? client.fullName : '—',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (client.email.isNotEmpty ||
              client.mobile.isNotEmpty ||
              client.location.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              loc.contact_details,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            if (client.email.isNotEmpty)
              _ContactRow(icon: Icons.email_outlined, value: client.email),
            if (client.mobile.isNotEmpty)
              _ContactRow(icon: Icons.phone_outlined, value: client.mobile),
            if (client.location.isNotEmpty)
              _ContactRow(
                icon: Icons.location_on_outlined,
                value: client.location,
              ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientCaseTile extends StatelessWidget {
  const _ClientCaseTile({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return PracticeCard(
      // Client -> Case, closing the loop with the Case -> Client link on the
      // case detail screen.
      onTap: () => context.push(RouteNames.lawyerCaseDetailPath(caseItem.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caseItem.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caseItem.nextHearing == null
                      ? caseItem.category
                      : '${caseItem.category} · ${loc.next_hearing_label} '
                            '${DateFormat('dd MMM').format(caseItem.nextHearing!)}',
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
          const SizedBox(width: 8),
          PracticeStatusPill(
            label: caseItem.status,
            color: practiceCaseStatusColor(caseItem.status),
          ),
        ],
      ),
    );
  }
}
