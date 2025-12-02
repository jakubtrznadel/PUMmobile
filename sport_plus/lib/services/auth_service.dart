import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../language_state.dart';

class AuthService {
  static const String baseUrl = 'https://www.sportplusproject.pl.hostingasp.pl';

  IOClient? _client;

  IOClient _getClient() {
    if (_client == null) {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      httpClient.connectionTimeout = Duration(seconds: 10);
      _client = IOClient(httpClient);
    }
    return _client!;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final client = _getClient();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);
        return {'success': true, 'token': data['token']};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ??
              (globalIsPolish.value
                  ? 'Błąd logowania: ${response.statusCode}'
                  : 'Login failed: ${response.statusCode}')
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': globalIsPolish.value
            ? 'Błąd połączenia z serwerem: $e'
            : 'Failed to connect to the server: $e'
      };
    }
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final client = _getClient();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'message': data['message']};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ??
              (globalIsPolish.value
                  ? 'Błąd rejestracji: ${response.statusCode}'
                  : 'Registration failed: ${response.statusCode}')
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': globalIsPolish.value
            ? 'Błąd połączenia z serwerem: $e'
            : 'Failed to connect to the server: $e'
      };
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> logoutAndClearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _client?.close();
    _client = null;
  }

  Future<List<dynamic>> getUserActivities() async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          data.sort((a, b) =>
              DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
          return data;
        }
        return [];
      } else {
        throw Exception(globalIsPolish.value
            ? 'Błąd pobierania aktywności'
            : 'Failed to load activities');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value
          ? 'Błąd połączenia przy pobieraniu aktywności'
          : 'Connection error when loading activities');
    }
  }

  Future<dynamic> getActivity(int id) async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            globalIsPolish.value ? 'Nie znaleziono aktywności' : 'Activity not found');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    }
  }

  Future<int?> createActivity(Map<String, dynamic> activity) async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/activities'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(activity),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          if (response.body.isEmpty) {
            throw Exception('Pusta odpowiedź od serwera.');
          }

          final data = jsonDecode(response.body);

          if (data is Map && data.containsKey('activityId')) {
            return data['activityId'];
          } else {
            throw Exception('Brak klucza "activityId" w odpowiedzi JSON.');
          }
        } catch (e) {
          throw Exception('Błąd przetwarzania odpowiedzi serwera: $e');
        }
      } else {
        throw Exception(
            'Błąd serwera (status ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception(
          'Nie udało się utworzyć aktywności. Sprawdź konsolę debugowania po szczegóły.');
    }
  }

  Future<void> updateActivity(int id, dynamic activity) async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.put(
        Uri.parse('$baseUrl/api/activities/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(activity),
      );

      if (response.statusCode != 200) {
        throw Exception(globalIsPolish.value
            ? 'Błąd aktualizacji aktywności'
            : 'Failed to update activity');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    }
  }

  Future<void> uploadActivityPhoto(int activityId, File file) async {
    final token = await getToken();
    final client = _getClient();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/activities/$activityId/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamedResponse =
      await client.send(request).timeout(Duration(seconds: 10));

      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        throw Exception(globalIsPolish.value
            ? 'Błąd wgrywania zdjęcia: ${streamedResponse.statusCode}, $responseBody'
            : 'Failed to upload photo: ${streamedResponse.statusCode}, $responseBody');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value
          ? 'Błąd połączenia przy wgrywaniu zdjęcia'
          : 'Connection error when uploading photo');
    }
  }

  Future<void> deleteActivity(int id) async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/api/activities/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(globalIsPolish.value
            ? 'Błąd usuwania aktywności'
            : 'Failed to delete activity');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    }
  }

  Future<dynamic> getUserStats() async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities/stats'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            globalIsPolish.value ? 'Błąd pobierania statystyk' : 'Failed to load stats');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    }
  }

  Future<Uint8List> exportActivityToGpx(int activityId) async {
    final token = await getToken();
    final client = _getClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities/$activityId/export/gpx'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception(globalIsPolish.value
            ? 'Nie udało się wyeksportować aktywności do GPX'
            : 'Failed to export activity to GPX');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    }
  }

  Future<List<dynamic>> getRanking(String sortBy) async {
    final client = _getClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities/ranking?sortBy=$sortBy'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        throw Exception(globalIsPolish.value
            ? 'Błąd pobierania rankingu'
            : 'Failed to load ranking');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final client = _getClient();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': globalIsPolish.value ? 'Link wysłany.' : 'Link sent.'
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? (globalIsPolish.value ? 'Błąd' : 'Error')
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
        globalIsPolish.value ? 'Błąd połączenia' : 'Connection error'
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    final client = _getClient();
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message':
          globalIsPolish.value ? 'Hasło zresetowane.' : 'Password reset.'
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? (globalIsPolish.value ? 'Błąd' : 'Error')
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
        globalIsPolish.value ? 'Błąd połączenia' : 'Connection error'
      };
    }
  }
}