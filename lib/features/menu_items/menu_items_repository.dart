import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_item.dart';

class MenuItemsRepository {
  final SupabaseClient _client;

  MenuItemsRepository(this._client);

  Future<List<MenuItemModel>> getItems(
    String menuId, {
    bool includeInactive = false,
  }) async {
    final response = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final list = response as List;

    final items = list
        .map((e) => MenuItemModel.fromMap(e as Map<String, dynamic>))
        .toList();

    if (includeInactive) {
      return items;
    }

    return items.where((item) => item.menuItemActive).toList();
  }

  Future<void> createItem({
    required String menuId,
    required String categoryId,
    required String name,
    String? description,
    required List<String> allergens,
    required int priceCents,
    required String currency,
    required int sortOrder,
  }) async {
    await _client.from('menu_items').insert({
      'menu_id': menuId,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'allergens': MenuAllergen.normalizeList(allergens),
      'price_cents': priceCents,
      'currency': currency,
      'sort_order': sortOrder,
      'is_sold_out': false,
      'menu_item_active': true,
    });
  }

  Future<void> updateItem({
    required String id,
    required String categoryId,
    required String name,
    String? description,
    required List<String> allergens,
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
          'allergens': MenuAllergen.normalizeList(allergens),
          'price_cents': priceCents,
          'currency': currency,
          'sort_order': sortOrder,
          'is_sold_out': isSoldOut,
        })
        .eq('id', id);
  }

  Future<void> updateItemsOrder(
    List<MenuItemModel> orderedItems,
  ) async {
    for (var index = 0; index < orderedItems.length; index++) {
      await _client
          .from('menu_items')
          .update({'sort_order': (index + 1) * 10})
          .eq('id', orderedItems[index].id);
    }
  }

  Future<void> setSoldOut({required String id, required bool isSoldOut}) async {
    await _client
        .from('menu_items')
        .update({'is_sold_out': isSoldOut})
        .eq('id', id);
  }

  Future<void> setItemActive({
    required String id,
    required bool isActive,
  }) async {
    await _client
        .from('menu_items')
        .update({'menu_item_active': isActive})
        .eq('id', id);
  }

  Future<void> deactivateItem(String id) async {
    await setItemActive(id: id, isActive: false);
  }

  Future<void> reactivateItem(String id) async {
    await setItemActive(id: id, isActive: true);
  }
}
