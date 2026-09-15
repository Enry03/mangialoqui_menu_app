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

    final restaurantMap = Map<String, dynamic>.from(restaurantResponse);
    final restaurantId = restaurantMap['id'] as String;

    final menuResponse = await _client
        .from('menus')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_published', true)
        .maybeSingle();

    if (menuResponse == null) {
      throw Exception('Menu pubblicato non trovato per il ristorante');
    }

    final menuMap = Map<String, dynamic>.from(menuResponse);
    final menu = MenuModel.fromMap(menuMap);

    final appearanceResponse = await _client
        .from('menu_appearance')
        .select()
        .eq('restaurant_id', restaurantId)
        .maybeSingle();

    final appearance = appearanceResponse == null
        ? null
        : MenuAppearance.fromMap(Map<String, dynamic>.from(appearanceResponse));

    final categoriesResponse = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menu.id)
        .eq('menu_category_active', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final categories = (categoriesResponse as List)
        .map((e) => MenuCategory.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final itemsResponse = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menu.id)
        .eq('menu_item_active', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final items = (itemsResponse as List)
        .map((e) => MenuItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PublicMenuData(
      menu: menu,
      categories: categories,
      items: items,
      appearance: appearance,
    );
  }
}
