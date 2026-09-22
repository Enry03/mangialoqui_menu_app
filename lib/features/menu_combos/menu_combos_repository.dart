import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_combo.dart';

class ComboItemInput {
  final String menuItemId;
  final int quantity;

  const ComboItemInput({required this.menuItemId, this.quantity = 1});
}

class MenuCombosRepository {
  final SupabaseClient _client;

  MenuCombosRepository(this._client);

  static const String _selectWithItems =
      '*, menu_combo_items(id, quantity, menu_item_id, menu_items(name))';

  Future<List<MenuCombo>> getCombos(
    String menuId, {
    bool includeInactive = false,
  }) async {
    final response = await _client
        .from('menu_combos')
        .select(_selectWithItems)
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final list = response as List;

    final combos = list
        .map((e) => MenuCombo.fromMap(e as Map<String, dynamic>))
        .toList();

    if (includeInactive) {
      return combos;
    }

    return combos.where((combo) => combo.menuComboActive).toList();
  }

  Future<String> createCombo({
    required String menuId,
    required String name,
    String? description,
    required int priceCents,
    required String currency,
    required int sortOrder,
  }) async {
    final inserted = await _client
        .from('menu_combos')
        .insert({
          'menu_id': menuId,
          'name': name,
          'description': description,
          'price_cents': priceCents,
          'currency': currency,
          'sort_order': sortOrder,
          'menu_combo_active': true,
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  Future<void> updateCombo({
    required String id,
    required String name,
    String? description,
    required int priceCents,
    required String currency,
    required int sortOrder,
  }) async {
    await _client
        .from('menu_combos')
        .update({
          'name': name,
          'description': description,
          'price_cents': priceCents,
          'currency': currency,
          'sort_order': sortOrder,
        })
        .eq('id', id);
  }

  Future<void> setComboItems({
    required String comboId,
    required List<ComboItemInput> items,
  }) async {
    await _client.from('menu_combo_items').delete().eq('combo_id', comboId);

    if (items.isEmpty) {
      return;
    }

    await _client
        .from('menu_combo_items')
        .insert([
          for (final item in items)
            {
              'combo_id': comboId,
              'menu_item_id': item.menuItemId,
              'quantity': item.quantity,
            },
        ]);
  }

  Future<void> setComboActive({
    required String id,
    required bool isActive,
  }) async {
    await _client
        .from('menu_combos')
        .update({'menu_combo_active': isActive})
        .eq('id', id);
  }

  Future<void> deactivateCombo(String id) async {
    await setComboActive(id: id, isActive: false);
  }

  Future<void> reactivateCombo(String id) async {
    await setComboActive(id: id, isActive: true);
  }

  Future<void> deleteAllForMenu(String menuId) async {
    await _client.from('menu_combos').delete().eq('menu_id', menuId);
  }
}
