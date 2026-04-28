class MenuModel {
  final String id;
  final String restaurantId;
  final String name;
  final String? renderMode;
  final bool isPublished;
  final String? defaultLanguage;
  final String? svgAssetPath;
  final String? draftVersionId;
  final String? publishedVersionId;

  MenuModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.renderMode,
    required this.isPublished,
    required this.defaultLanguage,
    required this.svgAssetPath,
    required this.draftVersionId,
    required this.publishedVersionId,
  });

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      name: map['name'] as String? ?? '',
      renderMode: map['render_mode'] as String?,
      isPublished: map['is_published'] as bool? ?? false,
      defaultLanguage: map['default_language'] as String?,
      svgAssetPath: map['svg_asset_path'] as String?,
      draftVersionId: map['draft_version_id'] as String?,
      publishedVersionId: map['published_version_id'] as String?,
    );
  }
}
