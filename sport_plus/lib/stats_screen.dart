import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_stats.dart';
import '../services/auth_service.dart';
import '../language_state.dart';
import '../translations.dart';
import 'custom_app_bar.dart';

class StatsScreen extends StatefulWidget {
  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _authService = AuthService();
  Future<UserStats?>? _statsFuture;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _statsFuture = _getUserStats();
    });
  }

  Future<UserStats?> _getUserStats() async {
    setState(() {
      _isOffline = false;
    });

    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults
        .any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    final prefs = await SharedPreferences.getInstance();
    dynamic statsData;

    if (isOnline) {
      try {
        statsData =
        await _authService.getUserStats().timeout(const Duration(seconds: 3));
        await prefs.setString('cached_stats', jsonEncode(statsData));
      } catch (e) {
        setState(() {
          _isOffline = true;
        });
        final cachedJson = prefs.getString('cached_stats');
        if (cachedJson != null) {
          statsData = jsonDecode(cachedJson);
        } else {
          return null;
        }
      }
    } else {
      setState(() {
        _isOffline = true;
      });
      final cachedJson = prefs.getString('cached_stats');
      if (cachedJson != null) {
        statsData = jsonDecode(cachedJson);
      } else {
        return null;
      }
    }

    return UserStats.fromJson(statsData);
  }

  String _formatDuration(double totalSeconds) {
    if (totalSeconds.isNaN || totalSeconds.isInfinite || totalSeconds < 0) {
      return "00:00";
    }
    int seconds = totalSeconds.floor() % 60;
    int minutes = (totalSeconds.floor() ~/ 60) % 60;
    int hours = (totalSeconds.floor() ~/ 3600);

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return "${hours.toString()}:$minutesStr:$secondsStr";
    } else {
      return "$minutesStr:$secondsStr";
    }
  }

  String _formatPace(double? paceInMinutes) {
    if (paceInMinutes == null ||
        paceInMinutes.isNaN ||
        paceInMinutes.isInfinite ||
        paceInMinutes <= 0) {
      return "--:--";
    }
    int minutes = paceInMinutes.floor();
    int seconds = ((paceInMinutes - minutes) * 60).round();

    if (seconds == 60) {
      return "${(minutes + 1).toString().padLeft(2, '0')}:00";
    }

    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      color: const Color(0xFF242424),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFffc300), size: 36),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.bebasNeue(
                  fontSize: 34,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
            translations['offlineCachedData'] ??
                'Brak połączenia. Widoczne dane z pamięci.',
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

        return Scaffold(
          appBar: CustomAppBar(),
          backgroundColor: const Color(0xFF1a1a1a),
          body: Column(
            children: [
              if (_isOffline) _buildOfflineWarning(translations),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchStats,
                  color: const Color(0xFF242424),
                  backgroundColor: const Color(0xFFffc300),
                  child: FutureBuilder<UserStats?>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFffc300)),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                                height:
                                MediaQuery.of(context).size.height * 0.3),
                            Center(
                              child: Text(
                                translations['noStats'] ?? 'Brak statystyk',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 24,
                                  color: const Color(0xFFffc300),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final stats = snapshot.data!;
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              translations['yourStats'] ?? 'Twoje Statystyki',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 42,
                                color: const Color(0xFFffc300),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1,
                              children: [
                                _buildStatCard(
                                  icon: Icons.track_changes,
                                  value: stats.totalWorkouts.toString(),
                                  label: translations['totalWorkouts'] ??
                                      'Liczba treningów',
                                ),
                                _buildStatCard(
                                  icon: Icons.map,
                                  value:
                                  '${stats.totalDistance.toStringAsFixed(2)} ${translations["km"] ?? "km"}',
                                  label: translations['totalDistance'] ??
                                      'Całkowity dystans',
                                ),
                                _buildStatCard(
                                  icon: Icons.timer,
                                  value: _formatDuration(stats.totalDuration),
                                  label: translations['totalDuration'] ??
                                      'Całkowity czas',
                                ),
                                _buildStatCard(
                                  icon: Icons.speed,
                                  value:
                                  '${stats.averageSpeed.toStringAsFixed(2)} ${translations["km/h"] ?? "km/h"}',
                                  label: translations['averageSpeed'] ??
                                      'Średnia prędkość',
                                ),
                                _buildStatCard(
                                  icon: Icons.rocket_launch,
                                  value:
                                  '${_formatPace(stats.fastestPace)} ${translations["min/km"] ?? "min/km"}',
                                  label: translations['fastestPace'] ??
                                      'Najszybsze tempo',
                                ),
                                _buildStatCard(
                                  icon: Icons.star,
                                  value:
                                  '${stats.maxDistance.toStringAsFixed(2)} ${translations["km"] ?? "km"}',
                                  label: translations['maxDistance'] ??
                                      'Najdłuższy dystans',
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
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