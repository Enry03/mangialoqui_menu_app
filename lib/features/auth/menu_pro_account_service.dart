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

  Future<Map<String, dynamic>> _callAllowedEmails({
    required String action,
    required Map<String, dynamic> body,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken.trim();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Nessun utente autenticato');
    }

    final response = await http.post(
      _platformApiUri('/api/prenow/allowed-emails'),
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
      throw Exception('Errore gestione accessi');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Risposta gestione accessi non valida');
  }

  Future<List<Map<String, dynamic>>> loadAllowedEmails({
    required String restaurantId,
  }) async {
    final response = await _client
        .from('restaurant_allowed_emails')
        .select('id, full_name, email, desired_role, created_by, created_at')
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> addAllowedEmail({
    required String restaurantId,
    required String fullName,
    required String email,
  }) async {
    final response = await _callAllowedEmails(
      action: 'add_allowed_email',
      body: {
        'restaurant_id': restaurantId,
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
      },
    );

    if (response['ok'] != true) {
      throw Exception('Errore durante il salvataggio della persona');
    }
  }

  Future<void> removeAllowedEmail({
    required String restaurantId,
    required String email,
  }) async {
    final response = await _callAllowedEmails(
      action: 'remove_allowed_email',
      body: {
        'restaurant_id': restaurantId,
        'email': email.trim().toLowerCase(),
      },
    );

    if (response['ok'] != true) {
      throw Exception('Errore durante la rimozione della persona');
    }
  }

  Future<void> updateAllowedEmailRole({
    required String restaurantId,
    required String email,
    required String desiredRole,
  }) async {
    final response = await _callAllowedEmails(
      action: 'update_allowed_email_role',
      body: {
        'restaurant_id': restaurantId,
        'email': email.trim().toLowerCase(),
        'desired_role': desiredRole.trim().toLowerCase(),
      },
    );

    if (response['ok'] != true) {
      throw Exception('Errore durante il cambio ruolo');
    }
  }
}
