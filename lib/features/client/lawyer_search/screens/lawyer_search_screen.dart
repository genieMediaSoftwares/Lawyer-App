import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../core/widgets/app_drawer.dart';

class LawyerSearchScreen extends ConsumerStatefulWidget {
  const LawyerSearchScreen({super.key});

  @override
  ConsumerState<LawyerSearchScreen> createState() => _LawyerSearchScreenState();
}

class _LawyerSearchScreenState extends ConsumerState<LawyerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialization = "All";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Build the specialization list dynamically from actual lawyer data
  List<String> _buildSpecializations(List<LawyerModel> lawyers) {
    final Set<String> specs = {};
    for (final l in lawyers) {
      if (l.specialization.trim().isNotEmpty) {
        specs.add(l.specialization.trim());
      }
    }
    final sorted = specs.toList()..sort();
    return ["All", ...sorted];
  }

  @override
  Widget build(BuildContext context) {
    final lawyersState = ref.watch(lawyersProvider);
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          "Find Advocates",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          lawyersState.maybeWhen(
            data: (_) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Refresh list",
              onPressed: () => ref.invalidate(lawyersProvider),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: lawyersState.when(
        // ── Loading ──────────────────────────────────────────────────────
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: gold),
              const SizedBox(height: 16),
              Text(
                "Loading advocates...",
                style: TextStyle(color: theme.textTheme.bodySmall?.color),
              ),
            ],
          ),
        ),
        // ── Error ────────────────────────────────────────────────────────
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  "Failed to load advocates",
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
                  onPressed: () => ref.invalidate(lawyersProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Try Again"),
                ),
              ],
            ),
          ),
        ),
        // ── Data ─────────────────────────────────────────────────────────
        data: (lawyers) {
          final specializations = _buildSpecializations(lawyers);

          // Keep filter valid after refresh
          if (!specializations.contains(_selectedSpecialization)) {
            _selectedSpecialization = "All";
          }

          final query = _searchController.text.toLowerCase().trim();
          final filtered = lawyers.where((lawyer) {
            final matchesSearch = query.isEmpty ||
                lawyer.fullName.toLowerCase().contains(query) ||
                lawyer.specialization.toLowerCase().contains(query) ||
                lawyer.location.toLowerCase().contains(query);
            final matchesSpec = _selectedSpecialization == "All" ||
                lawyer.specialization
                    .toLowerCase()
                    .contains(_selectedSpecialization.toLowerCase());
            return matchesSearch && matchesSpec;
          }).toList();

          return Column(
            children: [
              // ── Search + Filter Panel ────────────────────────────────
              Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search by name, specialization or city...",
                        prefixIcon: Icon(Icons.search, color: gold),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: specializations.length,
                        itemBuilder: (context, index) {
                          final spec = specializations[index];
                          final isSelected = _selectedSpecialization == spec;
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
                                if (val) {
                                  setState(
                                      () => _selectedSpecialization = spec);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── Result count ─────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 14, color: theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 4),
                    Text(
                      filtered.isEmpty
                          ? "No advocates found"
                          : "${filtered.length} advocate${filtered.length == 1 ? '' : 's'} found",
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Lawyer List ──────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined,
                                  size: 72,
                                  color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                "No Advocates Found",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Try adjusting your search or\nselect a different category.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(
                                      () => _selectedSpecialization = "All");
                                },
                                icon: const Icon(Icons.filter_alt_off),
                                label: const Text("Clear Filters"),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: gold,
                        onRefresh: () async =>
                            ref.invalidate(lawyersProvider),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _LawyerCard(
                              lawyer: filtered[index],
                              onViewProfile: () => context.push(
                                  '/lawyer-profile/${filtered[index].userId}'),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Lawyer Card
// ─────────────────────────────────────────────────────────────────────────────

class _LawyerCard extends StatelessWidget {
  final LawyerModel lawyer;
  final VoidCallback onViewProfile;

  const _LawyerCard({required this.lawyer, required this.onViewProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;
    final titleColor = theme.textTheme.titleMedium?.color;
    final subtitleColor = theme.textTheme.bodySmall?.color;

    // Avatar initials fallback
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
          onTap: onViewProfile,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + name + rating ───────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gold-rimmed avatar
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            gold.withOpacity(0.7),
                            gold,
                          ],
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
                                    _InitialsWidget(
                                        initials: initials),
                              ),
                            )
                          : _InitialsWidget(initials: initials),
                    ),
                    const SizedBox(width: 12),
                    // Name + specialization + location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Adv. ${lawyer.fullName}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: titleColor,
                            ),
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
                    // Rating badge
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

                // ── Divider ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: borderColor),
                ),

                // ── Stats row ────────────────────────────────────────
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

                // ── Book CTA ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onViewProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "View Profile & Book",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
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

// ── Avatar initials fallback ─────────────────────────────────────────────────

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

// ── Stats box ────────────────────────────────────────────────────────────────

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