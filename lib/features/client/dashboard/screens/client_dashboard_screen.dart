import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardTabProvider =
StateProvider<int>((ref) => 0);

class ClientDashboardScreen
    extends ConsumerWidget {
  const ClientDashboardScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final selectedTab =
    ref.watch(dashboardTabProvider);

    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              /// Greeting Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Icon(
                      Icons.person,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          "Good Morning 👋",
                          style: theme
                              .textTheme
                              .bodyMedium,
                        ),
                        Text(
                          "Sujith",
                          style: theme
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// Search Lawyer
              TextField(
                decoration: InputDecoration(
                  hintText:
                  "Search Lawyer...",
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// Categories
              Text(
                "Legal Categories",
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection:
                  Axis.horizontal,
                  children: const [
                    CategoryCard(
                      title: "Civil",
                      icon:
                      Icons.account_balance,
                    ),
                    CategoryCard(
                      title: "Criminal",
                      icon:
                      Icons.gavel_rounded,
                    ),
                    CategoryCard(
                      title: "Family",
                      icon:
                      Icons.family_restroom,
                    ),
                    CategoryCard(
                      title: "Corporate",
                      icon: Icons.business,
                    ),
                    CategoryCard(
                      title: "Property",
                      icon: Icons.home,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// Top Lawyers
              Text(
                "Top Rated Lawyers",
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const LawyerCard(
                name: "Adv. Rahul Sharma",
                specialization:
                "Criminal Lawyer",
                rating: 4.9,
              ),

              const LawyerCard(
                name: "Adv. Priya Reddy",
                specialization:
                "Family Lawyer",
                rating: 4.8,
              ),

              const SizedBox(height: 24),

              /// Upcoming Appointments
              Text(
                "Upcoming Appointments",
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const AppointmentCard(
                lawyerName:
                "Adv. Rahul Sharma",
                date:
                "20 Jun 2026 • 10:00 AM",
              ),

              const SizedBox(height: 24),

              /// Recent Consultations
              Text(
                "Recent Consultations",
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const ConsultationCard(
                title:
                "Property Dispute Case",
              ),

              const ConsultationCard(
                title:
                "Family Settlement",
              ),

              SizedBox(
                height:
                size.height * 0.08,
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar:
      NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected:
            (value) {
          ref
              .read(
              dashboardTabProvider
                  .notifier)
              .state = value;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: "Lawyers",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: "Chat",
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

/// CATEGORY CARD

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 95,
      margin:
      const EdgeInsets.only(right: 12),
      child: Card(
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}

/// LAWYER CARD

class LawyerCard extends StatelessWidget {
  final String name;
  final String specialization;
  final double rating;

  const LawyerCard({
    super.key,
    required this.name,
    required this.specialization,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
      const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(name),
        subtitle:
        Text(specialization),
        trailing: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            Text(
              rating.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

/// APPOINTMENT CARD

class AppointmentCard
    extends StatelessWidget {
  final String lawyerName;
  final String date;

  const AppointmentCard({
    super.key,
    required this.lawyerName,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.calendar_month,
        ),
        title: Text(lawyerName),
        subtitle: Text(date),
      ),
    );
  }
}

/// CONSULTATION CARD

class ConsultationCard
    extends StatelessWidget {
  final String title;

  const ConsultationCard({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading:
        const Icon(Icons.folder),
        title: Text(title),
      ),
    );
  }
}