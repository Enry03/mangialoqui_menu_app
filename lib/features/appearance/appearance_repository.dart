import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuAppearance {
  final String id;
  final String restaurantId;
  final String fontPreset;
  final String themePreset;
  final bool showLogo;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuAppearance({
    required this.id,
    required this.restaurantId,
    required this.fontPreset,
    required this.themePreset,
    required this.showLogo,
    required this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuAppearance.fromMap(Map<String, dynamic> map) {
    return MenuAppearance(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      fontPreset: map['font_preset'] as String? ?? 'modern',
      themePreset: map['theme_preset'] as String? ?? 'cream',
      showLogo: map['show_logo'] as bool? ?? true,
      logoUrl: map['logo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class AppearanceRepository {
  final SupabaseClient _client;

  AppearanceRepository(this._client);

  Future<MenuAppearance?> getAppearance(String restaurantId) async {
    final response = await _client
        .from('menu_appearance')
        .select()
        .eq('restaurant_id', restaurantId)
        .maybeSingle();

    if (response == null) return null;
    return MenuAppearance.fromMap(response);
  }

  Future<MenuAppearance> ensureAppearance(String restaurantId) async {
    final existing = await getAppearance(restaurantId);
    if (existing != null) return existing;

    final inserted = await _client
        .from('menu_appearance')
        .insert({
          'restaurant_id': restaurantId,
          'font_preset': 'modern',
          'theme_preset': 'cream',
          'show_logo': true,
          'logo_url': null,
        })
        .select()
        .single();

    return MenuAppearance.fromMap(inserted);
  }

  Future<MenuAppearance> updateAppearance({
    required String restaurantId,
    required String fontPreset,
    required String themePreset,
    required bool showLogo,
    required String? logoUrl,
  }) async {
    await ensureAppearance(restaurantId);

    final updated = await _client
        .from('menu_appearance')
        .update({
          'font_preset': fontPreset,
          'theme_preset': themePreset,
          'show_logo': showLogo,
          'logo_url': logoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('restaurant_id', restaurantId)
        .select()
        .single();

    return MenuAppearance.fromMap(updated);
  }

  /// Carica il logo nel bucket **restaurant-logos** (PUBLIC)
  /// e restituisce l'URL pubblico da salvare in logo_url.
  Future<String> uploadLogo({
    required String restaurantId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();

    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';

    final path =
        '$restaurantId/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';

    // Usa il bucket PUBLIC corretto per i loghi
    const bucket = 'restaurant-logos';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFromExtension(extension),
            cacheControl: '3600',
          ),
        );

    // URL pubblico leggibile direttamente da Image.network
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
