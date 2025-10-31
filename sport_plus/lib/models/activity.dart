class Activity {
  final int activityId;
  final int userId;
  final String name;
  final String type;
  final double duration;
  final double distance;
  final double? pace;
  final double? averageSpeed;
  final String? gpsTrack;
  final String? note;
  final String? photoUrl;
  final DateTime createdAt;

  Activity({
    required this.activityId,
    required this.userId,
    required this.name,
    required this.type,
    required this.duration,
    required this.distance,
    this.pace,
    this.averageSpeed,
    this.gpsTrack,
    this.note,
    this.photoUrl,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      activityId: json['activityId'] ?? 0,
      userId: json['userId'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'unknown',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      pace: (json['pace'] as num?)?.toDouble(),
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      gpsTrack: json['gpsTrack'],
      note: json['note'],
      photoUrl: json['photoUrl'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'duration': duration,
      'distance': distance,
      'pace': pace,
      'averageSpeed': averageSpeed,
      'gpsTrack': gpsTrack,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}