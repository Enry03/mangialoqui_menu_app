import 'package:supabase_flutter/supabase_flutter.dart';

import 'restaurant.dart';

class RestaurantRepository {
  final SupabaseClient _client;

  RestaurantRepository(this._client);

  Future<List<Restaurant>> getRestaurantsByIds(
    Iterable<String> restaurantIds,
  ) async {
    final ids = restaurantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) {
      return const [];
    }

    final response = await _client
        .from('restaurants')
        .select(
          'id, name, slug, default_menu_id, owner_user_id, has_menu_pro, '
          'google_review_url',
        )
        .inFilter('id', ids);

    final list = response as List;
    return list
        .map((row) => Restaurant.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateGoogleReviewUrl({
    required String restaurantId,
    required String? googleReviewUrl,
  }) async {
    await _client
        .from('restaurants')
        .update({'google_review_url': googleReviewUrl})
        .eq('id', restaurantId);
  }
}
