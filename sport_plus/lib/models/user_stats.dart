class UserStats {
  final int userId;
  final int totalWorkouts;
  final double totalDistance;
  final double averageSpeed;
  final DateTime lastUpdated;

  UserStats({
    required this.userId,
    required this.totalWorkouts,
    required this.totalDistance,
    required this.averageSpeed,
    required this.lastUpdated,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['userId'],
      totalWorkouts: json['totalWorkouts'],
      totalDistance: (json['totalDistance'] is int) ? (json['totalDistance'] as int).toDouble() : json['totalDistance'],
      averageSpeed: (json['averageSpeed'] is int) ? (json['averageSpeed'] as int).toDouble() : json['averageSpeed'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalWorkouts': totalWorkouts,
      'totalDistance': totalDistance,
      'averageSpeed': averageSpeed,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}