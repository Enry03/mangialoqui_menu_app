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
        .eq('is_active', true)
        .maybeSingle();

    if (menuResponse == null) {
      throw Exception('Menu attivo non trovato per il ristorante');
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

    final snapshotData = await _loadPublishedSnapshot(menu.id, menuMap);

    if (snapshotData != null) {
      final categories = _parseCategories(snapshotData['categories']);
      final items = _parseItems(snapshotData['items']);

      final hasValidSnapshot = categories.isNotEmpty && items.isNotEmpty;

      if (hasValidSnapshot) {
        return PublicMenuData(
          menu: menu,
          categories: categories,
          items: items,
          appearance: appearance,
        );
      }
    }

    final categoriesResponse = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menu.id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final categories = (categoriesResponse as List)
        .map((e) => MenuCategory.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final itemsResponse = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menu.id)
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

  Future<Map<String, dynamic>?> _loadPublishedSnapshot(
    String menuId,
    Map<String, dynamic> menuMap,
  ) async {
    final currentVersionId = menuMap['current_version_id'] as String?;

    if (currentVersionId != null && currentVersionId.isNotEmpty) {
      final currentVersionResponse = await _client
          .from('menu_versions')
          .select('id, data, is_published')
          .eq('id', currentVersionId)
          .maybeSingle();

      if (currentVersionResponse != null) {
        final currentVersionMap = Map<String, dynamic>.from(
          currentVersionResponse,
        );
        final data = currentVersionMap['data'];

        if (data is Map) {
          return Map<String, dynamic>.from(data as Map);
        }
      }
    }

    final publishedVersionResponse = await _client
        .from('menu_versions')
        .select('id, data, is_published, version_number, created_at')
        .eq('menu_id', menuId)
        .eq('is_published', true)
        .order('version_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (publishedVersionResponse == null) {
      return null;
    }

    final publishedVersionMap = Map<String, dynamic>.from(
      publishedVersionResponse,
    );
    final data = publishedVersionMap['data'];

    if (data is Map) {
      return Map<String, dynamic>.from(data as Map);
    }

    return null;
  }

  List<MenuCategory> _parseCategories(dynamic rawCategories) {
    if (rawCategories is! List) {
      return const [];
    }

    final categories = <MenuCategory>[];

    for (final entry in rawCategories) {
      try {
        final map = Map<String, dynamic>.from(entry as Map);
        categories.add(MenuCategory.fromMap(map));
      } catch (_) {}
    }

    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  List<MenuItemModel> _parseItems(dynamic rawItems) {
    if (rawItems is! List) {
      return const [];
    }

    final items = <MenuItemModel>[];

    for (final entry in rawItems) {
      try {
        final map = Map<String, dynamic>.from(entry as Map);
        items.add(MenuItemModel.fromMap(map));
      } catch (_) {}
    }

    items.sort((a, b) {
      final categoryCompare = a.categoryId.compareTo(b.categoryId);
      if (categoryCompare != 0) return categoryCompare;
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return items;
  }
}
