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
    });

    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    List<dynamic> activitiesData = [];
    final prefs = await SharedPreferences.getInstance();

    if (isOnline) {
      try {
        activitiesData = await _authService.getUserActivities();
        await prefs.setStringList('cached_activities', activitiesData.map((d) => jsonEncode(d)).toList());
      } catch (_) {
        activitiesData = _loadCachedActivities(prefs);
      }
    } else {
      activitiesData = _loadCachedActivities(prefs);
    }

    activitiesData.addAll(_loadPendingActivities(prefs));

    setState(() {
      _activities = activitiesData.map((json) => Activity.fromJson(json is Map<String, dynamic> ? json : jsonDecode(json))).toList();
      _isLoading = false;
    });
  }

  List<dynamic> _loadCachedActivities(SharedPreferences prefs) {
    return (prefs.getStringList('cached_activities') ?? []).map((s) => jsonDecode(s)).toList();
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalIsPolish,
      builder: (context, isPolish, child) {
        final translations = isPolish ? Translations.pl : Translations.en;

        return Scaffold(
          appBar: CustomAppBar(),
          backgroundColor: const Color(0xFF1a1a1a),
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
            ),
          )
              : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _filterType,
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            translations['all'] ?? 'All',
                            style: const TextStyle(color: Color(0xFFffc300)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'running',
                          child: Text(
                            translations['running'] ?? 'Running',
                            style: const TextStyle(color: Color(0xFFffc300)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'cycling',
                          child: Text(
                            translations['cycling'] ?? 'Cycling',
                            style: const TextStyle(color: Color(0xFFffc300)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'walking',
                          child: Text(
                            translations['walking'] ?? 'Walking',
                            style: const TextStyle(color: Color(0xFFffc300)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterType = value!;
                        });
                      },
                    ),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: [
                        DropdownMenuItem(
                          value: 'date',
                          child: Text(
                            translations['date'] ?? 'Date',
                            style: const TextStyle(color: Color(0xFFffc300)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'distance',
                          child: Text(
                            translations['distance'] ?? 'Distance',
                            style: const TextStyle(color: Color(0xFFffc300)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _getFilteredAndSortedActivities().length,
                  itemBuilder: (context, index) {
                    final activity = _getFilteredAndSortedActivities()[index];
                    return ListTile(
                      title: Text(
                        activity.name,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 20,
                          color: const Color(0xFFffc300),
                        ),
                      ),
                      subtitle: Text(
                        '${translations[activity.type] ?? activity.type} - ${activity.distance} km',
                        style: const TextStyle(color: Color(0xFFffc300)),
                      ),
                      onTap: activity.activityId != 0 ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivityDetailsScreen(activityId: activity.activityId),
                          ),
                        );
                      } : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}