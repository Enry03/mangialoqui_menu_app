class Restaurant {
  final String id;
  final String name;
  final String slug;
  final String? defaultMenuId;
  final String? ownerUserId;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    required this.defaultMenuId,
    required this.ownerUserId,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      defaultMenuId: map['default_menu_id'] as String?,
      ownerUserId: map['owner_user_id'] as String?,
    );
  }
}
