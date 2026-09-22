import '../../services/money_service.dart';

class MenuComboItemRef {
  final String id;
  final String menuItemId;
  final String itemName;
  final int quantity;

  const MenuComboItemRef({
    required this.id,
    required this.menuItemId,
    required this.itemName,
    required this.quantity,
  });

  factory MenuComboItemRef.fromMap(Map<String, dynamic> map) {
    final nestedItem = map['menu_items'];
    final itemName = nestedItem is Map<String, dynamic>
        ? (nestedItem['name'] as String? ?? '')
        : '';

    return MenuComboItemRef(
      id: (map['id'] ?? '').toString(),
      menuItemId: (map['menu_item_id'] ?? '').toString(),
      itemName: itemName,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class MenuCombo {
  final String id;
  final String menuId;
  final String name;
  final String? description;
  final int priceCents;
  final String currency;
  final int sortOrder;
  final bool menuComboActive;
  final List<MenuComboItemRef> items;

  const MenuCombo({
    required this.id,
    required this.menuId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.sortOrder,
    required this.menuComboActive,
    required this.items,
  });

  factory MenuCombo.fromMap(Map<String, dynamic> map) {
    final rawItems = map['menu_combo_items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(MenuComboItemRef.fromMap)
              .toList()
        : <MenuComboItemRef>[];

    return MenuCombo(
      id: (map['id'] ?? '').toString(),
      menuId: (map['menu_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: map['description']?.toString(),
      priceCents: MoneyService.centsFromDynamic(map['price_cents']),
      currency: (map['currency'] ?? 'EUR').toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      menuComboActive: map['menu_combo_active'] as bool? ?? true,
      items: items,
    );
  }

  String get formattedPrice {
    return MoneyService.centsToEuroText(priceCents);
  }
}
