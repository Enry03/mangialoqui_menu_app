import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurant/restaurant.dart';
import 'menu.dart';

class MenuRepository {
  final SupabaseClient _client;

  MenuRepository(this._client);

  Future<MenuModel> getCurrentMenu(Restaurant restaurant) async {
    developer.log('CURRENT RESTAURANT ID: ${restaurant.id}');
    developer.log('CURRENT RESTAURANT NAME: ${restaurant.name}');
    developer.log('CURRENT DEFAULT MENU ID: ${restaurant.defaultMenuId}');

    if (restaurant.defaultMenuId != null) {
      final response = await _client
          .from('menus')
          .select()
          .eq('id', restaurant.defaultMenuId!)
          .limit(1);

      final list = response as List;

      developer.log('MENU BY DEFAULT_MENU_ID COUNT: ${list.length}');

      if (list.isNotEmpty) {
        return MenuModel.fromMap(list.first as Map<String, dynamic>);
      }
    }

    final fallbackResponse = await _client
        .from('menus')
        .select()
        .eq('restaurant_id', restaurant.id)
        .order('created_at', ascending: true)
        .limit(1);

    final fallbackList = fallbackResponse as List;

    developer.log('MENU BY RESTAURANT_ID COUNT: ${fallbackList.length}');

    if (fallbackList.isEmpty) {
      throw Exception(
        'Nessun menu trovato per questo ristorante. Crea almeno una riga nella tabella menus.',
      );
    }

    return MenuModel.fromMap(fallbackList.first as Map<String, dynamic>);
  }
}
