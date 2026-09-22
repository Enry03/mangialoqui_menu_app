import '../../services/money_service.dart';

class MenuItemVariant {
  final String id;
  final String menuId;
  final String itemId;
  final String label;
  final String iconKey;
  final int priceCents;
  final int sortOrder;
  final bool menuItemVariantActive;

  const MenuItemVariant({
    required this.id,
    required this.menuId,
    required this.itemId,
    required this.label,
    required this.iconKey,
    required this.priceCents,
    required this.sortOrder,
    required this.menuItemVariantActive,
  });

  factory MenuItemVariant.fromMap(Map<String, dynamic> map) {
    return MenuItemVariant(
      id: (map['id'] ?? '').toString(),
      menuId: (map['menu_id'] ?? '').toString(),
      itemId: (map['item_id'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      iconKey: (map['icon_key'] as String?) ?? 'restaurant_menu',
      priceCents: MoneyService.centsFromDynamic(map['price_cents']),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      menuItemVariantActive: map['menu_item_variant_active'] as bool? ?? true,
    );
  }

  String get formattedPrice {
    return MoneyService.centsToEuroText(priceCents);
  }
}
