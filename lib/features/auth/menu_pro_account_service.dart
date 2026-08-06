import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuProAccountService {
  final SupabaseClient _client;

  MenuProAccountService(this._client);

  static const String _platformBaseUrl = String.fromEnvironment(
    'MANGIALOQUI_PLATFORM_BASE_URL',
    defaultValue: 'https://www.mangialoqui.it',
  );

  static Uri _platformApiUri(String path) {
    final base = _platformBaseUrl.endsWith('/')
        ? _platformBaseUrl.substring(0, _platformBaseUrl.length - 1)
        : _platformBaseUrl;

    return Uri.parse('$base$path');
  }

  Future<Map<String, dynamic>> _callAccount({
    required String action,
    required Map<String, dynamic> body,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken.trim();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Nessun utente autenticato');
    }

    final response = await http.post(
      _platformApiUri('/api/prenow/account'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'action': action,
        ...body,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore account Menu Pro: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Risposta account Menu Pro non valida');
  }

  Future<void> claimAccessFromAllowedEmail() async {
    await _callAccount(
      action: 'claim_access_from_email',
      body: const {},
    );
  }

  Future<Map<String, dynamic>> createMenuProRestaurant({
    required String name,
    required String slug,
  }) {
    return _callAccount(
      action: 'create_menu_pro_restaurant',
      body: {
        'name': name.trim(),
        'slug': slug.trim().toLowerCase(),
        'service_mode': 'both',
        'double_lunch': false,
        'double_dinner': false,
        'total_capacity': null,
      },
    );
  }
}
