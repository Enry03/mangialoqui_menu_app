import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_category.dart';

class MenuCategoriesRepository {
  final SupabaseClient _client;

  MenuCategoriesRepository(this._client);

  Future<List<MenuCategory>> getCategories(String menuId) async {
    final response = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final list = response as List;

    return list
        .map((e) => MenuCategory.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory({
    required String menuId,
    required String name,
    required int sortOrder,
  }) async {
    await _client.from('menu_categories').insert({
      'menu_id': menuId,
      'name': name,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required int sortOrder,
  }) async {
    await _client
        .from('menu_categories')
        .update({'name': name, 'sort_order': sortOrder})
        .eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('menu_categories').delete().eq('id', id);
  }
}
