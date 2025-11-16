import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import '../translations.dart';
import '../language_state.dart';

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  StreamSubscription<Position>? positionStream;
  DateTime? startTime;
  Timer? timer;
  double distance = 0.0;
  double avgSpeed = 0.0;
  double pace = 0.0;
  int durationInSeconds = 0;
  List<Map<String, double>> positions = [];
  bool isRunning = false;

  final translations =
  globalIsPolish.value ? Translations.pl : Translations.en;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stop').listen((event) {
    isRunning = false;
    positionStream?.cancel();
    timer?.cancel();

    final finalData = {
      'distance': distance,
      'duration': durationInSeconds.toDouble(),
      'averageSpeed': avgSpeed,
      'pace': pace,
      'positions': positions,
    };

    service.invoke('finalData', finalData);

    service.stopSelf();
  });

  service.on('start').listen((event) {
    if (isRunning) return;
    isRunning = true;

    distance = 0.0;
    avgSpeed = 0.0;
    pace = 0.0;
    durationInSeconds = 0;
    positions = [];
    startTime = DateTime.now();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!isRunning) return;

      final newPoint = {'lat': position.latitude, 'lon': position.longitude};

      if (positions.isNotEmpty) {
        final lastPoint = positions.last;
        distance += Geolocator.distanceBetween(
          lastPoint['lat']!,
          lastPoint['lon']!,
          position.latitude,
          position.longitude,
        );
      }
      positions.add(newPoint);
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRunning) {
        timer.cancel();
        return;
      }

      durationInSeconds = DateTime.now().difference(startTime!).inSeconds;
      final durationInHours = durationInSeconds / 3600.0;
      final distanceInKm = distance / 1000.0;

      if (distanceInKm > 0 && durationInSeconds > 0) {
        avgSpeed = distanceInKm / durationInHours;
        final durationInMinutes = durationInSeconds / 60.0;
        pace = durationInMinutes / distanceInKm;
      } else {
        avgSpeed = 0.0;
        pace = 0.0;
      }

      final Map<String, dynamic> data = {
        'distance': distance,
        'duration': durationInSeconds,
        'averageSpeed': avgSpeed,
        'pace': pace,
        'positions': positions,
        'isRunning': true,
      };

      service.invoke('update', data);

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: translations['appTitle'] ?? 'Sport+',
          content:
          '${translations['distance'] ?? 'Dystans'}: ${distanceInKm.toStringAsFixed(2)} km | ${translations['duration'] ?? 'Czas'}: ${_formatTime(durationInSeconds)}',
        );
      }
    });
  });
}

@pragma('vm:entry-point')
Future<bool> onBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await loadLanguagePreference();
  return true;
}

String _formatTime(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  final paddedMinutes = minutes.toString().padLeft(2, '0');
  final paddedSeconds = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$paddedMinutes:$paddedSeconds';
  } else {
    return '$paddedMinutes:$paddedSeconds';
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  final translations = globalIsPolish.value ? Translations.pl : Translations.en;

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'sport_plus_channel',
      initialNotificationTitle: translations['appTitle'] ?? 'Sport+',
      initialNotificationContent:
      translations['serviceRunning'] ?? 'Usługa śledzenia gotowa.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onBackground,
    ),
  );
}