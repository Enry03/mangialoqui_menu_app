class MenuItemModel {
  final String id;
  final String menuId;
  final String categoryId;
  final String name;
  final String? description;
  final int priceCents;
  final String? currency;
  final bool isSoldOut;
  final int sortOrder;

  const MenuItemModel({
    required this.id,
    required this.menuId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.isSoldOut,
    required this.sortOrder,
  });

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: map['id'] as String,
      menuId: map['menu_id'] as String,
      categoryId: map['category_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String?,
      isSoldOut: map['is_sold_out'] as bool? ?? false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedPrice {
    final value = priceCents / 100;
    return '€ ${value.toStringAsFixed(2)}';
  }
}
