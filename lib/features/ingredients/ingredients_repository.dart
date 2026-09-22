import 'package:supabase_flutter/supabase_flutter.dart';

import 'ingredient.dart';

class IngredientsRepository {
  final SupabaseClient _client;

  IngredientsRepository(this._client);

  Future<List<RestaurantIngredient>> getIngredients(
    String restaurantId,
  ) async {
    final response = await _client
        .from('restaurant_ingredients')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (response as List)
        .map((e) => RestaurantIngredient.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createIngredient({
    required String restaurantId,
    required String name,
    required int sortOrder,
  }) async {
    await _client.from('restaurant_ingredients').insert({
      'restaurant_id': restaurantId,
      'name': name,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateIngredient({
    required String id,
    required String name,
  }) async {
    await _client
        .from('restaurant_ingredients')
        .update({'name': name})
        .eq('id', id);
  }

  Future<void> deleteIngredient(String id) async {
    await _client.from('restaurant_ingredients').delete().eq('id', id);
  }
}
