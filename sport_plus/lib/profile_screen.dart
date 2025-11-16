import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http/io_client.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'custom_app_bar.dart';
import 'translations.dart';
import 'language_state.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  late IOClient _client;
  String? _firstName;
  String? _lastName;
  String? _birthDate;
  String? _gender;
  String? _height;
  String? _weight;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _isOffline = false;
  File? _image;

  @override
  void initState() {
    super.initState();
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    httpClient.connectionTimeout = Duration(seconds: 10);
    _client = IOClient(httpClient);

    _loadCachedProfile();
    _fetchProfile();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstName = prefs.getString('firstName') ?? '';
      _lastName = prefs.getString('lastName') ?? '';
      _birthDate = prefs.getString('birthDate') ?? '';
      _gender = prefs.getString('gender') ?? 'Male';
      _height = prefs.getString('height') ?? '';
      _weight = prefs.getString('weight') ?? '';
      _avatarUrl = prefs.getString('avatarUrl');
      _isInitialLoading = false;
    });
  }

  Future<void> _saveCachedProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firstName', data['firstName'] ?? '');
    await prefs.setString('lastName', data['lastName'] ?? '');
    await prefs.setString('birthDate', data['birthDate'] ?? '');
    await prefs.setString('gender', data['gender'] ?? 'Male');
    await prefs.setString('height', data['height']?.toString() ?? '');
    await prefs.setString('weight', data['weight']?.toString() ?? '');
    await prefs.setString('avatarUrl', data['avatarUrl'] ?? '');
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    final connectivityResults = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResults.any((r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    if (!isOnline) {
      setState(() {
        _isOffline = true;
        _isLoading = false;
        _isInitialLoading = false;
      });
      return;
    }

    final token = await _authService.getToken();
    try {
      final response = await _client.get(
        Uri.parse('${AuthService.baseUrl}/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _firstName = data['firstName'] ?? '';
          _lastName = data['lastName'] ?? '';
          _birthDate = data['birthDate'] ?? '';
          _gender = data['gender']?.isEmpty ?? true ? 'Male' : data['gender'];
          _height = data['height']?.toString() ?? '';
          _weight = data['weight']?.toString() ?? '';
          _avatarUrl = data['avatarUrl'];
        });
        await _saveCachedProfile(data);
      } else {
        _showError(
            globalIsPolish.value ? 'Błąd pobierania profilu' : 'Failed to load profile');
        setState(() {
          _isOffline = true;
        });
      }
    } catch (e) {
      _showError(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
      setState(() {
        _isOffline = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> body) async {
    setState(() {
      _isLoading = true;
    });

    final token = await _authService.getToken();
    try {
      final response = await _client.put(
        Uri.parse('${AuthService.baseUrl}/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _showSuccess(globalIsPolish.value ? 'Zaktualizowano!' : 'Updated!');
        await _fetchProfile();
      } else {
        _showError(globalIsPolish.value ? 'Błąd aktualizacji' : 'Update failed');
      }
    } catch (e) {
      _showError(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isOffline) return;

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle:
            globalIsPolish.value ? 'Dopasuj zdjęcie' : 'Adjust Photo',
            toolbarColor: const Color(0xFF1a1a1a),
            toolbarWidgetColor: const Color(0xFFffc300),
            backgroundColor: const Color(0xFF1a1a1a),
            activeControlsWidgetColor: const Color(0xFFffda66),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: globalIsPolish.value ? 'Dopasuj zdjęcie' : 'Adjust Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _image = File(croppedFile.path);
        _isLoading = true;
      });

      final token = await _authService.getToken();
      try {
        var request = http.MultipartRequest(
            'POST', Uri.parse('${AuthService.baseUrl}/api/profile/avatar'));
        request.headers['Authorization'] = 'Bearer $token';
        request.files
            .add(await http.MultipartFile.fromPath('file', _image!.path));

        final streamedResponse = await _client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _avatarUrl = data['avatarUrl'];
            _image = null;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('avatarUrl', data['avatarUrl'] ?? '');
          _showSuccess(
              globalIsPolish.value ? 'Avatar zaktualizowany!' : 'Avatar updated!');
        } else {
          _showError(globalIsPolish.value
              ? 'Błąd wgrywania avatara'
              : 'Avatar upload failed');
        }
      } catch (e) {
        _showError(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('already_active')) {
        _showError(globalIsPolish.value
            ? 'Galeria już otwarta, spróbuj ponownie'
            : 'Gallery already open, try again');
      } else {
        _showError(globalIsPolish.value
            ? 'Błąd podczas wybierania zdjęcia'
            : 'Error picking image');
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logoutAndClearData();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (Route<dynamic> route) => false,
      );
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

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFffc300)),
      enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFffc300))),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFffda66), width: 2)),
    );
  }

  Future<void> _showEditDialog(String label, String? currentValue, String field,
      {bool isNumber = false,
        bool isDate = false,
        bool isGender = false}) async {
    final controller = TextEditingController(text: currentValue);
    String selectedGender =
    currentValue?.isEmpty ?? true ? 'Male' : currentValue!;

    int numberValue = (isNumber && currentValue != null && currentValue.isNotEmpty)
        ? (double.tryParse(currentValue)?.round() ?? (field == 'height' ? 150 : 70))
        : (field == 'height' ? 150 : 70);

    await showDialog(
      context: context,
      builder: (context) {
        final translations =
        globalIsPolish.value ? Translations.pl : Translations.en;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget contentWidget;

            if (isDate) {
              contentWidget = TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFFffc300)),
                cursorColor: const Color(0xFFffc300),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(currentValue ?? '') ??
                        DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFffc300),
                            onPrimary: Color(0xFF242424),
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: const Color(0xFF242424),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFffc300),
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      controller.text =
                      picked.toIso8601String().split('T')[0];
                    });
                  }
                },
                decoration: _dialogInputDecoration(label),
              );
            } else if (isGender) {
              contentWidget = SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'Male',
                    label: Text(translations['male'] ?? 'Male'),
                    icon: Icon(Icons.male),
                  ),
                  ButtonSegment<String>(
                    value: 'Female',
                    label: Text(translations['female'] ?? 'Female'),
                    icon: Icon(Icons.female),
                  ),
                ],
                selected: {selectedGender},
                onSelectionChanged: (Set<String> newSelection) {
                  setDialogState(() {
                    selectedGender = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a1a1a),
                  foregroundColor: const Color(0xFFffc300),
                  selectedBackgroundColor: const Color(0xFFffc300),
                  selectedForegroundColor: const Color(0xFF242424),
                  side: const BorderSide(color: Color(0xFFffc300)),
                ),
                showSelectedIcon: false,
              );
            } else if (isNumber) {
              contentWidget = NumberPicker(
                value: numberValue,
                minValue: field == 'height' ? 50 : 30,
                maxValue: field == 'height' ? 250 : 200,
                textStyle: const TextStyle(color: Color(0xFFffc300)),
                selectedTextStyle: const TextStyle(
                    color: Color(0xFFffda66), fontSize: 24),
                onChanged: (value) =>
                    setDialogState(() => numberValue = value),
              );
            } else {
              contentWidget = TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFFffc300)),
                cursorColor: const Color(0xFFffc300),
                decoration: _dialogInputDecoration(label),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF242424),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text(
                translations['edit']! + ' $label',
                style: GoogleFonts.bebasNeue(
                    fontSize: 24, color: const Color(0xFFffc300)),
              ),
              content: SingleChildScrollView(
                child: contentWidget,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    translations['cancel']!,
                    style: GoogleFonts.bebasNeue(
                        fontSize: 18, color: const Color(0xFFffc300)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final body = isGender
                        ? {field: selectedGender}
                        : isNumber
                        ? {field: numberValue.toDouble()}
                        : {
                      field: controller.text.isEmpty
                          ? null
                          : controller.text
                    };
                    _updateProfile(body);
                    Navigator.pop(context);
                  },
                  child: Text(
                    translations['save']!,
                    style: GoogleFonts.bebasNeue(
                        fontSize: 18, color: const Color(0xFFffc300)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    return date.split('T')[0];
  }

  Widget _buildAvatar() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFF242424),
            child: _image != null
                ? ClipOval(
                child: Image.file(_image!,
                    width: 120, height: 120, fit: BoxFit.cover))
                : _avatarUrl != null && _avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: '${AuthService.baseUrl}$_avatarUrl',
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                      image: imageProvider, fit: BoxFit.cover),
                ),
              ),
              placeholder: (context, url) =>
              const CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
              ),
              errorWidget: (context, url, error) {
                return const Icon(Icons.person,
                    size: 60, color: Color(0xFFffc300));
              },
            )
                : const Icon(Icons.person,
                size: 60, color: Color(0xFFffc300)),
          ),
          if (!_isOffline)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFffc300),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Color(0xFF242424),
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
      String label, String? value, String field, IconData icon,
      {bool isNumber = false, bool isDate = false, bool isGender = false}) {
    String displayValue = value ?? '-';
    if (isGender && value != null && value.isNotEmpty) {
      displayValue = globalIsPolish.value
          ? Translations.pl[value.toLowerCase()] ?? value
          : Translations.en[value.toLowerCase()] ?? value;
    }
    if (isDate) {
      displayValue = _formatDate(value);
    }
    if (isNumber && value != null && value.isNotEmpty) {
      displayValue =
      '${double.tryParse(value)?.toStringAsFixed(0) ?? '-'} ${field == 'height' ? 'cm' : 'kg'}';
    }

    return Card(
      color: const Color(0xFF242424),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _isOffline ? null : () => _showEditDialog(label, value, field,
            isNumber: isNumber, isDate: isDate, isGender: isGender),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFffc300), size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!_isOffline)
                const Icon(Icons.edit, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineWarning(Map<String, String> translations) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      color: const Color(0xFFffc300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: const Color(0xFF242424), size: 20),
          const SizedBox(width: 10),
          Text(
            translations['offlineReadOnly'] ?? 'Brak połączenia. Tryb tylko do odczytu.',
            style: TextStyle(
              color: const Color(0xFF242424),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
          body: _isInitialLoading
              ? _buildSkeletonLoader()
              : RefreshIndicator(
            onRefresh: _fetchProfile,
            color: const Color(0xFF242424),
            backgroundColor: const Color(0xFFffc300),
            child: Stack(
              children: [
                if (!_isLoading && !_isInitialLoading)
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(0),
                    children: [
                      if (_isOffline) _buildOfflineWarning(translations),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Center(
                              child: Text(
                                translations['profile'] ?? 'Profile',
                                style: GoogleFonts.bebasNeue(
                                    fontSize: 42,
                                    color: const Color(0xFFffc300),
                                    letterSpacing: 1.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildAvatar(),
                            const SizedBox(height: 30),
                            _buildProfileCard(
                              translations['firstName'] ?? 'First Name',
                              _firstName,
                              'firstName',
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 12),
                            _buildProfileCard(
                              translations['lastName'] ?? 'Last Name',
                              _lastName,
                              'lastName',
                              Icons.person,
                            ),
                            const SizedBox(height: 12),
                            _buildProfileCard(
                              translations['birthDate'] ?? 'Birth Date',
                              _birthDate,
                              'birthDate',
                              Icons.calendar_today,
                              isDate: true,
                            ),
                            const SizedBox(height: 12),
                            _buildProfileCard(
                              translations['gender'] ?? 'Gender',
                              _gender,
                              'gender',
                              Icons.wc,
                              isGender: true,
                            ),
                            const SizedBox(height: 12),
                            _buildProfileCard(
                              translations['height'] ?? 'Height (cm)',
                              _height,
                              'height',
                              Icons.height,
                              isNumber: true,
                            ),
                            const SizedBox(height: 12),
                            _buildProfileCard(
                              translations['weight'] ?? 'Weight (kg)',
                              _weight,
                              'weight',
                              Icons.monitor_weight,
                              isNumber: true,
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _logout,
                              icon: const Icon(Icons.logout),
                              label: Text(
                                translations['logout'] ?? 'Logout',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 24,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFffc300)))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 40,
            color: Colors.grey[800],
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[800],
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < 6; i++) ...[
            Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}