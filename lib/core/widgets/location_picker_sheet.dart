import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../constants/app_colors.dart';

class LocationPickerSheet extends StatefulWidget {
  final String? initialLocation;
  const LocationPickerSheet({super.key, this.initialLocation});

  static Future<String?> show(BuildContext context, {String? initialLocation}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: LocationPickerSheet(initialLocation: initialLocation),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();
  Timer? _debounceTimer;
  CancelToken? _cancelToken;

  List<Map<String, String>> _searchResults = [];
  bool _isLoading = false;

  final List<String> _popularCities = [
    "Hyderabad, Telangana",
    "Mumbai, Maharashtra",
    "Delhi",
    "Bangalore, Karnataka",
    "Chennai, Tamil Nadu",
    "Kolkata, West Bengal",
    "Pune, Maharashtra",
    "Ahmedabad, Gujarat",
    "Jaipur, Rajasthan",
    "Lucknow, Uttar Pradesh",
  ];

  final List<Map<String, String>> _localLocations = [
    {"city": "Gachibowli", "district": "Rangareddy", "state": "Telangana", "pincode": "500032"},
    {"city": "Madhapur", "district": "Rangareddy", "state": "Telangana", "pincode": "500081"},
    {"city": "Banjara Hills", "district": "Hyderabad", "state": "Telangana", "pincode": "500034"},
    {"city": "Jubilee Hills", "district": "Hyderabad", "state": "Telangana", "pincode": "500033"},
    {"city": "Secunderabad", "district": "Hyderabad", "state": "Telangana", "pincode": "500003"},
    {"city": "Connaught Place", "district": "New Delhi", "state": "Delhi", "pincode": "110001"},
    {"city": "Dwarka", "district": "South West Delhi", "state": "Delhi", "pincode": "110075"},
    {"city": "Saket", "district": "South Delhi", "state": "Delhi", "pincode": "110017"},
    {"city": "Andheri West", "district": "Mumbai Suburban", "state": "Maharashtra", "pincode": "400053"},
    {"city": "Bandra West", "district": "Mumbai Suburban", "state": "Maharashtra", "pincode": "400050"},
    {"city": "Nariman Point", "district": "Mumbai", "state": "Maharashtra", "pincode": "400021"},
    {"city": "Indiranagar", "district": "Bangalore Urban", "state": "Karnataka", "pincode": "560038"},
    {"city": "Koramangala", "district": "Bangalore Urban", "state": "Karnataka", "pincode": "560034"},
    {"city": "Whitefield", "district": "Bangalore Urban", "state": "Karnataka", "pincode": "560066"},
    {"city": "Adyar", "district": "Chennai", "state": "Tamil Nadu", "pincode": "600020"},
    {"city": "T Nagar", "district": "Chennai", "state": "Tamil Nadu", "pincode": "600017"},
    {"city": "Salt Lake", "district": "North 24 Parganas", "state": "West Bengal", "pincode": "700091"},
    {"city": "Park Street", "district": "Kolkata", "state": "West Bengal", "pincode": "700016"},
    {"city": "Kothrud", "district": "Pune", "state": "Maharashtra", "pincode": "411038"},
    {"city": "Viman Nagar", "district": "Pune", "state": "Maharashtra", "pincode": "411014"},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    // Fast local matching
    final localMatches = _localLocations.where((loc) {
      final cityMatch = loc['city']!.toLowerCase().contains(query.toLowerCase());
      final districtMatch = loc['district']!.toLowerCase().contains(query.toLowerCase());
      final stateMatch = loc['state']!.toLowerCase().contains(query.toLowerCase());
      final pincodeMatch = loc['pincode']!.contains(query);
      return cityMatch || districtMatch || stateMatch || pincodeMatch;
    }).toList();

    setState(() {
      _searchResults = localMatches;
      _isLoading = true;
    });

    // Debounce the network lookup
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchLocationsFromApi(query);
    });
  }

  Future<void> _fetchLocationsFromApi(String query) async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final isPincode = RegExp(r'^\d+$').hasMatch(query);
    if (!isPincode && query.length < 3) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final url = isPincode
        ? "https://api.postalpincode.in/pincode/$query"
        : "https://api.postalpincode.in/postoffice/$query";

    try {
      final response = await _dio.get(url, cancelToken: _cancelToken);
      if (response.data != null && response.data is List && response.data.isNotEmpty) {
        final data = response.data[0];
        if (data['Status'] == 'Success' && data['PostOffice'] != null) {
          final list = data['PostOffice'] as List;
          final List<Map<String, String>> apiResults = [];

          for (var item in list) {
            apiResults.add({
              "city": item['Name'] ?? '',
              "district": item['District'] ?? '',
              "state": item['State'] ?? '',
              "pincode": item['Pincode'] ?? '',
            });
          }

          if (mounted) {
            setState(() {
              // Combine and remove duplicates
              final Map<String, Map<String, String>> uniqueResults = {};
              for (var res in _searchResults) {
                uniqueResults["${res['city']}_${res['pincode']}".toLowerCase()] = res;
              }
              for (var res in apiResults) {
                uniqueResults["${res['city']}_${res['pincode']}".toLowerCase()] = res;
              }
              _searchResults = uniqueResults.values.toList();
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      // Catch cancel / error
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatLocationString(Map<String, String> loc) {
    final city = loc['city'] ?? '';
    final district = loc['district'] ?? '';
    final state = loc['state'] ?? '';
    final pincode = loc['pincode'] ?? '';

    if (city.toLowerCase() == district.toLowerCase()) {
      return "$city, $state - $pincode";
    }
    return "$city, $district, $state - $pincode";
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerTheme.color ?? colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Select Location",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textTheme.titleLarge?.color,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textTheme.bodySmall?.color),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: "Search city, district, or pincode...",
              hintStyle: TextStyle(color: textTheme.bodySmall?.color),
              prefixIcon: Icon(Icons.search, color: textTheme.bodySmall?.color),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: Icon(Icons.clear, color: textTheme.bodySmall?.color),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: theme.inputDecorationTheme.fillColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Results Section
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasQuery) ...[
                    // Popular Grid
                    Text(
                      "Popular Cities",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _popularCities.map((city) {
                        final isSelected = widget.initialLocation?.toLowerCase().trim() == city.toLowerCase().trim();
                        return InkWell(
                          onTap: () => Navigator.pop(context, city),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primary : colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? colorScheme.primary : colorScheme.outline,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: isSelected ? Colors.black : colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  city.split(',')[0],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.black : textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Search progress and results list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Search Results",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textTheme.bodySmall?.color,
                          ),
                        ),
                        if (_isLoading)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: colorScheme.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Custom direct entry option as backup
                    InkWell(
                      onTap: () => Navigator.pop(context, _searchController.text.trim()),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_searching, color: colorScheme.primary, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Use typed value: \"${_searchController.text.trim()}\"",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textTheme.titleSmall?.color,
                                    ),
                                  ),
                                  Text(
                                    "Select this if your exact area isn't listed below.",
                                    style: TextStyle(color: textTheme.bodySmall?.color, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: textTheme.bodySmall?.color, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_searchResults.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerTheme.color),
                        itemBuilder: (context, index) {
                          final loc = _searchResults[index];
                          final formattedStr = _formatLocationString(loc);
                          final isSelected = widget.initialLocation?.toLowerCase().trim() == formattedStr.toLowerCase().trim();

                          return ListTile(
                            onTap: () => Navigator.pop(context, formattedStr),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: isSelected ? colorScheme.primary : textTheme.bodySmall?.color,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              loc['city'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? colorScheme.primary : textTheme.titleMedium?.color,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "${loc['district']}, ${loc['state']} - ${loc['pincode']}",
                              style: TextStyle(
                                color: textTheme.bodySmall?.color,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
                                : Icon(Icons.chevron_right, color: textTheme.bodySmall?.color, size: 20),
                          );
                        },
                      )
                    else if (!_isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(
                            children: [
                              Icon(Icons.search_off_outlined, size: 48, color: textTheme.bodySmall?.color),
                              const SizedBox(height: 12),
                              Text(
                                "No matches found on live directory",
                                style: TextStyle(color: textTheme.bodySmall?.color, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Please verify spelling or try typing a pincode.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textTheme.bodySmall?.color?.withOpacity(0.7), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
