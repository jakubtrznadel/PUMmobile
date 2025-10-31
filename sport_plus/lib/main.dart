import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/io_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'animations/splash_animation.dart';
import 'profile_screen.dart';
import 'custom_app_bar.dart';
import 'translations.dart';
import 'language_state.dart';
import 'services/auth_service.dart';
import 'activity_tracking_screen.dart';
import 'activity_list_screen.dart';
import 'stats_screen.dart';
import 'login_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await loadLanguagePreference();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    await Future.delayed(const Duration(milliseconds: 2000));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
          token != null ? MainScreen() : LoginScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFffc300)),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _authService = AuthService();
  String? _firstName;
  String? _lastName;
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndSyncActivities();
  }

  Future<void> _fetchProfileAndSyncActivities() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    _firstName = prefs.getString('firstName');
    _lastName = prefs.getString('lastName');
    _avatarUrl = prefs.getString('avatarUrl');

    var connectivityResults = await (Connectivity().checkConnectivity());
    bool isOnline = connectivityResults
        .any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    if (isOnline) {
      try {
        final token = await _authService.getToken();
        if (token == null) {
          if (mounted)
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => LoginScreen()));
          return;
        }

        final client = IOClient(HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true);
        final response = await client.get(
          Uri.parse('${AuthService.baseUrl}/api/profile'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200 && mounted) {
          final data = jsonDecode(response.body);
          setState(() {
            _firstName = data['firstName'];
            _lastName = data['lastName'];
            _avatarUrl = data['avatarUrl'];
          });
          await prefs.setString('firstName', _firstName ?? '');
          await prefs.setString('lastName', _lastName ?? '');
          await prefs.setString('avatarUrl', _avatarUrl ?? '');
        }

        var localActivitiesJSON = prefs.getStringList('local_activities') ?? [];

        if (localActivitiesJSON.isNotEmpty) {
          List<String> successfullySynced = [];
          List<String> remainingActivities = List.from(localActivitiesJSON);

          for (var entryJSON in localActivitiesJSON) {
            try {
              final entry = jsonDecode(entryJSON);
              final activityData = entry['activity'];
              final photoPath = entry['photoPath'];

              final newActivityId =
              await _authService.createActivity(activityData);

              if (photoPath != null && newActivityId != null) {
                final photoFile = File(photoPath);
                if (await photoFile.exists()) {
                  await _authService.uploadActivityPhoto(
                      newActivityId, photoFile);
                }
              }
              successfullySynced.add(entryJSON);
            } catch (e) {

            }
          }

          if (successfullySynced.isNotEmpty) {
            remainingActivities
                .removeWhere((item) => successfullySynced.contains(item));
            await prefs.setStringList('local_activities', remainingActivities);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  globalIsPolish.value ? 'Błąd połączenia' : 'Connection error')));
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  ButtonStyle _customButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.pressed))
          return const Color(0xFFffda66);
        return const Color(0xFFffc300);
      }),
      foregroundColor: WidgetStateProperty.all(const Color(0xFF242424)),
      padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0)),
      textStyle: WidgetStateProperty.all(
          GoogleFonts.bebasNeue(fontSize: 24.0, fontWeight: FontWeight.w600)),
      shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
      elevation: WidgetStateProperty.resolveWith<double>((states) {
        if (states.contains(WidgetState.pressed)) return 4.0;
        return 8.0;
      }),
      shadowColor: WidgetStateProperty.all(Colors.black26),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      animationDuration: const Duration(milliseconds: 150),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: const Color(0xFF242424),
      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
          ? ClipOval(
        child: CachedNetworkImage(
          imageUrl: '${AuthService.baseUrl}$_avatarUrl',
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          placeholder: (context, url) => const CircularProgressIndicator(
              valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFFffc300))),
          errorWidget: (context, url, error) =>
          const Icon(Icons.error, size: 50, color: Color(0xFFffc300)),
        ),
      )
          : const Icon(Icons.person, size: 50, color: Color(0xFFffc300)),
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
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFffc300))))
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(translations['welcome'] ?? 'Welcome',
                    style: GoogleFonts.bebasNeue(
                        fontSize: 36, color: const Color(0xFFffc300)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (_firstName != null && _firstName!.isNotEmpty) ...[
                  _buildAvatar(),
                  const SizedBox(height: 10),
                  Text('$_firstName $_lastName',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 24, color: const Color(0xFFffc300)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      style: _customButtonStyle(),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ActivityTrackingScreen())),
                      child: Text(
                          translations['startActivity'] ?? 'Start Activity')),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      style: _customButtonStyle(),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ActivitiesListScreen())),
                      child: Text(
                          translations['activities'] ?? 'Activities')),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      style: _customButtonStyle(),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => StatsScreen())),
                      child: Text(translations['stats'] ?? 'Statistics')),
                  const SizedBox(height: 10),
                  ElevatedButton(
                      style: _customButtonStyle(),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ProfileScreen())),
                      child: Text(
                          translations['goToProfile'] ?? 'Go to Profile')),
                ] else ...[
                  Text(translations['setUpData'] ?? 'Set up your data',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 24, color: const Color(0xFFffc300)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      style: _customButtonStyle(),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ProfileScreen())),
                      child: Text(
                          translations['goToProfile'] ?? 'Go to Profile')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}