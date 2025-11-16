import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/user_ranking.dart';
import 'services/auth_service.dart';
import 'language_state.dart';
import 'translations.dart';
import 'custom_app_bar.dart';

class RankingScreen extends StatefulWidget {
  @override
  _RankingScreenState createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _authService = AuthService();
  Future<List<UserRanking>>? _rankingFuture;
  String _sortBy = 'totalWorkouts';

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    setState(() {
      _rankingFuture = _loadRanking();
    });
  }

  Future<List<UserRanking>> _loadRanking() async {
    final List<dynamic> rankingData = await _authService.getRanking(_sortBy);
    return rankingData.map((json) => UserRanking.fromJson(json)).toList();
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

  String _getSortValue(UserRanking user, String sortBy, Map<String, String> translations) {
    switch (sortBy) {
      case 'totalWorkouts':
        return '${user.totalWorkouts}';
      case 'totalDistance':
        return '${user.totalDistance.toStringAsFixed(2)} ${translations["km"] ?? "km"}';
      case 'totalDuration':
        return _formatDuration(user.totalDuration);
      case 'fastestPace':
        return '${_formatPace(user.fastestPace)} ${translations["min/km"] ?? "min/km"}';
      case 'averageSpeed':
        return '${user.averageSpeed.toStringAsFixed(2)} ${translations["km/h"] ?? "km/h"}';
      default:
        return '';
    }
  }

  String _getRankIcon(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '${index + 1}.';
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = value == _sortBy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) {
            setState(() {
              _sortBy = value;
              _fetchRanking();
            });
          }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  translations['ranking'] ?? 'Ranking',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 42,
                    color: const Color(0xFFffc300),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildFilterChip(translations['totalWorkouts'] ?? 'Treningi', 'totalWorkouts'),
                    _buildFilterChip(translations['totalDistance'] ?? 'Dystans', 'totalDistance'),
                    _buildFilterChip(translations['totalDuration'] ?? 'Czas', 'totalDuration'),
                    _buildFilterChip(translations['fastestPace'] ?? 'Tempo', 'fastestPace'),
                    _buildFilterChip(translations['averageSpeed'] ?? 'Prędkość', 'averageSpeed'),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchRanking,
                  color: const Color(0xFF242424),
                  backgroundColor: const Color(0xFFffc300),
                  child: FutureBuilder<List<UserRanking>>(
                    future: _rankingFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Text(
                                translations['noRankingData'] ?? 'Brak danych do rankingu',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 24,
                                  color: const Color(0xFFffc300),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final rankingList = snapshot.data!;
                      return ListView.builder(
                        itemCount: rankingList.length,
                        itemBuilder: (context, index) {
                          final user = rankingList[index];
                          final value = _getSortValue(user, _sortBy, translations);

                          return Card(
                            color: const Color(0xFF242424),
                            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: index < 3
                                  ? const BorderSide(color: Color(0xFFffc300), width: 1)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: Text(
                                _getRankIcon(index),
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 22,
                                  color: const Color(0xFFffc300),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              title: Text(
                                user.email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                value,
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 20,
                                  color: const Color(0xFFffc300),
                                ),
                              ),
                            ),
                          );
                        },
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