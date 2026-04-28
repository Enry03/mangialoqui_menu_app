import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/profile.dart';
import 'restaurant.dart';

class RestaurantRepository {
  final SupabaseClient _client;

  RestaurantRepository(this._client);

  Future<Restaurant> getRestaurantForProfile(Profile profile) async {
    final response = await _client
        .from('restaurants')
        .select()
        .eq('id', profile.restaurantId)
        .limit(1);

    final list = response as List;

    if (list.isEmpty) {
      throw Exception(
        'Ristorante non trovato. Controlla il restaurant_id nel profilo utente.',
      );
    }

    return Restaurant.fromMap(list.first as Map<String, dynamic>);
  }
}
