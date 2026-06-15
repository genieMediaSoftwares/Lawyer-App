import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ---------------------------
/// MODEL
/// ---------------------------

class Lawyer {
  final String name;
  final String specialization;
  final int experience;
  final double rating;
  final int fee;
  final String location;

  Lawyer({
    required this.name,
    required this.specialization,
    required this.experience,
    required this.rating,
    required this.fee,
    required this.location,
  });
}

/// ---------------------------
/// PROVIDER
/// ---------------------------

final lawyerSearchProvider =
StateNotifierProvider<
    LawyerSearchNotifier,
    List<Lawyer>>(
      (ref) => LawyerSearchNotifier(),
);

class LawyerSearchNotifier
    extends StateNotifier<List<Lawyer>> {
  LawyerSearchNotifier() : super([]) {
    loadMore();
  }

  int page = 1;

  Future<void> loadMore() async {
    await Future.delayed(
      const Duration(seconds: 1),
    );

    final List<Lawyer> newLawyers =
    List.generate(
      10,
          (index) => Lawyer(
        name:
        "Advocate ${(page - 1) * 10 + index + 1}",
        specialization:
        [
          "Criminal",
          "Family",
          "Civil",
          "Corporate",
          "Property"
        ][index % 5],
        experience:
        3 + (index * 2),
        rating:
        4.0 + (index % 5) * 0.2,
        fee:
        1000 + (index * 500),
        location:
        [
          "Hyderabad",
          "Vizag",
          "Vijayawada",
          "Delhi",
          "Mumbai"
        ][index % 5],
      ),
    );

    state = [...state, ...newLawyers];
    page++;
  }
}

/// ---------------------------
/// SCREEN
/// ---------------------------

class LawyerSearchScreen
    extends ConsumerStatefulWidget {
  const LawyerSearchScreen({
    super.key,
  });

  @override
  ConsumerState<LawyerSearchScreen>
  createState() =>
      _LawyerSearchScreenState();
}

class _LawyerSearchScreenState
    extends ConsumerState<
        LawyerSearchScreen> {
  final ScrollController
  _scrollController =
  ScrollController();

  final TextEditingController
  searchController =
  TextEditingController();

  String selectedPractice = "All";

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position
          .pixels >=
          _scrollController
              .position
              .maxScrollExtent -
              200) {
        ref
            .read(
            lawyerSearchProvider
                .notifier)
            .loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lawyers =
    ref.watch(
        lawyerSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Find Lawyers"),
      ),
      body: Column(
        children: [
          /// SEARCH
          Padding(
            padding:
            const EdgeInsets.all(
                16),
            child: TextField(
              controller:
              searchController,
              decoration:
              InputDecoration(
                hintText:
                "Search Lawyer",
                prefixIcon:
                const Icon(
                  Icons.search,
                ),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
              ),
            ),
          ),

          /// FILTERS
          SizedBox(
            height: 50,
            child: ListView(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
              ),
              scrollDirection:
              Axis.horizontal,
              children: [
                filterChip(
                    "Practice Area"),
                filterChip(
                    "Experience"),
                filterChip("Fees"),
                filterChip(
                    "Rating"),
                filterChip(
                    "Location"),
              ],
            ),
          ),

          const SizedBox(
              height: 10),

          /// LAWYERS LIST
          Expanded(
            child: ListView.builder(
              controller:
              _scrollController,
              itemCount:
              lawyers.length +
                  1,
              itemBuilder:
                  (context, index) {
                if (index ==
                    lawyers.length) {
                  return const Padding(
                    padding:
                    EdgeInsets.all(
                        20),
                    child: Center(
                      child:
                      CircularProgressIndicator(),
                    ),
                  );
                }

                final lawyer =
                lawyers[index];

                return LawyerCard(
                  lawyer:
                  lawyer,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget filterChip(
      String title) {
    return Padding(
      padding:
      const EdgeInsets.only(
          right: 8),
      child: FilterChip(
        label: Text(title),
        selected: false,
        onSelected: (_) {},
      ),
    );
  }
}

/// ---------------------------
/// LAWYER CARD
/// ---------------------------

class LawyerCard
    extends StatelessWidget {
  final Lawyer lawyer;

  const LawyerCard({
    super.key,
    required this.lawyer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(
            14),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child:
                  Icon(Icons.person),
                ),
                const SizedBox(
                    width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        lawyer.name,
                        style:
                        const TextStyle(
                          fontSize:
                          16,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                      Text(
                        lawyer
                            .specialization,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration:
                  BoxDecoration(
                    color: Colors
                        .green
                        .withOpacity(
                        0.15),
                    borderRadius:
                    BorderRadius
                        .circular(
                        8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: Colors
                            .orange,
                      ),
                      const SizedBox(
                          width: 4),
                      Text(
                        lawyer.rating
                            .toString(),
                      ),
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(
                height: 12),

            Row(
              children: [
                const Icon(
                  Icons.work,
                  size: 18,
                ),
                const SizedBox(
                    width: 6),
                Text(
                  "${lawyer.experience} Years",
                ),
              ],
            ),

            const SizedBox(
                height: 8),

            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 18,
                ),
                const SizedBox(
                    width: 6),
                Text(
                  lawyer.location,
                ),
              ],
            ),

            const SizedBox(
                height: 8),

            Row(
              children: [
                const Icon(
                  Icons.currency_rupee,
                  size: 18,
                ),
                const SizedBox(
                    width: 6),
                Text(
                  "${lawyer.fee}/Consultation",
                ),
              ],
            ),

            const SizedBox(
                height: 14),

            SizedBox(
              width:
              double.infinity,
              child:
              ElevatedButton(
                onPressed: () {
                  // Navigate to lawyer profile
                },
                child: const Text(
                  "View Profile",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}