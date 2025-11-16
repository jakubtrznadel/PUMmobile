import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import '../models/activity.dart';
import '../services/auth_service.dart';
import '../language_state.dart';
import '../translations.dart';
import 'custom_app_bar.dart';
import 'activity_details_screen.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

class ActivityTrackingScreen extends StatefulWidget {
  @override
  _ActivityTrackingScreenState createState() => _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState extends State<ActivityTrackingScreen> {
  final _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final _service = FlutterBackgroundService();

  bool _isTracking = false;
  String _activityType = 'running';
  String _activityName = '';
  String _note = '';
  File? _photo;
  final MapController _mapController = MapController();
  bool _isSaving = false;

  StreamSubscription<Map<String, dynamic>?>? _serviceSubscription;
  StreamSubscription<Map<String, dynamic>?>? _finalDataSubscription;
  Map<String, dynamic>? _serviceData;

  List<LatLng> _routePoints = [];
  double _distance = 0.0;
  int _durationInSeconds = 0;
  double _averageSpeed = 0.0;
  double _pace = 0.0;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _bindService();
    _checkPermissionAndLocate();
  }

  Future<void> _checkPermissionAndLocate() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Usługa lokalizacji wyłączona. Włącz lokalizację.'),
          backgroundColor: Colors.red));
      return;
    }

    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _currentPosition =
              LatLng(initialPosition.latitude, initialPosition.longitude);
          _mapController.move(_currentPosition!, 16.0);
        });
      }
    } catch (e) {
    }
  }

  void _bindService() {
    _serviceSubscription = _service.on('update').listen((data) {
      if (data == null) return;
      setState(() {
        _isTracking = data['isRunning'] ?? false;

        _distance = (data['distance'] as num?)?.toDouble() ?? 0.0;
        _durationInSeconds = (data['duration'] as num?)?.toInt() ?? 0;
        _averageSpeed = (data['averageSpeed'] as num?)?.toDouble() ?? 0.0;
        _pace = (data['pace'] as num?)?.toDouble() ?? 0.0;

        final List<dynamic> points = data['positions'] ?? [];
        _routePoints = points
            .map((p) => LatLng(p['lat']!, p['lon']!))
            .toList();

        if (_routePoints.isNotEmpty) {
          _currentPosition = _routePoints.last;
          _mapController.move(_currentPosition!, _mapController.camera.zoom);
        }
      });
    });

    _finalDataSubscription = _service.on('finalData').listen((data) {
      if (data == null) {
        setState(() {
          _isSaving = false;
        });
        return;
      }
      _performSave(data);
    });

    _service.isRunning().then((isRunning) {
      if (isRunning) {
      }
    });
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _finalDataSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startTracking() async {
    bool serviceRunning = await _service.startService();
    if (serviceRunning) {
      _service.invoke('start');
      setState(() {
        _isTracking = true;
      });
    }
  }

  void _stopTracking() {
    if (_durationInSeconds > 0) {
      _showSaveDialog();
    } else {
      _service.invoke('stop');
      setState(() {
        _isTracking = false;
      });
    }
  }

  Future<void> _pickPhoto(StateSetter dialogSetState) async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      dialogSetState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveActivity() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    Navigator.of(context).pop();
    _service.invoke('stop');
  }

  Future<void> _performSave(Map<String, dynamic> finalData) async {
    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;

    final double finalDistance = (finalData['distance'] as num?)?.toDouble() ?? 0.0;
    final double finalDuration = (finalData['duration'] as num?)?.toDouble() ?? 0.0;

    if (finalDistance < 0.01 && finalDuration < 10) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            translations['activityTooShort'] ?? 'Aktywność zbyt krótka, nie zapisano.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final double? finalAvgSpeed = (finalData['averageSpeed'] as num?)?.toDouble();
    final double? finalPace = (finalData['pace'] as num?)?.toDouble();
    final List<dynamic> finalPositions = finalData['positions'] ?? [];

    final activity = Activity(
      activityId: 0,
      userId: 0,
      name: _activityName.isNotEmpty
          ? _activityName
          : 'Aktywność z ${DateTime.now().toIso8601String()}',
      type: _activityType,
      duration: finalDuration,
      distance: double.parse((finalDistance / 1000.0).toStringAsFixed(2)),
      pace: finalPace,
      averageSpeed: finalAvgSpeed,
      gpsTrack: jsonEncode(finalPositions),
      note: _note,
      photoUrl: null,
      createdAt: DateTime.now(),
    );

    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults
        .any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    if (!isOnline) {
      await _saveActivityLocally(activity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(translations['offlineSavedLocally'] ??
              'Offline. Zapisano lokalnie.'),
          backgroundColor: Colors.orange,
        ));
        await Future.delayed(const Duration(milliseconds: 1500));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ActivityDetailsScreen(activity: activity),
          ),
        );
      }
    } else {
      int? newActivityId;
      try {
        newActivityId = await _authService.createActivity(activity.toJson());

        if (_photo != null && newActivityId != null) {
          try {
            await _authService.uploadActivityPhoto(newActivityId, _photo!);
          } catch (photoError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(translations['activitySavedNoPhoto'] ??
                    'Aktywność zapisana, ale błąd zdjęcia.'),
                backgroundColor: Colors.orange,
              ));
            }
          }
        }

        if (mounted) {
          if (newActivityId != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(translations['activitySavedOnline'] ??
                  'Aktywność zapisana online!'),
              backgroundColor: Colors.green,
            ));
            await Future.delayed(const Duration(milliseconds: 1500));
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    ActivityDetailsScreen(activityId: newActivityId),
              ),
            );
          }
        }
      } catch (e) {
        await _saveActivityLocally(activity);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translations['serverErrorSavedLocally'] ??
                'Błąd serwera. Zapisano lokalnie.'),
            backgroundColor: Colors.orange,
          ));
          await Future.delayed(const Duration(milliseconds: 1500));
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ActivityDetailsScreen(activity: activity),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveActivityLocally(Activity activity) async {
    final prefs = await SharedPreferences.getInstance();
    var localActivitiesJSON = prefs.getStringList('local_activities') ?? [];

    final entry = {
      'activity': activity.toJson(),
      'photoPath': _photo?.path,
    };
    final entryString = jsonEncode(entry);

    if (!localActivitiesJSON.contains(entryString)) {
      localActivitiesJSON.add(entryString);
      await prefs.setStringList('local_activities', localActivitiesJSON);
    } else {
    }
  }

  void _showSaveDialog() {
    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF242424),
              title: Text(translations['saveActivity'] ?? 'Zapisz aktywność',
                  style: GoogleFonts.bebasNeue(
                      fontSize: 24, color: const Color(0xFFffc300))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => _activityName = value,
                      style: const TextStyle(color: Color(0xFFffc300)),
                      decoration: InputDecoration(
                        labelText:
                        translations['activityName'] ?? 'Nazwa aktywności',
                        labelStyle: const TextStyle(color: Color(0xFFffc300)),
                        enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFffc300))),
                        focusedBorder: const OutlineInputBorder(
                            borderSide:
                            BorderSide(color: Color(0xFFffda66), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: _activityType,
                      dropdownColor: const Color(0xFF242424),
                      style: const TextStyle(color: Color(0xFFffc300)),
                      isExpanded: true,
                      items: <String>['running', 'cycling', 'walking']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child:
                          Text(translations[value] ?? value.capitalize()),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        dialogSetState(() {
                          _activityType = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (value) => _note = value,
                      style: const TextStyle(color: Color(0xFFffc300)),
                      decoration: InputDecoration(
                        labelText: translations['note'] ?? 'Notatka',
                        labelStyle: const TextStyle(color: Color(0xFFffc300)),
                        enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFffc300))),
                        focusedBorder: const OutlineInputBorder(
                            borderSide:
                            BorderSide(color: Color(0xFFffda66), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _pickPhoto(dialogSetState),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFffc300)),
                      child: Text(
                          translations['pickPhoto'] ?? 'Wybierz zdjęcie',
                          style: GoogleFonts.bebasNeue(
                              color: const Color(0xFF242424))),
                    ),
                    if (_photo != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Image.file(_photo!,
                              height: 100, width: 100, fit: BoxFit.cover)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(translations['cancel'] ?? 'Anuluj',
                        style: const TextStyle(color: Color(0xFFffc300)))),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveActivity,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFffc300)),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF242424)))
                      : Text(translations['save'] ?? 'Zapisz',
                      style: GoogleFonts.bebasNeue(
                          color: const Color(0xFF242424))),
                ),
              ],
            );
          },
        );
      },
    );
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

  String _formatPace(double paceInMinPerKm) {
    if (paceInMinPerKm.isInfinite ||
        paceInMinPerKm.isNaN ||
        paceInMinPerKm <= 0) {
      return '--:--';
    }
    final int minutes = paceInMinPerKm.floor();
    final int seconds = ((paceInMinPerKm - minutes) * 60).round();

    if (seconds == 60) {
      return '${(minutes + 1).toString().padLeft(2, '0')}:00';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildLiveStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFffc300), size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.bebasNeue(
                fontSize: 20, color: Colors.white, letterSpacing: 1.5)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
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
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                  _currentPosition ?? const LatLng(51.40, 16.08),
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  PolylineLayer(polylines: [
                    Polyline(
                        points: _routePoints,
                        strokeWidth: 5.0,
                        color: const Color(0xFFffc300))
                  ]),
                  if (_currentPosition != null)
                    MarkerLayer(markers: [
                      Marker(
                          point: _currentPosition!,
                          width: 20,
                          height: 20,
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 20))
                    ]),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 20.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF242424),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 2.0,
                        children: [
                          _buildLiveStat(
                            translations['distance'] ?? 'Dystans',
                            '${(_distance / 1000).toStringAsFixed(2)} ${translations['km'] ?? 'km'}',
                            Icons.directions_run,
                          ),
                          _buildLiveStat(
                            translations['duration'] ?? 'Czas trwania',
                            _formatTime(_durationInSeconds),
                            Icons.timer_outlined,
                          ),
                          _buildLiveStat(
                            translations['avgSpeed'] ?? 'Prędkość',
                            '${_averageSpeed.toStringAsFixed(1)} ${translations['km/h'] ?? 'km/h'}',
                            Icons.speed,
                          ),
                          _buildLiveStat(
                            translations['pace'] ?? 'Tempo',
                            '${_formatPace(_pace)} ${translations['min/km'] ?? 'min/km'}',
                            Icons.timelapse,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                          _isTracking ? _stopTracking : _startTracking,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFffc300),
                              padding:
                              const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Text(
                            _isTracking
                                ? (translations['stop'] ?? 'Zatrzymaj')
                                : (translations['start'] ?? 'Start'),
                            style: GoogleFonts.bebasNeue(
                                fontSize: 28,
                                color: const Color(0xFF242424),
                                letterSpacing: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isSaving)
                Container(
                  color: Colors.black.withOpacity(0.75),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          translations['savingActivity'] ??
                              'Zapisywanie aktywności...',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 24,
                            color: const Color(0xFFffc300),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
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