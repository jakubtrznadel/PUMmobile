import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../language_state.dart';

class AuthService {
  static const String baseUrl = 'https://192.168.0.161:7114';

  IOClient _createClient() {
    final httpClient = HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    httpClient.connectionTimeout = Duration(seconds: 2);
    return IOClient(httpClient);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final client = _createClient();
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
          'message': data['message'] ?? (globalIsPolish.value ? 'Błąd logowania: ${response.statusCode}' : 'Login failed: ${response.statusCode}')
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': globalIsPolish.value ? 'Błąd połączenia z serwerem: $e' : 'Failed to connect to the server: $e'
      };
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final client = _createClient();
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
          'message': data['message'] ?? (globalIsPolish.value ? 'Błąd rejestracji: ${response.statusCode}' : 'Registration failed: ${response.statusCode}')
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': globalIsPolish.value ? 'Błąd połączenia z serwerem: $e' : 'Failed to connect to the server: $e'
      };
    } finally {
      client.close();
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> logoutAndClearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<List<dynamic>> getUserActivities() async {
    final token = await getToken();
    final client = _createClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          data.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
          return data;
        }
        return [];
      } else {
        throw Exception(globalIsPolish.value ? 'Błąd pobierania aktywności' : 'Failed to load activities');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia przy pobieraniu aktywności' : 'Connection error when loading activities');
    } finally {
      client.close();
    }
  }

  Future<dynamic> getActivity(int id) async {
    final token = await getToken();
    final client = _createClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(globalIsPolish.value ? 'Nie znaleziono aktywności' : 'Activity not found');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    } finally {
      client.close();
    }
  }

  Future<int?> createActivity(Map<String, dynamic> activity) async {
    final token = await getToken();
    final client = _createClient();
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
        throw Exception('Błąd serwera (status ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Nie udało się utworzyć aktywności. Sprawdź konsolę debugowania po szczegóły.');
    } finally {
      client.close();
    }
  }

  Future<void> updateActivity(int id, dynamic activity) async {
    final token = await getToken();
    final client = _createClient();
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
        throw Exception(globalIsPolish.value ? 'Błąd aktualizacji aktywności' : 'Failed to update activity');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    } finally {
      client.close();
    }
  }

  Future<void> uploadActivityPhoto(int activityId, File file) async {
    final token = await getToken();
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/activities/$activityId/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      final streamedResponse = await request.send().timeout(Duration(seconds: 2));
      if (streamedResponse.statusCode != 200) {
        throw Exception(globalIsPolish.value ? 'Błąd wgrywania zdjęcia: ${streamedResponse.statusCode}' : 'Failed to upload photo: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia przy wgrywaniu zdjęcia' : 'Connection error when uploading photo');
    }
  }

  Future<void> deleteActivity(int id) async {
    final token = await getToken();
    final client = _createClient();
    try {
      final response = await client.delete(
        Uri.parse('$baseUrl/api/activities/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(globalIsPolish.value ? 'Błąd usuwania aktywności' : 'Failed to delete activity');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    } finally {
      client.close();
    }
  }

  Future<dynamic> getUserStats() async {
    final token = await getToken();
    final client = _createClient();
    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(globalIsPolish.value ? 'Błąd pobierania statystyk' : 'Failed to load stats');
      }
    } catch (e) {
      throw Exception(globalIsPolish.value ? 'Błąd połączenia' : 'Connection error');
    } finally {
      client.close();
    }
  }
}