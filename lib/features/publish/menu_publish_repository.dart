import 'package:supabase_flutter/supabase_flutter.dart';

import '../menu/menu.dart';
import '../restaurant/restaurant.dart';

class MenuVersion {
  final String id;
  final int versionNumber;
  final String? label;
  final bool isPublished;
  final DateTime createdAt;

  MenuVersion({
    required this.id,
    required this.versionNumber,
    required this.label,
    required this.isPublished,
    required this.createdAt,
  });

  factory MenuVersion.fromMap(Map<String, dynamic> map) {
    return MenuVersion(
      id: map['id'] as String,
      versionNumber: (map['version_number'] as num).toInt(),
      label: map['label'] as String?,
      isPublished: map['is_published'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class MenuPublishRepository {
  final SupabaseClient _client;

  MenuPublishRepository(this._client);

  Future<List<MenuVersion>> getVersions(MenuModel menu) async {
    final response = await _client
        .from('menu_versions')
        .select()
        .eq('menu_id', menu.id)
        .order('version_number', ascending: false);

    final list = response as List;

    return list
        .map((e) => MenuVersion.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuVersion> createDraftVersion({
    required Restaurant restaurant,
    required MenuModel menu,
    String? label,
  }) async {
    final maxResponse = await _client
        .from('menu_versions')
        .select('version_number')
        .eq('menu_id', menu.id)
        .order('version_number', ascending: false)
        .limit(1);

    final maxList = maxResponse as List;
    final nextNumber = maxList.isEmpty
        ? 1
        : ((maxList.first['version_number'] as num).toInt() + 1);

    final categoriesResponse = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menu.id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final itemsResponse = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menu.id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final appearanceResponse = await _client
        .from('menu_appearance')
        .select()
        .eq('restaurant_id', restaurant.id)
        .maybeSingle();

    final snapshot = <String, dynamic>{
      'restaurant': {
        'id': restaurant.id,
        'name': restaurant.name,
        'slug': restaurant.slug,
      },
      'menu': {
        'id': menu.id,
        'restaurant_id': menu.restaurantId,
        'name': menu.name,
      },
      'categories': (categoriesResponse as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      'items': (itemsResponse as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      'appearance': appearanceResponse == null
          ? null
          : Map<String, dynamic>.from(appearanceResponse as Map),
    };

    final insertResponse = await _client
        .from('menu_versions')
        .insert({
          'restaurant_id': restaurant.id,
          'menu_id': menu.id,
          'version_number': nextNumber,
          'label': label,
          'is_published': false,
          'data': snapshot,
        })
        .select('id, version_number, label, is_published, created_at')
        .single();

    return MenuVersion.fromMap(insertResponse);
  }

  Future<void> publishVersion({
    required MenuModel menu,
    required String versionId,
  }) async {
    await _client
        .from('menu_versions')
        .update({'is_published': false})
        .eq('menu_id', menu.id);

    await _client
        .from('menu_versions')
        .update({'is_published': true})
        .eq('id', versionId);

    await _client
        .from('menus')
        .update({'current_version_id': versionId})
        .eq('id', menu.id);
  }
}
