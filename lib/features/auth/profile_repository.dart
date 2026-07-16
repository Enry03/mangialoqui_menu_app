import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<Profile?> findCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Nessun utente autenticato');
    }

    developer.log('AUTH USER ID: ${user.id}');
    developer.log('AUTH USER EMAIL: ${user.email}');

    final response = await _client
        .from('profiles')
        .select('id, restaurant_id, role')
        .eq('id', user.id)
        .eq('is_hired', true)
        .limit(1);

    final list = response as List;

    developer.log('PROFILE COUNT: ${list.length}');

    if (list.isEmpty) {
      return null;
    }

    final profile = Profile.fromMap(list.first as Map<String, dynamic>);
    developer.log('PROFILE RESTAURANT ID: ${profile.restaurantId}');
    developer.log('PROFILE ROLE: ${profile.role}');

    return profile;
  }

  Future<Profile> getCurrentProfile() async {
    final profile = await findCurrentProfile();

    if (profile == null) {
      throw Exception(
        'Il tuo account non è collegato a nessun ristorante autorizzato.',
      );
    }

    return profile;
  }
}
