import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<List<Profile>> findActiveProfiles() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Nessun utente autenticato');
    }

    final response = await _client
        .from('profiles')
        .select('id, restaurant_id, role')
        .eq('id', user.id)
        .eq('is_hired', true);

    final list = response as List;
    return list
        .map((row) => Profile.fromMap(row as Map<String, dynamic>))
        .toList();
  }
}
