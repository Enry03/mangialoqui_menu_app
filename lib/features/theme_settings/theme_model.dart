class ThemeModel {
  final String id;
  final String restaurantId;
  final String? templateKey;
  final String? logoPath;
  final String? primaryColor;
  final String? secondaryColor;
  final String? fontKey;

  ThemeModel({
    required this.id,
    required this.restaurantId,
    required this.templateKey,
    required this.logoPath,
    required this.primaryColor,
    required this.secondaryColor,
    required this.fontKey,
  });

  factory ThemeModel.fromMap(Map<String, dynamic> map) {
    return ThemeModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      templateKey: map['template_key'] as String?,
      logoPath: map['logo_path'] as String?,
      primaryColor: map['primary_color'] as String?,
      secondaryColor: map['secondary_color'] as String?,
      fontKey: map['font_key'] as String?,
    );
  }
}
