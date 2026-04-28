import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_item.dart';

class MenuItemsRepository {
  final SupabaseClient _client;

  MenuItemsRepository(this._client);

  Future<List<MenuItemModel>> getItems(String menuId) async {
    final response = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final list = response as List;

    return list
        .map((e) => MenuItemModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createItem({
    required String menuId,
    required String categoryId,
    required String name,
    String? description,
    required int priceCents,
    required String currency,
    required int sortOrder,
  }) async {
    await _client.from('menu_items').insert({
      'menu_id': menuId,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price_cents': priceCents,
      'currency': currency,
      'sort_order': sortOrder,
      'is_sold_out': false,
    });
  }

  Future<void> updateItem({
    required String id,
    required String categoryId,
    required String name,
    String? description,
    required int priceCents,
    required String currency,
    required int sortOrder,
    required bool isSoldOut,
  }) async {
    await _client
        .from('menu_items')
        .update({
          'category_id': categoryId,
          'name': name,
          'description': description,
          'price_cents': priceCents,
          'currency': currency,
          'sort_order': sortOrder,
          'is_sold_out': isSoldOut,
        })
        .eq('id', id);
  }

  Future<void> setSoldOut({required String id, required bool isSoldOut}) async {
    await _client
        .from('menu_items')
        .update({'is_sold_out': isSoldOut})
        .eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('menu_items').delete().eq('id', id);
  }
}
