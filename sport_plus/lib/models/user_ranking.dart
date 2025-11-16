class UserRanking {
  final int userId;
  final String email;
  final int totalWorkouts;
  final double totalDistance;
  final double totalDuration;
  final double? fastestPace;
  final double averageSpeed;

  UserRanking({
    required this.userId,
    required this.email,
    required this.totalWorkouts,
    required this.totalDistance,
    required this.totalDuration,
    this.fastestPace,
    required this.averageSpeed,
  });

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    return UserRanking(
      userId: json['userId'],
      email: json['email'],
      totalWorkouts: json['totalWorkouts'],
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalDuration: (json['totalDuration'] as num?)?.toDouble() ?? 0.0,
      fastestPace: (json['fastestPace'] as num?)?.toDouble(),
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}