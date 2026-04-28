import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurant/restaurant.dart';
import '../menu/menu.dart';

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
    // calcola prossimo numero versione
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

    final insertResponse = await _client
        .from('menu_versions')
        .insert({
          'restaurant_id': restaurant.id,
          'menu_id': menu.id,
          'version_number': nextNumber,
          'label': label,
          'is_published': false,
        })
        .select('id, version_number, label, is_published, created_at')
        .limit(1);

    final insertList = insertResponse as List;

    return MenuVersion.fromMap(insertList.first as Map<String, dynamic>);
  }

  Future<void> publishVersion({
    required MenuModel menu,
    required String versionId,
  }) async {
    // metti tutte le versioni is_published = false per questo menu
    await _client
        .from('menu_versions')
        .update({'is_published': false})
        .eq('menu_id', menu.id);

    // marca la versione scelta come pubblicata
    await _client
        .from('menu_versions')
        .update({'is_published': true})
        .eq('id', versionId);

    // aggiorna puntatore nel menu
    await _client
        .from('menus')
        .update({'current_version_id': versionId})
        .eq('id', menu.id);
  }
}
