import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';

class LawyerProfileScreen extends StatelessWidget {
  const LawyerProfileScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lawyer Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            /// HEADER
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 55,
                      backgroundImage:
                          NetworkImage(
                        "https://i.pravatar.cc/300",
                      ),
                    ),

                    const SizedBox(
                        height: 16),

                    Text(
                      "Adv. Rahul Sharma",
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.blue
                            .withOpacity(
                                0.1),
                        borderRadius:
                            BorderRadius
                                .circular(
                                    20),
                      ),
                      child: const Text(
                        "Criminal Lawyer",
                      ),
                    ),

                    const SizedBox(
                        height: 16),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceEvenly,
                      children: const [
                        ProfileStat(
                          title:
                              "Experience",
                          value:
                              "12 Years",
                        ),
                        ProfileStat(
                          title:
                              "Cases",
                          value: "320+",
                        ),
                        ProfileStat(
                          title:
                              "Rating",
                          value: "4.9",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// SPECIALIZATION
            sectionTitle(
              context,
              "Specialization",
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: const [
                Chip(
                  label:
                      Text("Criminal Law"),
                ),
                Chip(
                  label:
                      Text("Cyber Crime"),
                ),
                Chip(
                  label:
                      Text("Civil Cases"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// LANGUAGES
            sectionTitle(
              context,
              "Languages",
            ),

            const SizedBox(height: 10),

            const Text(
              "English, Hindi, Telugu",
            ),

            const SizedBox(height: 20),

            /// ABOUT
            sectionTitle(
              context,
              "About",
            ),

            const SizedBox(height: 10),

            const Text(
              "Experienced advocate with more than 12 years of legal practice in criminal, civil, and cyber law matters. Successfully handled over 300 cases across multiple courts.",
            ),

            const SizedBox(height: 20),

            /// REVIEWS
            sectionTitle(
              context,
              "Reviews",
            ),

            const SizedBox(height: 10),

            const ReviewCard(
              name: "Suresh",
              review:
                  "Excellent guidance and quick resolution.",
              rating: 5,
            ),

            const ReviewCard(
              name: "Anjali",
              review:
                  "Very professional and knowledgeable.",
              rating: 4,
            ),

            const SizedBox(height: 20),

            /// AVAILABILITY
            sectionTitle(
              context,
              "Availability",
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CalendarDatePicker(
                      initialDate:
                          DateTime.now(),
                      firstDate:
                          DateTime.now(),
                      lastDate:
                          DateTime.now()
                              .add(
                        const Duration(
                          days: 90,
                        ),
                      ),
                      onDateChanged:
                          (date) {},
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// BOOK APPOINTMENT
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  context.push(
                    RouteNames
                        .appointmentBooking,
                  );
                },
                child: const Text(
                  "Book Appointment",
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(
    BuildContext context,
    String title,
  ) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
    );
  }
}

/// -------------------------
/// PROFILE STATS
/// -------------------------

class ProfileStat extends StatelessWidget {
  final String title;
  final String value;

  const ProfileStat({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(title),
      ],
    );
  }
}

/// -------------------------
/// REVIEW CARD
/// -------------------------

class ReviewCard extends StatelessWidget {
  final String name;
  final String review;
  final int rating;

  const ReviewCard({
    super.key,
    required this.name,
    required this.review,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading:
            const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(name),
        subtitle: Text(review),
        trailing: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: List.generate(
            rating,
            (index) => const Icon(
              Icons.star,
              color: Colors.orange,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}