import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8085/api/v1';

  static Future<Map<String, dynamic>> login(String email, String password) async {
  try {
  final res = await http.post(
  Uri.parse('$baseUrl/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'email': email, 'password': password}),
  );
  if (res.statusCode == 200) return jsonDecode(res.body);
  return {'error': 'Server returned code ${res.statusCode}: ${res.body}'};
  } catch (e) {
  debugPrint('Login Error: $e');
  return {'error': 'Connection failed: $e. Check CORS settings on Spring Boot backend.'};
  }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
  try {
  final res = await http.post(
  Uri.parse('$baseUrl/auth/register'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'name': name, 'email': email, 'password': password}),
  );
  if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
  return {'error': 'Registration failed (${res.statusCode}): ${res.body}'};
  } catch (e) {
  debugPrint('Register Error: $e');
  return {'error': 'Network error: $e. Verify Spring Boot is running on 8085 with @CrossOrigin allowed.'};
  }
  }

  // Save Board State
  static Future<bool> saveBoard(String token, String boardName, List<Map<String, dynamic>> items, List<Map<String, dynamic>> connections) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/boards'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': boardName,
          'contentJson': jsonEncode({'items': items, 'connections': connections}),
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Save Board Error: $e');
      return false;
    }
  }

  // Load Boards
  static Future<List<dynamic>> fetchUserBoards(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/boards'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (e) {
      debugPrint('Load Boards Error: $e');
    }
    return [];
  }
}
