import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/lawyer_client_provider.dart';
import '../../../../routes/route_names.dart';
import '../widgets/practice_widgets.dart';

/// The advocate's client roster, client-first rather than case-first.
///
/// The Clients tab on the dashboard lists *cases* grouped by stage, which is
/// the right view when working through a pipeline. This is the other view: one
/// row per person, with everything they have brought behind it. Both read from
/// the same data, so neither can show a client the other does not.
class LawyerClientsScreen extends ConsumerStatefulWidget {
  const LawyerClientsScreen({super.key});

  @override
  ConsumerState<LawyerClientsScreen> createState() =>
      _LawyerClientsScreenState();
}

class _LawyerClientsScreenState extends ConsumerState<LawyerClientsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(lawyerClientSearchProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final clientsState = ref.watch(filteredLawyerClientsProvider);
    final query = ref.watch(lawyerClientSearchProvider);

    // Case counts per client, so a row can say how many matters sit behind it
    // without a second request.
    final caseCounts = ref
        .watch(lawyerCasesProvider)
        .maybeWhen(
          data: (cases) {
            final counts = <String, int>{};
            for (final c in cases) {
              counts[c.clientId] = (counts[c.clientId] ?? 0) + 1;
            }
            return counts;
          },
          orElse: () => const <String, int>{},
        );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.practice_clients_title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: PracticeContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: PracticeSearchField(
                  controller: _searchController,
                  hintText: loc.search_clients_hint,
                  onChanged: (value) => ref
                      .read(lawyerClientSearchProvider.notifier)
                      .state = value,
                ),
              ),
              Expanded(
                child: clientsState.when(
                  data: (clients) {
                    if (clients.isEmpty) {
                      final filtering = query.trim().isNotEmpty;
                      return PracticeEmptyState(
                        icon: filtering
                            ? Icons.search_off
                            : Icons.people_outline,
                        title: filtering
                            ? loc.no_clients_match
                            : loc.no_clients_yet,
                        message: filtering ? null : loc.no_clients_yet_desc,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(lawyerClientsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: clients.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          return _ClientCard(
                            client: client,
                            caseCount: caseCounts[client.id] ?? 0,
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => PracticeErrorState(
                    onRetry: () => ref.invalidate(lawyerClientsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.caseCount});

  final LawyerClientModel client;
  final int caseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return PracticeCard(
      onTap: () =>
          context.push(RouteNames.lawyerClientDetailPath(client.id)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.surface,
            backgroundImage: client.profileImage.isNotEmpty
                ? NetworkImage(AppConfig.getAttachmentUrl(client.profileImage))
                : null,
            child: client.profileImage.isEmpty
                ? const Icon(Icons.person, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.fullName.isNotEmpty ? client.fullName : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (client.location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    client.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
                if (caseCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    loc.cases_count_label(caseCount),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.mutedText,
          ),
        ],
      ),
    );
  }
}
