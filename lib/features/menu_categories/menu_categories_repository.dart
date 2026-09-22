import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_category.dart';

class MenuCategoriesRepository {
  final SupabaseClient _client;

  MenuCategoriesRepository(this._client);

  Future<List<MenuCategory>> getCategories(
    String menuId, {
    bool includeInactive = false,
  }) async {
    final response = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final list = response as List;

    final categories = list
        .map((e) => MenuCategory.fromMap(e as Map<String, dynamic>))
        .toList();

    if (includeInactive) {
      return categories;
    }

    return categories.where((category) => category.menuCategoryActive).toList();
  }

  Future<void> createCategory({
    required String menuId,
    required String name,
    required String iconKey,
    required int sortOrder,
  }) async {
    await _client.from('menu_categories').insert({
      'menu_id': menuId,
      'name': name,
      'icon_key': iconKey,
      'sort_order': sortOrder,
      'menu_category_active': true,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String iconKey,
    required int sortOrder,
  }) async {
    await _client
        .from('menu_categories')
        .update({
          'name': name,
          'icon_key': iconKey,
          'sort_order': sortOrder,
        })
        .eq('id', id);
  }

  Future<void> setCategoryActive({
    required String id,
    required bool isActive,
  }) async {
    await _client
        .from('menu_categories')
        .update({'menu_category_active': isActive})
        .eq('id', id);
  }

  Future<void> deactivateCategory(String id) async {
    await setCategoryActive(id: id, isActive: false);
  }

  Future<void> reactivateCategory(String id) async {
    await setCategoryActive(id: id, isActive: true);
  }

  Future<void> deleteAllForMenu(String menuId) async {
    await _client.from('menu_categories').delete().eq('menu_id', menuId);
  }
}
