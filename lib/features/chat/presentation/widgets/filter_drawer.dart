import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/lawyer_provider.dart';

// List of common languages to choose from
const List<String> kAvailableLanguages = [
  'English',
  'Hindi',
  'Telugu',
  'Spanish',
  'French',
  'German',
  'Tamil',
  'Kannada'
];

typedef voidFunction = void Function(AdvocateFilters);

class FilterContent extends StatefulWidget {
  final AdvocateFilters initialFilters;
  final List<String> specializations;
  final List<String> locations;
  final voidFunction onApply;
  final VoidCallback onReset;
  final ScrollController? scrollController;

  const FilterContent({
    super.key,
    required this.initialFilters,
    required this.specializations,
    required this.locations,
    required this.onApply,
    required this.onReset,
    this.scrollController,
  });

  @override
  State<FilterContent> createState() => _FilterContentState();
}

class _FilterContentState extends State<FilterContent> {
  late String _specialization;
  late String _location;
  late String _experience;
  late String _rating;
  late bool _verifiedOnly;
  late bool _availableNow;
  late RangeValues _feeRange;
  late List<String> _selectedLanguages;

  @override
  void initState() {
    super.initState();
    _specialization = widget.initialFilters.specialization;
    _location = widget.initialFilters.location;
    _experience = widget.initialFilters.experience;
    _rating = widget.initialFilters.minRating == null
        ? 'All Ratings'
        : '${widget.initialFilters.minRating!.toStringAsFixed(1)}★+';
    _verifiedOnly = widget.initialFilters.verifiedOnly;
    _availableNow = widget.initialFilters.availableNow;
    _feeRange = RangeValues(
      widget.initialFilters.minFee ?? 0,
      widget.initialFilters.maxFee ?? 5000,
    );
    _selectedLanguages = List.from(widget.initialFilters.languages);
  }

  void _reset() {
    setState(() {
      _specialization = 'All Practice Areas';
      _location = 'All Locations';
      _experience = 'All Experience';
      _rating = 'All Ratings';
      _verifiedOnly = false;
      _availableNow = false;
      _feeRange = const RangeValues(0, 5000);
      _selectedLanguages = [];
    });
    widget.onReset();
  }

  void _apply() {
    double? minRating;
    if (_rating != 'All Ratings') {
      minRating = double.tryParse(_rating.replaceFirst('★+', ''));
    }

    final newFilters = widget.initialFilters.copyWith(
      specialization: _specialization,
      location: _location,
      experience: _experience,
      minRating: minRating,
      minFee: _feeRange.start,
      maxFee: _feeRange.end,
      languages: _selectedLanguages,
      verifiedOnly: _verifiedOnly,
      availableNow: _availableNow,
    );
    widget.onApply(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Sanitize & build Practice Area list
    final specItems = ['All Practice Areas', ...widget.specializations]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (!specItems.contains(_specialization)) {
      _specialization = specItems.isNotEmpty ? specItems.first : 'All Practice Areas';
    }

    // 2. Sanitize & build Location list
    final locItems = ['All Locations', ...widget.locations]
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    if (!locItems.contains(_location)) {
      _location = locItems.isNotEmpty ? locItems.first : 'All Locations';
    }

    // 3. Sanitize & build Experience list
    final expItems = ['All Experience', '0-2', '3-5', '5-10', '10+']
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (!expItems.contains(_experience)) {
      _experience = expItems.isNotEmpty ? expItems.first : 'All Experience';
    }

    // 4. Sanitize & build Rating list
    final ratingItems = ['All Ratings', '4.0★+', '3.0★+', '2.0★+']
        .toSet()
        .toList();
    if (!ratingItems.contains(_rating)) {
      _rating = ratingItems.isNotEmpty ? ratingItems.first : 'All Ratings';
    }

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Scrollable fields list
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Practice Area ────────────────────────────────
                  _buildLabel('Practice Area'),
                  _buildDropdown<String>(
                    value: _specialization,
                    items: specItems.isEmpty ? null : specItems.map((spec) {
                      return DropdownMenuItem(
                        value: spec,
                        child: Text(spec, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _specialization = val);
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Location ─────────────────────────────────────
                  _buildLabel('Location'),
                  _buildDropdown<String>(
                    value: _location,
                    items: locItems.isEmpty ? null : locItems.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(loc, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _location = val);
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Experience ───────────────────────────────────
                  _buildLabel('Experience'),
                  _buildDropdown<String>(
                    value: _experience,
                    items: expItems.isEmpty ? null : expItems.map((exp) {
                      final label = exp == 'All Experience' || exp == '10+' ? exp : '$exp Years';
                      return DropdownMenuItem(
                        value: exp,
                        child: Text(label, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _experience = val);
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Rating ───────────────────────────────────────
                  _buildLabel('Rating'),
                  _buildDropdown<String>(
                    value: _rating,
                    items: ratingItems.isEmpty ? null : ratingItems.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(r, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _rating = val);
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Consultation Fee Range ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Consultation Fee'),
                      Text(
                        '₹${_feeRange.start.round()} - ₹${_feeRange.end.round()}',
                        style: const TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RangeSlider(
                    values: _feeRange,
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    activeColor: AppColors.primaryGold,
                    inactiveColor: const Color(0xFF2A2A2A),
                    onChanged: (values) {
                      setState(() => _feeRange = values);
                    },
                  ),

                  const SizedBox(height: 14),

                  // ── Languages Chips ──────────────────────────────
                  _buildLabel('Languages'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kAvailableLanguages.map((lang) {
                      final isSelected = _selectedLanguages.contains(lang);
                      return ChoiceChip(
                        label: Text(lang),
                        selected: isSelected,
                        selectedColor: AppColors.primaryGold,
                        backgroundColor: const Color(0xFF161616),
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryGold : const Color(0xFF2A2A2A),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : const Color(0xFF9A9A9A),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedLanguages.add(lang);
                            } else {
                              _selectedLanguages.remove(lang);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── Switch Toggles ───────────────────────────────
                  _buildSwitchRow(
                    label: 'Available for Consultation',
                    value: _availableNow,
                    onChanged: (val) => setState(() => _availableNow = val),
                  ),
                  const SizedBox(height: 10),
                  _buildSwitchRow(
                    label: 'Verified Advocates Only',
                    value: _verifiedOnly,
                    onChanged: (val) => setState(() => _verifiedOnly = val),
                  ),
                ],
              ),
            ),
          ),

          // Pinned bottom actions bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Color(0xFF1A1A1A), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _reset,
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9A9A9A),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>>? items,
    required ValueChanged<T?> onChanged,
  }) {
    final finalItems = items == null || items.isEmpty ? <DropdownMenuItem<T>>[] : items;
    final T? finalValue = (items == null || items.isEmpty || value == null) ? null : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: finalValue,
          items: finalItems.isEmpty ? null : finalItems,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF161616),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9A9A9A)),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.black,
          activeTrackColor: AppColors.primaryGold,
          inactiveThumbColor: const Color(0xFF707070),
          inactiveTrackColor: const Color(0xFF161616),
        ),
      ],
    );
  }
}

// ── Right side sliding Drawer for Tablet/Desktop ───────────────────────────────────

class FilterDrawer extends ConsumerWidget {
  const FilterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(advocateFiltersProvider);
    final filterOptions = ref.watch(filterOptionsProvider);

    return Drawer(
      backgroundColor: Colors.black,
      width: 380,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Advocates',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
            // Drawer Body / Content
            Expanded(
              child: filterOptions.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                error: (err, _) => Center(child: Text('Error loading filters: $err', style: const TextStyle(color: Colors.white))),
                data: (data) => FilterContent(
                  initialFilters: filters,
                  specializations: data['specializations']!,
                  locations: data['locations']!,
                  onApply: (newFilters) {
                    ref.read(advocateFiltersProvider.notifier).state = newFilters;
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  onReset: () {
                    ref.read(advocateFiltersProvider.notifier).state = AdvocateFilters(search: filters.search);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet for Mobile ────────────────────────────────────────────────────────

class FilterBottomSheet extends ConsumerWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(advocateFiltersProvider);
    final filterOptions = ref.watch(filterOptionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: Colors.black,
            child: SafeArea(
              child: Column(
                children: [
                  // Bottom Sheet handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Advocates',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: filterOptions.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryGold),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading filters: $err',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      data: (data) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: FilterContent(
                          initialFilters: filters,
                          specializations: data['specializations']!,
                          locations: data['locations']!,
                          scrollController: scrollController,
                          onApply: (newFilters) {
                            ref.read(advocateFiltersProvider.notifier).state = newFilters;
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          onReset: () {
                            ref.read(advocateFiltersProvider.notifier).state =
                                AdvocateFilters(search: filters.search);
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
