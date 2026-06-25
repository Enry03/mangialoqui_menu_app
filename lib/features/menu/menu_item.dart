class MenuItemModel {
  final String id;
  final String menuId;
  final String categoryId;
  final String name;
  final String? description;
  final int priceCents;
  final String currency;
  final bool isSoldOut;
  final int sortOrder;
  final DateTime? createdAt;

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
    required this.createdAt,
  });

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: (map['id'] ?? '').toString(),
      menuId: (map['menu_id'] ?? '').toString(),
      categoryId: (map['category_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: map['description']?.toString(),
      priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] ?? 'EUR').toString(),
      isSoldOut: map['is_sold_out'] == true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  String get formattedPrice {
    final value = (priceCents / 100).toStringAsFixed(2);
    return '€ $value';
  }
}
