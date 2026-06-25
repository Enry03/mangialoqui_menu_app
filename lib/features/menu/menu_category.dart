class MenuCategory {
  final String id;
  final String menuId;
  final String name;
  final int sortOrder;
  final DateTime? createdAt;

  const MenuCategory({
    required this.id,
    required this.menuId,
    required this.name,
    required this.sortOrder,
    this.createdAt,
  });

  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      id: (map['id'] ?? '').toString(),
      menuId: (map['menu_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
