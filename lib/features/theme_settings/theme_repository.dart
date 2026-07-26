import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme_model.dart';

class ThemeRepository {
  final SupabaseClient _client;

  ThemeRepository(this._client);

  Future<ThemeModel?> getThemeForRestaurant(String restaurantId) async {
    final response = await _client
        .from('themes')
        .select()
        .eq('restaurant_id', restaurantId)
        .limit(1);

    if ((response as List).isEmpty) {
      return null;
    }

    return ThemeModel.fromMap(response.first);
  }
}
