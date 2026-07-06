import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class GetMatchedScreen extends ConsumerStatefulWidget {
  const GetMatchedScreen({super.key});

  @override
  ConsumerState<GetMatchedScreen> createState() => _GetMatchedScreenState();
}

class _GetMatchedScreenState extends ConsumerState<GetMatchedScreen> {
  String _selectedSpecialization = "All";
  int _minExperience = 0;
  int _maxFee = 5000;
  double _minRating = 0.0;
  String _selectedLanguage = "All";
  bool _isLoading = false;
  List<LawyerModel> _matchedLawyers = [];

  final List<String> _specializations = [
    "All",
    "Criminal Law",
    "Divorce & Family",
    "Property Disputes",
    "Civil Cases",
    "Cyber Crime",
    "GST & Taxation",
    "Labour Law"
  ];

  final List<String> _languages = ["All", "English", "Hindi", "Telugu", "Kannada"];

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> queryParams = {};
      if (_selectedSpecialization != "All") {
        queryParams['specialization'] = _selectedSpecialization;
      }
      if (_minExperience > 0) {
        queryParams['experience'] = _minExperience;
      }
      if (_maxFee < 5000) {
        queryParams['maxFee'] = _maxFee;
      }
      if (_minRating > 0.0) {
        queryParams['rating'] = _minRating;
      }
      if (_selectedLanguage != "All") {
        queryParams['language'] = _selectedLanguage;
      }

      final response = await DioClient.dio.get("/lawyers/match", queryParameters: queryParams);
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        setState(() {
          _matchedLawyers = list.map((item) => LawyerModel.fromJson(item)).toList();
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Lawyer Matchmaker", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: Column(
        children: [
          // Filter Panel Header
          _buildFilterPanel(),
          
          // Lawyer List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _matchedLawyers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchMatches,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _matchedLawyers.length,
                          itemBuilder: (context, index) {
                            final lawyer = _matchedLawyers[index];
                            return _buildLawyerCard(lawyer);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ExpansionTile(
        title: Row(
          children: const [
            Icon(Icons.tune, color: AppColors.navyBlue, size: 20),
            SizedBox(width: 8),
            Text("Refine Match Criteria", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Specialization
                const Text("Specialization", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedSpecialization,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _specializations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedSpecialization = val ?? "All");
                    _fetchMatches();
                  },
                ),
                const SizedBox(height: 12),

                // Experience Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Min Experience: $_minExperience Years", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _minExperience.toDouble(),
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: AppColors.navyBlue,
                  label: "$_minExperience Years",
                  onChanged: (val) {
                    setState(() => _minExperience = val.toInt());
                  },
                  onChangeEnd: (_) => _fetchMatches(),
                ),

                // Consultation Fee Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Max Consultation Fee: ₹$_maxFee", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _maxFee.toDouble(),
                  min: 500,
                  max: 5000,
                  divisions: 9,
                  activeColor: AppColors.navyBlue,
                  label: "₹$_maxFee",
                  onChanged: (val) {
                    setState(() => _maxFee = val.toInt());
                  },
                  onChangeEnd: (_) => _fetchMatches(),
                ),

                // Languages
                const Text("Preferred Language", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedLanguage = val ?? "All");
                    _fetchMatches();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLawyerCard(LawyerModel lawyer) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: lawyer.profileImage.isNotEmpty ? NetworkImage(lawyer.profileImage) : null,
                  child: lawyer.profileImage.isEmpty ? const Icon(Icons.person, size: 32) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            lawyer.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Colors.blue, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(lawyer.specialization, style: const TextStyle(color: AppColors.grey500, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text("${lawyer.rating} (${lawyer.totalReviews} reviews)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Consultation Fee", style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text("₹${lawyer.consultationFee}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Experience", style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text("${lawyer.experience} Years+", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push('/lawyer-profile/${lawyer.userId}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text("Book Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 72, color: AppColors.grey300),
            const SizedBox(height: 16),
            const Text("No Matched Lawyers Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue)),
            const SizedBox(height: 8),
            const Text("Try relaxing your filters to view more matching legal professionals.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey400)),
          ],
        ),
      ),
    );
  }
}
