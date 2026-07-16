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

  Future<void> claimAccessFromAllowedEmail() async {
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
        'action': 'claim_access_from_email',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore collegamento account: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Risposta account non valida');
    }
  }
}