import 'package:supabase_flutter/supabase_flutter.dart';

import '../appearance/appearance_repository.dart';
import '../menu/menu.dart';
import '../menu_categories/menu_category.dart';
import '../menu_items/menu_item.dart';

class PublicMenuData {
  final MenuModel menu;
  final List<MenuCategory> categories;
  final List<MenuItemModel> items;
  final MenuAppearance? appearance;

  const PublicMenuData({
    required this.menu,
    required this.categories,
    required this.items,
    required this.appearance,
  });
}

class PublicMenuRepository {
  final SupabaseClient _client;

  PublicMenuRepository(this._client);

  Future<PublicMenuData> loadPublicMenu(String restaurantSlug) async {
    final restaurantResponse = await _client
        .from('restaurants')
        .select('id, name, slug')
        .eq('slug', restaurantSlug)
        .maybeSingle();

    if (restaurantResponse == null) {
      throw Exception('Ristorante non trovato per slug: $restaurantSlug');
    }

    final restaurantId = restaurantResponse['id'] as String;

    final menuResponse = await _client
        .from('menus')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_active', true)
        .maybeSingle();

    if (menuResponse == null) {
      throw Exception('Menu attivo non trovato per il ristorante');
    }

    final menu = MenuModel.fromMap(menuResponse as Map<String, dynamic>);

    final categoriesResponse = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menu.id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final categories = (categoriesResponse as List)
        .map((e) => MenuCategory.fromMap(e as Map<String, dynamic>))
        .toList();

    final itemsResponse = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menu.id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final items = (itemsResponse as List)
        .map((e) => MenuItemModel.fromMap(e as Map<String, dynamic>))
        .toList();

    final appearanceResponse = await _client
        .from('menu_appearance')
        .select()
        .eq('restaurant_id', restaurantId)
        .maybeSingle();

    final appearance = appearanceResponse == null
        ? null
        : MenuAppearance.fromMap(appearanceResponse as Map<String, dynamic>);

    return PublicMenuData(
      menu: menu,
      categories: categories,
      items: items,
      appearance: appearance,
    );
  }
}
