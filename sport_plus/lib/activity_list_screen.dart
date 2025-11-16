import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity.dart';
import '../services/auth_service.dart';
import '../language_state.dart';
import '../translations.dart';
import 'custom_app_bar.dart';
import 'activity_details_screen.dart';

class ActivitiesListScreen extends StatefulWidget {
  @override
  _ActivitiesListScreenState createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends State<ActivitiesListScreen> {
  final _authService = AuthService();
  List<Activity> _activities = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _filterType = 'all';
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults
        .any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    List<dynamic> activitiesData = [];
    final prefs = await SharedPreferences.getInstance();

    final pendingActivities = _loadPendingActivities(prefs);

    if (isOnline) {
      try {
        activitiesData =
        await _authService.getUserActivities().timeout(const Duration(seconds: 3));

        await prefs.setStringList('cached_activities',
            activitiesData.map((d) => jsonEncode(d)).toList());

        activitiesData.addAll(pendingActivities);
      } catch (e) {
        setState(() {
          _isOffline = true;
        });
        activitiesData = pendingActivities;
      }
    } else {
      setState(() {
        _isOffline = true;
      });
      activitiesData = pendingActivities;
    }

    setState(() {
      _activities = activitiesData
          .map((json) =>
          Activity.fromJson(json is Map<String, dynamic> ? json : jsonDecode(json)))
          .toList();
      _isLoading = false;
    });
  }

  List<dynamic> _loadCachedActivities(SharedPreferences prefs) {
    return (prefs.getStringList('cached_activities') ?? [])
        .map((s) => jsonDecode(s))
        .toList();
  }

  List<dynamic> _loadPendingActivities(SharedPreferences prefs) {
    return (prefs.getStringList('local_activities') ?? []).map((s) {
      final entry = jsonDecode(s);
      return entry['activity'];
    }).toList();
  }

  List<Activity> _getFilteredAndSortedActivities() {
    var filtered = _activities;
    if (_filterType != 'all') {
      filtered = filtered.where((a) => a.type == _filterType).toList();
    }
    if (_sortBy == 'date') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortBy == 'distance') {
      filtered.sort((a, b) => b.distance.compareTo(a.distance));
    }
    return filtered;
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.timeline;
    }
  }

  String _formatDate(DateTime date, Map<String, String> translations) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }

  Widget _buildFilterChip(String label, String value, String groupValue,
      Function(String) onSelected) {
    final isSelected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) onSelected(value);
        },
        backgroundColor: const Color(0xFF242424),
        selectedColor: const Color(0xFFffc300),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF242424) : const Color(0xFFffc300),
          fontWeight: FontWeight.bold,
        ),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFFffc300))),
      ),
    );
  }

  Widget _buildActivityCard(
      Activity activity, Map<String, String> translations) {
    final isPending = activity.activityId == 0;

    return Card(
      color: const Color(0xFF242424),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (isPending) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ActivityDetailsScreen(activity: activity),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ActivityDetailsScreen(activityId: activity.activityId),
              ),
            ).then((_) => _fetchActivities());
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                _getIconForType(activity.type),
                color: const Color(0xFFffc300),
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.name,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 24,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(activity.createdAt, translations),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${activity.distance.toStringAsFixed(2)} ${translations["km"] ?? "km"}',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 26,
                      color: const Color(0xFFffc300),
                    ),
                  ),
                  if (isPending)
                    Text(
                      translations['pending'] ?? 'Oczekuje',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineWarning(Map<String, String> translations) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      color: const Color(0xFFffc300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: const Color(0xFF242424), size: 20),
          const SizedBox(width: 10),
          Text(
            translations['offlinePendingOnly'] ??
                'Brak połączenia. Widoczne tylko oczekujące.',
            style: TextStyle(
              color: const Color(0xFF242424),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalIsPolish,
      builder: (context, isPolish, child) {
        final translations = isPolish ? Translations.pl : Translations.en;
        final filteredActivities = _getFilteredAndSortedActivities();

        return Scaffold(
          appBar: CustomAppBar(),
          backgroundColor: const Color(0xFF1a1a1a),
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isOffline) _buildOfflineWarning(translations),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  translations['filterBy'] ?? 'Filtruj',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: const Color(0xFFffc300),
                    letterSpacing: 1,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildFilterChip(
                        translations['all'] ?? 'All', 'all', _filterType,
                            (value) {
                          setState(() => _filterType = value);
                        }),
                    _buildFilterChip(translations['running'] ?? 'Running',
                        'running', _filterType, (value) {
                          setState(() => _filterType = value);
                        }),
                    _buildFilterChip(
                        translations['cycling'] ?? 'Cycling',
                        'cycling',
                        _filterType, (value) {
                      setState(() => _filterType = value);
                    }),
                    _buildFilterChip(
                        translations['walking'] ?? 'Walking',
                        'walking',
                        _filterType, (value) {
                      setState(() => _filterType = value);
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  translations['sortBy'] ?? 'Sortuj',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: const Color(0xFFffc300),
                    letterSpacing: 1,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildFilterChip(
                        translations['date'] ?? 'Date', 'date', _sortBy,
                            (value) {
                          setState(() => _sortBy = value);
                        }),
                    _buildFilterChip(translations['distance'] ?? 'Distance',
                        'distance', _sortBy, (value) {
                          setState(() => _sortBy = value);
                        }),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchActivities,
                  color: const Color(0xFF242424),
                  backgroundColor: const Color(0xFFffc300),
                  child: filteredActivities.isEmpty
                      ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context)
                              .size
                              .height *
                              0.2),
                      Center(
                        child: Text(
                          translations['noActivitiesFound'] ??
                              'Nie znaleziono aktywności',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  )
                      : ListView.builder(
                    itemCount: filteredActivities.length,
                    itemBuilder: (context, index) {
                      final activity = filteredActivities[index];
                      return _buildActivityCard(
                          activity, translations);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}