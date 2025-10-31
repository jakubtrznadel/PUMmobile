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
    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults
        .any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    final prefs = await SharedPreferences.getInstance();
    dynamic statsData;

    if (isOnline) {
      try {
        statsData = await _authService.getUserStats();
        await prefs.setString('cached_stats', jsonEncode(statsData));
      } catch (e) {
        final cachedJson = prefs.getString('cached_stats');
        if (cachedJson != null) {
          statsData = jsonDecode(cachedJson);
        } else {
          return null;
        }
      }
    } else {
      final cachedJson = prefs.getString('cached_stats');
      if (cachedJson != null) {
        statsData = jsonDecode(cachedJson);
      } else {
        return null;
      }
    }

    return UserStats.fromJson(statsData);
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
          body: FutureBuilder<UserStats?>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Text(
                    translations['noStats'] ?? 'Brak statystyk',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: const Color(0xFFffc300),
                    ),
                  ),
                );
              }

              final stats = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translations['stats'] ?? 'Statystyki',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 36, color: const Color(0xFFffc300)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${translations['totalWorkouts'] ?? 'Liczba treningów'}: ${stats.totalWorkouts}',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 20, color: const Color(0xFFffc300)),
                    ),
                    Text(
                      '${translations['totalDistance'] ?? 'Całkowity dystans'}: ${stats.totalDistance.toStringAsFixed(2)} ${translations['km']}',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 20, color: const Color(0xFFffc300)),
                    ),
                    Text(
                      '${translations['averageSpeed'] ?? 'Średnia prędkość'}: ${stats.averageSpeed.toStringAsFixed(2)} ${translations['km/h']}',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 20, color: const Color(0xFFffc300)),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}