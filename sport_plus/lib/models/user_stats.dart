class UserStats {
  final int userId;
  final int totalWorkouts;
  final double totalDistance;
  final double averageSpeed;
  final double maxDistance;
  final double totalDuration;
  final double? fastestPace;
  final DateTime lastUpdated;

  UserStats({
    required this.userId,
    required this.totalWorkouts,
    required this.totalDistance,
    required this.averageSpeed,
    required this.maxDistance,
    required this.totalDuration,
    this.fastestPace,
    required this.lastUpdated,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['userId'],
      totalWorkouts: json['totalWorkouts'],
      totalDistance: (json['totalDistance'] is int)
          ? (json['totalDistance'] as int).toDouble()
          : json['totalDistance'],
      averageSpeed: (json['averageSpeed'] is int)
          ? (json['averageSpeed'] as int).toDouble()
          : json['averageSpeed'],
      maxDistance: (json['maxDistance'] is int)
          ? (json['maxDistance'] as int).toDouble()
          : json['maxDistance'],
      totalDuration: (json['totalDuration'] is int)
          ? (json['totalDuration'] as int).toDouble()
          : json['totalDuration'],
      fastestPace: (json['fastestPace'] is int)
          ? (json['fastestPace'] as int).toDouble()
          : json['fastestPace'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalWorkouts': totalWorkouts,
      'totalDistance': totalDistance,
      'averageSpeed': averageSpeed,
      'maxDistance': maxDistance,
      'totalDuration': totalDuration,
      'fastestPace': fastestPace,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}