import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../menu/menu.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';
import 'appearance_provider.dart';
import 'appearance_repository.dart';

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  String? _selectedFont;
  String? _selectedTheme;
  bool? _showLogo;
  String? _logoUrl;
  bool _saving = false;

  static const _fontOptions = <_FontOption>[
    _FontOption(
      key: 'modern',
      label: 'Moderno',
      description: 'Pulito e contemporaneo.',
    ),
    _FontOption(
      key: 'elegant',
      label: 'Elegante',
      description: 'Più raffinato e curato.',
    ),
    _FontOption(
      key: 'classic',
      label: 'Classico',
      description: 'Tradizionale e affidabile.',
    ),
    _FontOption(
      key: 'compact',
      label: 'Compatto',
      description: 'Più denso e diretto.',
    ),
  ];

  static const _themeOptions = <_ThemeOption>[
    _ThemeOption(
      key: 'cream',
      label: 'Cream',
      background: Color(0xFFF7F1E8),
      surface: Colors.white,
      text: Color(0xFF1E1A17),
      accent: Color(0xFFB98952),
    ),
    _ThemeOption(
      key: 'dark',
      label: 'Dark',
      background: Color(0xFF141414),
      surface: Color(0xFF1F1F1F),
      text: Color(0xFFF5F5F5),
      accent: Color(0xFFD7A86E),
    ),
    _ThemeOption(
      key: 'forest',
      label: 'Forest',
      background: Color(0xFFF4F6F0),
      surface: Colors.white,
      text: Color(0xFF1F2A1F),
      accent: Color(0xFF4F7A57),
    ),
    _ThemeOption(
      key: 'burgundy',
      label: 'Burgundy',
      background: Color(0xFFF8F2F2),
      surface: Colors.white,
      text: Color(0xFF2E1A1E),
      accent: Color(0xFF8A3C4A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final appearanceAsync = ref.watch(menuAppearanceProvider);
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aspetto')),
      body: appearanceAsync.when(
        data: (appearance) {
          _selectedFont ??= appearance.fontPreset;
          _selectedTheme ??= appearance.themePreset;
          _showLogo ??= appearance.showLogo;
          _logoUrl ??= appearance.logoUrl;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personalizza lo stile del menu pubblico',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Qui scegli font, colori e logo. Il menu online vero continuerà a essere gestito da mangialoquiplatform.',
                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Font',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._fontOptions.map(_buildFontOption),
                const SizedBox(height: 24),
                const Text(
                  'Colori',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._themeOptions.map(_buildThemeOption),
                const SizedBox(height: 24),
                const Text(
                  'Logo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostra logo nel menu'),
                  value: _showLogo ?? true,
                  onChanged: (value) {
                    setState(() {
                      _showLogo = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (_logoUrl != null && _logoUrl!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Logo attuale',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _logoUrl!,
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('Impossibile caricare il logo.'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickLogo,
                      icon: const Icon(Icons.upload),
                      label: const Text('Carica logo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _logoUrl = null;
                              });
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Rimuovi logo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _resetRecommendedStyle,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Ripristina stile consigliato'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveAppearance,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _saving ? 'Salvataggio...' : 'Salva aspetto',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPublicMenu,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Apri menu pubblico'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Anteprima rapida',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                restaurantAsync.when(
                  data: (restaurant) {
                    return menuAsync.when(
                      data: (menu) {
                        return categoriesAsync.when(
                          data: (categories) {
                            return itemsAsync.when(
                              data: (items) {
                                return _AppearancePreviewCard(
                                  restaurantName: restaurant.name,
                                  menu: menu,
                                  categories: categories,
                                  items: items,
                                  fontPreset: _selectedFont ?? 'modern',
                                  themePreset: _selectedTheme ?? 'cream',
                                  showLogo: _showLogo ?? true,
                                  logoUrl: _logoUrl,
                                );
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (e, _) => Text('Errore piatti: $e'),
                            );
                          },
                          loading: () => const CircularProgressIndicator(),
                          error: (e, _) => Text('Errore categorie: $e'),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Errore menu: $e'),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Errore ristorante: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
      ),
    );
  }

  Widget _buildFontOption(_FontOption option) {
    final selected = _selectedFont == option.key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedFont = option.key;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.black87 : Colors.black12,
              width: selected ? 1.5 : 1,
            ),
            color: selected ? Colors.black.withOpacity(0.03) : null,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: TextStyle(color: Colors.black.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(_ThemeOption option) {
    final selected = _selectedTheme == option.key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _selectedTheme = option.key;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.black87 : Colors.black12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  _ColorDot(option.background),
                  const SizedBox(width: 6),
                  _ColorDot(option.text),
                  const SizedBox(width: 6),
                  _ColorDot(option.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (file == null) return;

      setState(() {
        _saving = true;
      });

      final restaurant = await ref.read(currentRestaurantProvider.future);
      final repo = ref.read(appearanceRepositoryProvider);

      final logoUrl = await repo.uploadLogo(
        restaurantId: restaurant.id,
        file: file,
      );

      setState(() {
        _logoUrl = logoUrl;
      });
      debugPrint('Logo URL salvato: $logoUrl');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logo caricato')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore upload logo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveAppearance() async {
    try {
      setState(() {
        _saving = true;
      });

      final restaurant = await ref.read(currentRestaurantProvider.future);
      final repo = ref.read(appearanceRepositoryProvider);

      await repo.updateAppearance(
        restaurantId: restaurant.id,
        fontPreset: _selectedFont ?? 'modern',
        themePreset: _selectedTheme ?? 'cream',
        showLogo: _showLogo ?? true,
        logoUrl: _logoUrl,
      );

      ref.invalidate(menuAppearanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Aspetto salvato')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openPublicMenu() async {
    final uri = Uri.parse('https://morsiburger.mangialoqui.it/menu');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _resetRecommendedStyle() {
    setState(() {
      _selectedFont = 'modern';
      _selectedTheme = 'cream';
      _showLogo = true;
    });
  }
}

class _AppearancePreviewCard extends StatelessWidget {
  final String restaurantName;
  final MenuModel menu;
  final List categories;
  final List items;
  final String fontPreset;
  final String themePreset;
  final bool showLogo;
  final String? logoUrl;

  const _AppearancePreviewCard({
    required this.restaurantName,
    required this.menu,
    required this.categories,
    required this.items,
    required this.fontPreset,
    required this.themePreset,
    required this.showLogo,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _themeFromKey(themePreset);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black12),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: theme.text,
          fontFamily: _fontFamilyFromPreset(fontPreset),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLogo && logoUrl != null && logoUrl!.isNotEmpty) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    logoUrl!,
                    height: 54,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Center(
              child: Column(
                children: [
                  Text(
                    restaurantName.toUpperCase(),
                    style: TextStyle(
                      color: theme.text.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      fontFamily: _fontFamilyFromPreset(fontPreset),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    menu.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontFamily: _fontFamilyFromPreset(fontPreset),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anteprima rapida del menu pubblico',
                    style: TextStyle(
                      color: theme.text.withOpacity(0.75),
                      fontSize: 15,
                      fontFamily: _fontFamilyFromPreset(fontPreset),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final category in categories.take(2)) ...[
              Text(
                category.name,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: _fontFamilyFromPreset(fontPreset),
                ),
              ),
              const SizedBox(height: 8),
              ...(items
                  .where((item) => item.categoryId == category.id)
                  .take(2)
                  .map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.accent.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    fontFamily: _fontFamilyFromPreset(
                                      fontPreset,
                                    ),
                                  ),
                                ),
                                if (item.description != null &&
                                    item.description!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description!,
                                    style: TextStyle(
                                      color: theme.text.withOpacity(0.7),
                                      fontFamily: _fontFamilyFromPreset(
                                        fontPreset,
                                      ),
                                    ),
                                  ),
                                ],
                                if (item.isSoldOut) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Sold out',
                                    style: TextStyle(
                                      color: theme.accent,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: _fontFamilyFromPreset(
                                        fontPreset,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.formattedPrice,
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w800,
                              fontFamily: _fontFamilyFromPreset(fontPreset),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  _PreviewTheme _themeFromKey(String key) {
    switch (key) {
      case 'dark':
        return const _PreviewTheme(
          background: Color(0xFF141414),
          surface: Color(0xFF1F1F1F),
          text: Color(0xFFF5F5F5),
          accent: Color(0xFFD7A86E),
        );
      case 'forest':
        return const _PreviewTheme(
          background: Color(0xFFF4F6F0),
          surface: Colors.white,
          text: Color(0xFF1F2A1F),
          accent: Color(0xFF4F7A57),
        );
      case 'burgundy':
        return const _PreviewTheme(
          background: Color(0xFFF8F2F2),
          surface: Colors.white,
          text: Color(0xFF2E1A1E),
          accent: Color(0xFF8A3C4A),
        );
      case 'cream':
      default:
        return const _PreviewTheme(
          background: Color(0xFFF7F1E8),
          surface: Colors.white,
          text: Color(0xFF1E1A17),
          accent: Color(0xFFB98952),
        );
    }
  }

  String? _fontFamilyFromPreset(String preset) {
    switch (preset) {
      case 'elegant':
        return 'Georgia';
      case 'classic':
        return 'Times New Roman';
      case 'compact':
        return 'Roboto';
      case 'modern':
      default:
        return null;
    }
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}

class _FontOption {
  final String key;
  final String label;
  final String description;

  const _FontOption({
    required this.key,
    required this.label,
    required this.description,
  });
}

class _ThemeOption {
  final String key;
  final String label;
  final Color background;
  final Color surface;
  final Color text;
  final Color accent;

  const _ThemeOption({
    required this.key,
    required this.label,
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
  });
}

class _PreviewTheme {
  final Color background;
  final Color surface;
  final Color text;
  final Color accent;

  const _PreviewTheme({
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
  });
}
