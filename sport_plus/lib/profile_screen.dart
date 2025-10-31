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
  String? _firstName;
  String? _lastName;
  String? _birthDate;
  String? _gender;
  String? _height;
  String? _weight;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  File? _image;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _fetchProfile();
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
    print('Loaded from cache: firstName=$_firstName, gender=$_gender, avatarUrl=$_avatarUrl');
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
    });
    final startTime = DateTime.now();

    final token = await _authService.getToken();
    final client = IOClient(HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true);
    try {
      final response = await client.get(
        Uri.parse('${AuthService.baseUrl}/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Profile fetched: gender=${data['gender']}, avatarUrl=${data['avatarUrl']}');
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
        print('Fetch profile failed: status=${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(globalIsPolish.value ? 'Błąd pobierania profilu' : 'Failed to load profile')),
        );
      }
    } catch (e) {
      print('Fetch profile error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      client.close();
      print('Fetch profile time: ${DateTime.now().difference(startTime).inMilliseconds} ms');
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> body) async {
    setState(() {
      _isLoading = true;
    });

    final token = await _authService.getToken();
    final client = IOClient(HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true);
    try {
      print('Updating profile with body: $body');
      final response = await client.put(
        Uri.parse('${AuthService.baseUrl}/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(globalIsPolish.value ? 'Zaktualizowano!' : 'Updated!')),
        );
        await _fetchProfile();
      } else {
        print('Update profile failed: status=${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(globalIsPolish.value ? 'Błąd aktualizacji' : 'Update failed')),
        );
      }
    } catch (e) {
      print('Update profile error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      client.close();
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: globalIsPolish.value ? 'Dopasuj zdjęcie' : 'Adjust Photo',
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
      final client = IOClient(HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true);
      try {
        var request = http.MultipartRequest('POST', Uri.parse('${AuthService.baseUrl}/api/profile/avatar'));
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _avatarUrl = data['avatarUrl'];
            _image = null;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('avatarUrl', data['avatarUrl'] ?? '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(globalIsPolish.value ? 'Avatar zaktualizowany!' : 'Avatar updated!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(globalIsPolish.value ? 'Błąd wgrywania avatara' : 'Avatar upload failed')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
        client.close();
      }
    } catch (e) {
      if (e.toString().contains('already_active')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(globalIsPolish.value ? 'Galeria już otwarta, spróbuj ponownie' : 'Gallery already open, try again')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(globalIsPolish.value ? 'Błąd podczas wybierania zdjęcia' : 'Error picking image')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logoutAndClearData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
  }

  Future<void> _showEditDialog(String label, String? currentValue, String field, {bool isNumber = false, bool isDate = false, bool isGender = false}) async {
    final controller = TextEditingController(text: currentValue);
    String selectedGender = currentValue?.isEmpty ?? true ? 'Male' : currentValue!;
    int numberValue = (isNumber && currentValue != null && currentValue.isNotEmpty) ? int.parse(currentValue) : (field == 'height' ? 150 : 70);

    await showDialog(
      context: context,
      builder: (context) {
        final translations = globalIsPolish.value ? Translations.pl : Translations.en;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a1a),
              title: Text(
                translations['edit']! + ' $label',
                style: GoogleFonts.bebasNeue(fontSize: 24, color: const Color(0xFFffc300)),
              ),
              content: isDate
                  ? TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFFffc300)),
                cursorColor: const Color(0xFFffc300),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      controller.text = picked.toIso8601String().split('T')[0];
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Color(0xFFffc300)),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFffc300))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFffda66), width: 2)),
                ),
              )
                  : isGender
                  ? DropdownButton<String>(
                value: ['Male', 'Female'].contains(selectedGender) ? selectedGender : 'Male',
                items: [
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text(translations['male']!, style: const TextStyle(color: Color(0xFFffc300))),
                  ),
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text(translations['female']!, style: const TextStyle(color: Color(0xFFffc300))),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    selectedGender = value ?? 'Male';
                  });
                  print('Gender changed to: $selectedGender');
                },
                dropdownColor: const Color(0xFF1a1a1a),
                style: const TextStyle(color: Color(0xFFffc300)),
                isExpanded: true,
              )
                  : isNumber
                  ? NumberPicker(
                value: numberValue,
                minValue: field == 'height' ? 50 : 30,
                maxValue: field == 'height' ? 250 : 200,
                textStyle: const TextStyle(color: Color(0xFFffc300)),
                selectedTextStyle: const TextStyle(color: Color(0xFFffda66), fontSize: 24),
                onChanged: (value) => setDialogState(() => numberValue = value),
              )
                  : TextField(
                controller: controller,
                style: const TextStyle(color: Color(0xFFffc300)),
                cursorColor: const Color(0xFFffc300),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Color(0xFFffc300)),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFffc300))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFffda66), width: 2)),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    translations['cancel']!,
                    style: GoogleFonts.bebasNeue(fontSize: 18, color: const Color(0xFFffc300)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final body = isGender
                        ? {field: selectedGender}
                        : isNumber
                        ? {field: numberValue.toDouble()}
                        : {field: controller.text.isEmpty ? null : controller.text};
                    _updateProfile(body);
                    Navigator.pop(context);
                  },
                  child: Text(
                    translations['save']!,
                    style: GoogleFonts.bebasNeue(fontSize: 18, color: const Color(0xFFffc300)),
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
    return GestureDetector(
      onTap: _pickAndUploadAvatar,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: const Color(0xFF242424),
        child: _image != null
            ? ClipOval(child: Image.file(_image!, fit: BoxFit.cover))
            : _avatarUrl != null && _avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: '${AuthService.baseUrl}$_avatarUrl',
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          placeholder: (context, url) => const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300)),
          ),
          errorWidget: (context, url, error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(globalIsPolish.value ? 'Błąd ładowania avatara' : 'Failed to load avatar')),
            );
            return const Icon(Icons.error, size: 50, color: Color(0xFFffc300));
          },
        )
            : const Icon(Icons.camera_alt, size: 50, color: Color(0xFFffc300)),
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
              : _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFffc300))))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(translations['profile'] ?? 'Profile', style: GoogleFonts.bebasNeue(fontSize: 36, color: const Color(0xFFffc300))),
                const SizedBox(height: 20),
                _buildAvatar(),
                const SizedBox(height: 10),
                Text(translations['avatar'] ?? 'Change avatar', style: const TextStyle(color: Color(0xFFffc300))),
                const SizedBox(height: 20),
                _buildInfoRow(translations['firstName'] ?? 'First Name', _firstName, 'firstName'),
                const SizedBox(height: 16),
                _buildInfoRow(translations['lastName'] ?? 'Last Name', _lastName, 'lastName'),
                const SizedBox(height: 16),
                _buildInfoRow(translations['birthDate'] ?? 'Birth Date', _formatDate(_birthDate), 'birthDate', isDate: true),
                const SizedBox(height: 16),
                _buildInfoRow(
                  translations['gender'] ?? 'Gender',
                  _gender?.isEmpty ?? true ? '-' : translations[_gender!.toLowerCase()] ?? '-',
                  'gender',
                  isGender: true,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(translations['height'] ?? 'Height (cm)', _height, 'height', isNumber: true),
                const SizedBox(height: 16),
                _buildInfoRow(translations['weight'] ?? 'Weight (kg)', _weight, 'weight', isNumber: true),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: _buttonStyle(),
                  onPressed: _logout,
                  child: Text(translations['logout'] ?? 'Logout'),
                ),
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
        children: [
          Container(
            width: double.infinity,
            height: 36,
            color: Colors.grey[800],
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[800],
          ),
          const SizedBox(height: 10),
          Container(
            width: 100,
            height: 16,
            color: Colors.grey[800],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < 6; i++) ...[
            Container(
              width: double.infinity,
              height: 20,
              color: Colors.grey[800],
            ),
            const SizedBox(height: 16),
          ],
          Container(
            width: 120,
            height: 40,
            color: Colors.grey[800],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, String field, {bool isNumber = false, bool isDate = false, bool isGender = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '$label: ${value ?? '-'}',
            style: GoogleFonts.bebasNeue(fontSize: 20, color: const Color(0xFFffc300)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFFffc300)),
          onPressed: () => _showEditDialog(label, value, field, isNumber: isNumber, isDate: isDate, isGender: isGender),
        ),
      ],
    );
  }

  ButtonStyle _buttonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => states.contains(WidgetState.pressed) ? const Color(0xFFffda66) : const Color(0xFFffc300)),
      foregroundColor: WidgetStateProperty.all(const Color(0xFF242424)),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
      textStyle: WidgetStateProperty.all(GoogleFonts.bebasNeue(fontSize: 24, fontWeight: FontWeight.w600)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      elevation: WidgetStateProperty.resolveWith<double>((states) => states.contains(WidgetState.pressed) ? 4 : 8),
      shadowColor: WidgetStateProperty.all(Colors.black26),
    );
  }
}