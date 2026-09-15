import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/case_model.dart';
import '../../../../models/hearing_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/hearing_provider.dart';
import '../../../../routes/route_names.dart';
import '../widgets/hearing_editor_sheet.dart';
import '../widgets/practice_widgets.dart';

/// Court hearings across every one of the advocate's matters, split into what
/// is still ahead and what has been dealt with.
///
/// This screen shows hearings and nothing else. Client consultations booked
/// through the app are appointments — they keep their own model, their own
/// Google Calendar sync, and their own place on the dashboard Calendar tab. The
/// note under the tab bar says so, because an advocate seeing a "Hearings"
/// screen would reasonably wonder where their consultations went.
class LawyerHearingsScreen extends ConsumerStatefulWidget {
  const LawyerHearingsScreen({super.key});

  @override
  ConsumerState<LawyerHearingsScreen> createState() =>
      _LawyerHearingsScreenState();
}

class _LawyerHearingsScreenState extends ConsumerState<LawyerHearingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final hearingsState = ref.watch(lawyerHearingsProvider);
    final upcoming = ref.watch(upcomingHearingsProvider);
    final past = ref.watch(pastHearingsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc.practice_hearings_title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: loc.upcoming), Tab(text: loc.past)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickCaseAndAddHearing,
        icon: const Icon(Icons.add, color: AppColors.onGold),
        label: Text(
          loc.add_hearing,
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
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.hearings_consultation_note,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: hearingsState.when(
                  data: (_) => TabBarView(
                    controller: _tabController,
                    children: [
                      _HearingList(
                        hearings: upcoming.valueOrNull ?? const [],
                        emptyTitle: loc.no_upcoming_hearings,
                        emptyMessage: loc.no_hearings_yet_desc,
                      ),
                      _HearingList(
                        hearings: past.valueOrNull ?? const [],
                        emptyTitle: loc.no_past_hearings,
                      ),
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => PracticeErrorState(
                    onRetry: () => ref.invalidate(lawyerHearingsProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Adding a hearing needs a case to attach it to, so the advocate picks the
  /// matter first. Only their own cases are offered — the server would reject
  /// anything else, and there is no reason to show it.
  Future<void> _pickCaseAndAddHearing() async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final cases = ref.read(lawyerCasesProvider).valueOrNull ?? const [];

    if (cases.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(loc.no_cases_yet_desc)));
      return;
    }

    final selected = await showModalBottomSheet<CaseModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CasePickerSheet(cases: cases),
    );

    if (selected == null || !mounted) return;

    final saved = await showHearingEditorSheet(
      context,
      caseId: selected.id,
      caseTitle: selected.title,
    );

    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(loc.hearing_saved)));
    }
  }
}

class _CasePickerSheet extends StatelessWidget {
  const _CasePickerSheet({required this.cases});

  final List<CaseModel> cases;

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
              loc.select_case,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: cases.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final caseItem = cases[index];
                  return PracticeCard(
                    onTap: () => Navigator.of(context).pop(caseItem),
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
                        const SizedBox(height: 3),
                        Text(
                          caseItem.clientName.isNotEmpty
                              ? '${caseItem.clientName} · ${caseItem.category}'
                              : caseItem.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedText,
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

class _HearingList extends ConsumerWidget {
  const _HearingList({
    required this.hearings,
    required this.emptyTitle,
    this.emptyMessage,
  });

  final List<HearingModel> hearings;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hearings.isEmpty) {
      return PracticeEmptyState(
        icon: Icons.gavel_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(lawyerHearingsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: hearings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _HearingCard(hearing: hearings[index]),
      ),
    );
  }
}

class _HearingCard extends StatelessWidget {
  const _HearingCard({required this.hearing});

  final HearingModel hearing;

  /// "Today" and "Tomorrow" read faster than a date when the hearing is
  /// imminent, which is exactly when it matters most.
  String _dateLabel(AppLocalizations loc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(hearing.date.year, hearing.date.month, hearing.date.day);
    final days = target.difference(today).inDays;

    if (days == 0) return loc.today;
    if (days == 1) return loc.tomorrow;
    return DateFormat('EEE, dd MMM yyyy').format(hearing.date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final statusColor = practiceHearingStatusColor(hearing.status);

    return PracticeCard(
      onTap: hearing.caseId.isEmpty
          ? null
          : () => context.push(RouteNames.lawyerCaseDetailPath(hearing.caseId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, size: 14, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hearing.timeSlot.isNotEmpty
                      ? '${_dateLabel(loc)} · ${hearing.timeSlot}'
                      : _dateLabel(loc),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              PracticeStatusPill(
                label: practiceHearingStatusLabel(loc, hearing.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hearing.caseTitle.isNotEmpty ? hearing.caseTitle : '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (hearing.purpose.isNotEmpty)
            _Line(icon: Icons.subject, text: hearing.purpose),
          if (hearing.court.isNotEmpty)
            _Line(icon: Icons.account_balance_outlined, text: hearing.court),
          if (hearing.clientName.isNotEmpty)
            _Line(icon: Icons.person_outline, text: hearing.clientName),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppColors.mutedText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
