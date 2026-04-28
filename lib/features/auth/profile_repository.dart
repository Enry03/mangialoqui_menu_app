import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<Profile> getCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Nessun utente autenticato');
    }

    developer.log('AUTH USER ID: ${user.id}');
    developer.log('AUTH USER EMAIL: ${user.email}');

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .limit(1);

    final list = response as List;

    developer.log('PROFILE COUNT: ${list.length}');

    if (list.isEmpty) {
      throw Exception(
        'Profilo utente non trovato. Crea una riga in profiles con id uguale allo user id autenticato.',
      );
    }

    final profile = Profile.fromMap(list.first as Map<String, dynamic>);
    developer.log('PROFILE RESTAURANT ID: ${profile.restaurantId}');

    return profile;
  }
}
