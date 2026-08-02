class MenuCategory {
  final String id;
  final String menuId;
  final String name;
  final String iconKey;
  final int sortOrder;
  final bool menuCategoryActive;
  final DateTime? createdAt;

  const MenuCategory({
    required this.id,
    required this.menuId,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
    required this.menuCategoryActive,
    this.createdAt,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: map['id'] as String,
      menuId: map['menu_id'] as String,
      name: map['name'] as String,
      iconKey: map['icon_key'] as String? ?? 'restaurant_menu',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      menuCategoryActive: map['menu_category_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
