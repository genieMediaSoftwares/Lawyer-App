import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../core/widgets/app_drawer.dart';

class GetMatchedScreen extends ConsumerStatefulWidget {
  const GetMatchedScreen({super.key});

  @override
  ConsumerState<GetMatchedScreen> createState() => _GetMatchedScreenState();
}

class _GetMatchedScreenState extends ConsumerState<GetMatchedScreen> {
  // Filter state
  String _selectedSpecialization = "All";
  int _minExperience = 0;
  int _maxFee = 5000;
  String _selectedLanguage = "All";

  // Dynamic lists built from real data
  List<String> _specializations = ["All"];
  List<String> _languages = ["All"];

  // Results state
  bool _isLoading = true;
  String? _errorMessage;
  List<LawyerModel> _matchedLawyers = [];

  // Expansion panel
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadAllAndBuildFilters();
  }

  /// Load ALL lawyers first to build dynamic filters, then show them all.
  Future<void> _loadAllAndBuildFilters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await DioClient.dio.get("/lawyers");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final allLawyers =
            list.map((item) => LawyerModel.fromJson(item)).toList();

        // Build dynamic specialization list
        final specSet = <String>{};
        final langSet = <String>{};
        for (final l in allLawyers) {
          if (l.specialization.trim().isNotEmpty) {
            specSet.add(l.specialization.trim());
          }
          for (final lang in l.languages) {
            if (lang.trim().isNotEmpty) langSet.add(lang.trim());
          }
        }

        setState(() {
          _specializations = ["All", ...specSet.toList()..sort()];
          _languages = ["All", ...langSet.toList()..sort()];
          _matchedLawyers = allLawyers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load lawyers.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception:", "").trim();
        _isLoading = false;
      });
    }
  }

  /// After filters change, call /lawyers/match to get filtered results.
  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final Map<String, dynamic> queryParams = {};
      if (_selectedSpecialization != "All") {
        queryParams['specialization'] = _selectedSpecialization;
      }
      if (_minExperience > 0) {
        queryParams['experience'] = _minExperience;
      }
      queryParams['maxFee'] = _maxFee;
      if (_selectedLanguage != "All") {
        queryParams['language'] = _selectedLanguage;
      }

      final response = await DioClient.dio
          .get("/lawyers/match", queryParameters: queryParams);
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        setState(() {
          _matchedLawyers =
              list.map((item) => LawyerModel.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _matchedLawyers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll("Exception:", "").trim();
        _isLoading = false;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedSpecialization = "All";
      _minExperience = 0;
      _maxFee = 5000;
      _selectedLanguage = "All";
    });
    _loadAllAndBuildFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          "Lawyer Matchmaker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Reload all",
            onPressed: _loadAllAndBuildFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Panel ───────────────────────────────────────────
          _FilterPanel(
            specializations: _specializations,
            languages: _languages,
            selectedSpecialization: _selectedSpecialization,
            minExperience: _minExperience,
            maxFee: _maxFee,
            selectedLanguage: _selectedLanguage,
            isExpanded: _filtersExpanded,
            onToggleExpand: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            onSpecializationChanged: (val) {
              setState(() => _selectedSpecialization = val);
              _fetchMatches();
            },
            onExperienceChanged: (val) =>
                setState(() => _minExperience = val),
            onExperienceChangeEnd: (_) => _fetchMatches(),
            onFeeChanged: (val) => setState(() => _maxFee = val),
            onFeeChangeEnd: (_) => _fetchMatches(),
            onLanguageChanged: (val) {
              setState(() => _selectedLanguage = val);
              _fetchMatches();
            },
            onReset: _resetFilters,
          ),

          // ── Results count strip ────────────────────────────────────
          if (!_isLoading && _errorMessage == null)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.people_outline,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    _matchedLawyers.isEmpty
                        ? "No lawyers matched"
                        : "${_matchedLawyers.length} lawyer${_matchedLawyers.length == 1 ? '' : 's'} matched",
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedSpecialization != "All" ||
                      _minExperience > 0 ||
                      _maxFee < 5000 ||
                      _selectedLanguage != "All")
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Text(
                        "Clear filters",
                        style: TextStyle(
                          color: gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Main body ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: gold),
                        const SizedBox(height: 16),
                        Text(
                          "Matching lawyers for you...",
                          style: TextStyle(
                              color: theme.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? _ErrorState(
                        message: _errorMessage!,
                        onRetry: _loadAllAndBuildFilters,
                      )
                    : _matchedLawyers.isEmpty
                        ? _EmptyState(onClearFilters: _resetFilters)
                        : RefreshIndicator(
                            color: gold,
                            onRefresh: _fetchMatches,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _matchedLawyers.length,
                              itemBuilder: (context, index) {
                                return _MatchedLawyerCard(
                                  lawyer: _matchedLawyers[index],
                                  onBook: () => context.push(
                                      '/lawyer-profile/${_matchedLawyers[index].userId}'),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Panel Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final List<String> specializations;
  final List<String> languages;
  final String selectedSpecialization;
  final int minExperience;
  final int maxFee;
  final String selectedLanguage;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<String> onSpecializationChanged;
  final ValueChanged<int> onExperienceChanged;
  final ValueChanged<int> onExperienceChangeEnd;
  final ValueChanged<int> onFeeChanged;
  final ValueChanged<int> onFeeChangeEnd;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onReset;

  const _FilterPanel({
    required this.specializations,
    required this.languages,
    required this.selectedSpecialization,
    required this.minExperience,
    required this.maxFee,
    required this.selectedLanguage,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onSpecializationChanged,
    required this.onExperienceChanged,
    required this.onExperienceChangeEnd,
    required this.onFeeChanged,
    required this.onFeeChangeEnd,
    required this.onLanguageChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.tune, color: gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Refine Match Criteria",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: gold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: gold,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Specialization label
                  Text(
                    "Specialization",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dynamic specialization chips (horizontal scroll)
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: specializations.length,
                      itemBuilder: (context, i) {
                        final spec = specializations[i];
                        final isSelected = selectedSpecialization == spec;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(spec),
                            selected: isSelected,
                            selectedColor: gold,
                            backgroundColor: theme.colorScheme.surface,
                            side: BorderSide(
                              color: isSelected
                                  ? gold
                                  : theme.colorScheme.outline,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : theme.textTheme.bodySmall?.color,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) onSpecializationChanged(spec);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Experience slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Min Experience",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold.withOpacity(0.35)),
                        ),
                        child: Text(
                          "$minExperience yrs",
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: minExperience.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    activeColor: gold,
                    label: "$minExperience Years",
                    onChanged: (val) => onExperienceChanged(val.toInt()),
                    onChangeEnd: (val) =>
                        onExperienceChangeEnd(val.toInt()),
                  ),

                  // Fee slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Max Consultation Fee",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gold.withOpacity(0.35)),
                        ),
                        child: Text(
                          "₹$maxFee",
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: maxFee.toDouble(),
                    min: 500,
                    max: 5000,
                    divisions: 9,
                    activeColor: gold,
                    label: "₹$maxFee",
                    onChanged: (val) => onFeeChanged(val.toInt()),
                    onChangeEnd: (val) => onFeeChangeEnd(val.toInt()),
                  ),

                  // Language label
                  Text(
                    "Preferred Language",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dynamic language chips
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: languages.length,
                      itemBuilder: (context, i) {
                        final lang = languages[i];
                        final isSelected = selectedLanguage == lang;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(lang),
                            selected: isSelected,
                            selectedColor: gold,
                            backgroundColor: theme.colorScheme.surface,
                            side: BorderSide(
                              color: isSelected
                                  ? gold
                                  : theme.colorScheme.outline,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : theme.textTheme.bodySmall?.color,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) onLanguageChanged(lang);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],

          Divider(height: 1, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Matched Lawyer Card
// ─────────────────────────────────────────────────────────────────────────────

class _MatchedLawyerCard extends StatelessWidget {
  final LawyerModel lawyer;
  final VoidCallback onBook;

  const _MatchedLawyerCard({required this.lawyer, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;
    final titleColor = theme.textTheme.titleMedium?.color;
    final subtitleColor = theme.textTheme.bodySmall?.color;

    final initials = lawyer.fullName.trim().isNotEmpty
        ? lawyer.fullName
            .trim()
            .split(" ")
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
        : "A";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onBook,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [gold.withOpacity(0.6), gold],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color: gold.withOpacity(0.5), width: 2),
                      ),
                      child: lawyer.profileImage.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                lawyer.profileImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _InitialsWidget(initials: initials),
                              ),
                            )
                          : _InitialsWidget(initials: initials),
                    ),
                    const SizedBox(width: 12),

                    // Name + Specialization + Location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Adv. ${lawyer.fullName}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: titleColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.verified,
                                  color: gold, size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: gold.withOpacity(0.35)),
                            ),
                            child: Text(
                              lawyer.specialization.isNotEmpty
                                  ? lawyer.specialization
                                  : "General Practice",
                              style: TextStyle(
                                color: gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (lawyer.location.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    color: gold, size: 13),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    lawyer.location,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: subtitleColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Rating
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: gold.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: gold, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            lawyer.rating > 0
                                ? lawyer.rating.toStringAsFixed(1)
                                : "New",
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Languages row ───────────────────────────────────
                if (lawyer.languages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: lawyer.languages.take(4).map((lang) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                              fontSize: 10, color: subtitleColor),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // ── Divider ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: borderColor),
                ),

                // ── Stats ───────────────────────────────────────────
                Row(
                  children: [
                    _StatBox(
                      icon: Icons.work_history_outlined,
                      value: "${lawyer.experience}+ yrs",
                      label: "Experience",
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      icon: Icons.currency_rupee_rounded,
                      value: "₹${lawyer.consultationFee}",
                      label: "Consultation",
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      icon: Icons.rate_review_outlined,
                      value: "${lawyer.totalReviews}",
                      label: "Reviews",
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Book button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onBook,
                    icon: const Icon(Icons.calendar_month_outlined,
                        size: 18),
                    label: const Text(
                      "Book Consultation",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InitialsWidget extends StatelessWidget {
  final String initials;
  const _InitialsWidget({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: gold),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClearFilters;
  const _EmptyState({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 72, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              "No Lawyers Matched",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try relaxing your filters to view\nmore legal professionals.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text("Reset Filters"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              "Connection Error",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
