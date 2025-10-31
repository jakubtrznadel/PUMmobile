import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity.dart';
import '../services/auth_service.dart';
import '../language_state.dart';
import '../translations.dart';
import 'custom_app_bar.dart';

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
  bool _isTracking = false;
  DateTime? _startTime;
  double _distance = 0.0;
  List<Position> _positions = [];
  StreamSubscription<Position>? _positionStream;
  String _activityType = 'running';
  String _activityName = '';
  String _note = '';
  File? _photo;
  LatLng? _currentPosition;
  final MapController _mapController = MapController();
  Timer? _timer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<bool> _checkLocationServicesAndPermissions() async {
    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Usługa lokalizacji wyłączona. Włącz lokalizację.'),
          backgroundColor: Colors.red));
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Odmówiono dostępu do lokalizacji.'),
            backgroundColor: Colors.red));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Dostęp do lokalizacji zablokowany. Włącz go w ustawieniach aplikacji.'),
          backgroundColor: Colors.red));
      return false;
    }
    return true;
  }

  void _startLocationStream() async {
    bool hasPermission = await _checkLocationServicesAndPermissions();
    if (!hasPermission) return;

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
      print("Nie udało się pobrać początkowej lokalizacji: $e");
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          if (_isTracking) {
            if (_positions.isNotEmpty) {
              _distance += Geolocator.distanceBetween(
                _positions.last.latitude,
                _positions.last.longitude,
                position.latitude,
                position.longitude,
              );
            }
            _positions.add(position);
            _mapController.move(
                LatLng(position.latitude, position.longitude),
                _mapController.camera.zoom);
          }
        });
      }
    });
  }

  void _startTracking() async {
    bool hasPermission = await _checkLocationServicesAndPermissions();
    if (!hasPermission) return;
    setState(() {
      _isTracking = true;
      _startTime = DateTime.now();
      _positions = [];
      _distance = 0.0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      } else {
        timer.cancel();
      }
    });
  }

  void _stopTracking() {
    _timer?.cancel();
    setState(() {
      _isTracking = false;
    });
    if (_startTime != null) {
      _showSaveDialog();
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
    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;
    if (_startTime == null || _isSaving) return;
    setState(() {
      _isSaving = true;
    });
    Navigator.of(context).pop();

    final durationInSeconds = DateTime.now().difference(_startTime!).inSeconds;
    final durationInHours = durationInSeconds / 3600.0;
    double? averageSpeed;
    double? pace;
    double distanceInKm = _distance / 1000.0;

    if (distanceInKm > 0 && durationInHours > 0) {
      averageSpeed = distanceInKm / durationInHours;
      pace = (durationInSeconds / 60.0) / distanceInKm;
    }

    final activity = Activity(
      activityId: 0,
      userId: 0,
      name: _activityName.isNotEmpty
          ? _activityName
          : 'Aktywność z ${DateTime.now().toIso8601String()}',
      type: _activityType,
      duration: double.parse(durationInHours.toStringAsFixed(2)),
      distance: double.parse(distanceInKm.toStringAsFixed(2)),
      pace: pace,
      averageSpeed: averageSpeed,
      gpsTrack: jsonEncode(
          _positions.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList()),
      note: _note,
      photoUrl: null,
      createdAt: DateTime.now(),
    );

    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults
        .any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    if (isOnline) {
      try {
        final newActivityId = await _authService.createActivity(activity.toJson());
        if (_photo != null && newActivityId != null) {
          await _authService.uploadActivityPhoto(newActivityId, _photo!);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translations['activitySavedOnline'] ??
                'Aktywność zapisana online!'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        await _saveActivityLocally(activity);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(translations['serverErrorSavedLocally'] ??
                'Błąd serwera. Zapisano lokalnie.'),
            backgroundColor: Colors.orange,
          ));
        }
      }
    } else {
      await _saveActivityLocally(activity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(translations['offlineSavedLocally'] ??
              'Offline. Zapisano lokalnie.'),
          backgroundColor: Colors.orange,
        ));
      }
    }

    setState(() {
      _isSaving = false;
      _activityName = '';
      _note = '';
      _photo = null;
      _activityType = 'running';
    });
  }

  Future<void> _saveActivityLocally(Activity activity) async {
    final prefs = await SharedPreferences.getInstance();
    var localActivitiesJSON = prefs.getStringList('local_activities') ?? [];
    final entry = {
      'activity': activity.toJson(),
      'photoPath': _photo?.path,
    };
    if (!localActivitiesJSON.any((json) => json == jsonEncode(entry))) {
      localActivitiesJSON.add(jsonEncode(entry));
      await prefs.setStringList('local_activities', localActivitiesJSON);
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
                        labelText: translations['activityName'] ?? 'Nazwa aktywności',
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
                          child: Text(translations[value] ?? value.capitalize()),
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
                      child: Text(translations['pickPhoto'] ?? 'Wybierz zdjęcie',
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

  Widget _buildLiveStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFffc300), size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.bebasNeue(
                fontSize: 32, color: Colors.white, letterSpacing: 1.5)),
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
                        points: _positions
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLiveStat(
                            translations['distance'] ?? 'Dystans',
                            '${(_distance / 1000).toStringAsFixed(2)} ${translations['km']}',
                            Icons.directions_run,
                          ),
                          _buildLiveStat(
                            translations['duration'] ?? 'Czas trwania',
                            _formatTime(_startTime != null
                                ? DateTime.now().difference(_startTime!).inSeconds
                                : 0),
                            Icons.timer_outlined,
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
            ],
          ),
        );
      },
    );
  }
}