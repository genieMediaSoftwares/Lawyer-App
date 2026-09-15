import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/case_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../routes/route_names.dart';
import '../widgets/practice_widgets.dart';

/// The advocate's own matters: search, filter, sort, and open one.
///
/// Reads [filteredLawyerCasesProvider], which is derived from the existing
/// [casesProvider] rather than fetching its own list — so this screen is
/// already live over the /cases socket and cannot disagree with the Clients tab
/// or the workspace counts.
class LawyerCasesScreen extends ConsumerStatefulWidget {
  const LawyerCasesScreen({super.key});

  @override
  ConsumerState<LawyerCasesScreen> createState() => _LawyerCasesScreenState();
}

class _LawyerCasesScreenState extends ConsumerState<LawyerCasesScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider so returning to this screen restores whatever
    // the advocate had typed, rather than showing a filtered list under an
    // empty search box.
    _searchController = TextEditingController(
      text: ref.read(lawyerCaseSearchProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final casesState = ref.watch(filteredLawyerCasesProvider);
    final statuses = ref.watch(lawyerCaseStatusesProvider);
    final activeStatus = ref.watch(lawyerCaseStatusFilterProvider);
    final query = ref.watch(lawyerCaseSearchProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.lawyer_cases_title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: loc.sort_by,
            onSelected: (value) =>
                ref.read(lawyerCaseSortProvider.notifier).state = value,
            itemBuilder: (context) => [
              _sortItem('Newest', loc.sort_newest),
              _sortItem('Oldest', loc.sort_oldest),
              _sortItem('Hearing', loc.sort_hearing),
              _sortItem('Client', loc.sort_client),
              _sortItem('Status', loc.sort_status),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: PracticeContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: PracticeSearchField(
                  controller: _searchController,
                  hintText: loc.search_cases_hint,
                  onChanged: (value) =>
                      ref.read(lawyerCaseSearchProvider.notifier).state = value,
                ),
              ),

              // The status row is hidden when there is only "All" to choose
              // from, which is the case for an advocate whose matters are all
              // at the same stage.
              if (statuses.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: statuses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final status = statuses[index];
                      final label = status == 'All' ? loc.all : status;
                      return FilterChip(
                        label: Text(label, style: const TextStyle(fontSize: 11)),
                        selected: activeStatus == status,
                        showCheckmark: false,
                        onSelected: (_) => ref
                            .read(lawyerCaseStatusFilterProvider.notifier)
                            .state = status,
                      );
                    },
                  ),
                ),

              Expanded(
                child: casesState.when(
                  data: (cases) {
                    if (cases.isEmpty) {
                      final filtering =
                          query.trim().isNotEmpty || activeStatus != 'All';
                      return PracticeEmptyState(
                        icon: filtering
                            ? Icons.search_off
                            : Icons.folder_open_outlined,
                        title: filtering ? loc.no_cases_match : loc.no_cases_yet,
                        message: filtering
                            ? loc.no_cases_match_desc
                            : loc.no_cases_yet_desc,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () => ref
                          .read(casesProvider.notifier)
                          .fetchCases(silent: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: cases.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                loc.cases_count_label(cases.length),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }
                          return _CaseCard(caseItem: cases[index - 1]);
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => PracticeErrorState(
                    onRetry: () => ref.read(casesProvider.notifier).fetchCases(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    final selected = ref.read(lawyerCaseSortProvider) == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: selected ? AppColors.primaryGold : AppColors.mutedText,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.caseItem});

  final CaseModel caseItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final statusColor = practiceCaseStatusColor(caseItem.status);

    return PracticeCard(
      onTap: () => context.push(
        RouteNames.lawyerCaseDetailPath(caseItem.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  caseItem.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PracticeStatusPill(label: caseItem.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),

          _MetaRow(
            icon: Icons.person_outline,
            text: caseItem.clientName.isNotEmpty ? caseItem.clientName : '—',
          ),
          const SizedBox(height: 4),
          _MetaRow(icon: Icons.category_outlined, text: caseItem.category),

          if (caseItem.nextHearing != null) ...[
            const SizedBox(height: 4),
            _MetaRow(
              icon: Icons.gavel_outlined,
              // Gold rather than the body colour: an advocate scanning this
              // list is usually looking for the next date they have to be
              // somewhere.
              color: AppColors.primaryGold,
              text:
                  '${loc.next_hearing_label}: '
                  '${DateFormat('dd MMM yyyy').format(caseItem.nextHearing!)}',
            ),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              if (caseItem.documents.isNotEmpty) ...[
                _CountChip(
                  icon: Icons.description_outlined,
                  count: caseItem.documents.length,
                ),
                const SizedBox(width: 8),
              ],
              if (caseItem.hearings.isNotEmpty) ...[
                _CountChip(
                  icon: Icons.gavel_outlined,
                  count: caseItem.hearings.length,
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy').format(caseItem.createdAt),
                style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.secondaryText;
    return Row(
      children: [
        Icon(icon, size: 13, color: resolved),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: resolved),
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.mutedText),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
        ),
      ],
    );
  }
}
