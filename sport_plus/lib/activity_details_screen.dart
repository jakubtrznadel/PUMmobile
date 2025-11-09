import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/activity.dart';
import '../services/auth_service.dart';
import '../language_state.dart';
import '../translations.dart';
import 'custom_app_bar.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final int activityId;

  const ActivityDetailsScreen({super.key, required this.activityId});

  @override
  _ActivityDetailsScreenState createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final _authService = AuthService();
  Activity? _activity;
  bool _isLoading = true;
  bool _isExporting = false;
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchActivity();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _parseGpsTrack(String? gpsTrack) {
    if (gpsTrack == null || gpsTrack.isEmpty) return;
    try {
      final List<dynamic> pointsJson = jsonDecode(gpsTrack);
      setState(() {
        _routePoints = pointsJson
            .map((point) => LatLng(point['lat'], point['lon']))
            .toList();
      });
    } catch (e) {
      print('Błąd parsowania trasy GPS: $e');
    }
  }

  Future<void> _fetchActivity() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final activityData = await _authService.getActivity(widget.activityId);
      final activity = Activity.fromJson(activityData);
      setState(() {
        _activity = activity;
      });
      _parseGpsTrack(activity.gpsTrack);
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExportGpx() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    final translations =
    globalIsPolish.value ? Translations.pl : Translations.en;

    try {
      final Uint8List gpxBytes =
      await _authService.exportActivityToGpx(widget.activityId);

      String fileName =
          'activity_${_activity?.name.replaceAll(' ', '_') ?? widget.activityId}.gpx';

      final String? path = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: gpxBytes,
          fileName: fileName,
        ),
      );

      if (path != null) {
        _showSuccess(
            '${translations['fileSaved'] ?? 'Zapisano plik'}: $fileName');
      } else {
        print("Zapisywanie pliku anulowane przez użytkownika.");
      }
    } catch (e) {
      _showError(
          '${translations['exportError'] ?? 'Błąd podczas eksportu'}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  String _formatDuration(double durationInHours, Map<String, String> translations) {
    if (durationInHours < 0) return "0 ${translations['min']} 0 ${translations['s']}";
    final totalSeconds = (durationInHours * 3600).round();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours ${translations['h']} $minutes ${translations['min']}';
    } else {
      return '$minutes ${translations['min']} $seconds ${translations['s']}';
    }
  }

  String _formatPace(double? decimalPace) {
    if (decimalPace == null || decimalPace <= 0) return "-";
    final int minutes = decimalPace.floor();
    final int seconds = ((decimalPace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(LatLng(0, 0), LatLng(0, 0));
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Map<String, String> translations,
  }) {
    return Card(
      color: const Color(0xFF242424),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Icon(icon, color: const Color(0xFFffc300), size: 26),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Flexible(
              child: Text(
                translations[label] ?? label,
                style: TextStyle(
                  fontSize: 13,
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalIsPolish,
      builder: (context, isPolish, child) {
        final translations = isPolish ? Translations.pl : Translations.en;

        return Scaffold(
          appBar: CustomAppBar(),
          backgroundColor: const Color(0xFF1a1a1a),
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc3D)),
            ),
          )
              : _activity == null
              ? Center(
            child: Text(
              translations['activityNotFound'] ?? 'Activity not found',
              style: GoogleFonts.bebasNeue(
                fontSize: 24,
                color: const Color(0xFFffc3D0),
              ),
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _activity!.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 38,
                    color: const Color(0xFFffc300),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    _buildStatCard(
                      icon: Icons.directions_run,
                      value: '${_activity!.distance.toStringAsFixed(2)} ${translations['km']}',
                      label: 'distance',
                      translations: translations,
                    ),
                    _buildStatCard(
                      icon: Icons.timer_outlined,
                      value: _formatDuration(_activity!.duration, translations),
                      label: 'duration',
                      translations: translations,
                    ),
                    _buildStatCard(
                      icon: Icons.speed,
                      value: '${_formatPace(_activity!.pace)} ${translations['min/km']}',
                      label: 'pace',
                      translations: translations,
                    ),
                    _buildStatCard(
                      icon: Icons.shutter_speed,
                      value: '${_activity!.averageSpeed?.toStringAsFixed(2) ?? '-'} ${translations['km/h']}',
                      label: 'averageSpeed',
                      translations: translations,
                    ),
                  ],
                ),

                if (_activity!.note != null &&
                    _activity!.note!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    translations['note'] ?? 'Notatka',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: const Color(0xFFffc300),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _activity!.note!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (_routePoints.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _routePoints.first,
                          initialZoom: 14,
                          onMapReady: () {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (mounted && _routePoints.isNotEmpty) {
                                final bounds = _calculateBounds(_routePoints);

                                if (bounds.southWest == bounds.northEast) {
                                  _mapController.move(bounds.center, 17.0);
                                } else {
                                  _mapController.fitCamera(
                                    CameraFit.bounds(
                                      bounds: bounds,
                                      padding: const EdgeInsets.all(30.0),
                                    ),
                                  );
                                }
                              }
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5.0,
                                color: const Color(0xFFffc300),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_activity!.photoUrl != null &&
                    _activity!.photoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) {
                            return _FullScreenImageViewer(
                              imageUrl:
                              '${AuthService.baseUrl}${_activity!.photoUrl}',
                              heroTag:
                              'activityImage${_activity!.activityId}',
                            );
                          }));
                    },
                    child: Hero(
                      tag: 'activityImage${_activity!.activityId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl:
                          '${AuthService.baseUrl}${_activity!.photoUrl}',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                          const Center(
                              child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _handleExportGpx,
                  icon: _isExporting
                      ? Container(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF242424)),
                    ),
                  )
                      : const Icon(Icons.download,
                      color: Color(0xFF242424)),
                  label: Text(
                    _isExporting
                        ? (translations['exporting'] ?? 'Eksportowanie...')
                        : (translations['exportToGpx'] ??
                        'Eksportuj do GPX'),
                    style: GoogleFonts.bebasNeue(
                      fontSize: 20,
                      color: const Color(0xFF242424),
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffc300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer(
      {required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Hero(
            tag: heroTag,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40.0,
            left: 10.0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30.0),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}