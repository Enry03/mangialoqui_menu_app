import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../menu/menu.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';
import 'appearance_provider.dart';

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
      description: 'Pulito, deciso e più adatto al look attuale.',
    ),
    _FontOption(
      key: 'elegant',
      label: 'Elegante',
      description: 'Più raffinato, con una presenza più editoriale.',
    ),
    _FontOption(
      key: 'classic',
      label: 'Classico',
      description: 'Tradizionale e affidabile, con un tono senza tempo.',
    ),
    _FontOption(
      key: 'compact',
      label: 'Compatto',
      description: 'Più denso, diretto e orientato alla lettura rapida.',
    ),
  ];

  static const _themeOptions = <_ThemeOption>[
    _ThemeOption(
      key: 'cream',
      label: 'Ocean Light',
      background: Color(0xFFF5F7FB),
      surface: Colors.white,
      text: Color(0xFF0F172A),
      accent: AppColors.primary,
    ),
    _ThemeOption(
      key: 'dark',
      label: 'Ocean Dark',
      background: Color(0xFF0E1726),
      surface: Color(0xFF162033),
      text: Color(0xFFF8FAFC),
      accent: Color(0xFF7FB3FF),
    ),
    _ThemeOption(
      key: 'forest',
      label: 'Fresh Blue',
      background: Color(0xFFF2F7FF),
      surface: Colors.white,
      text: Color(0xFF11243F),
      accent: Color(0xFF2A5CAA),
    ),
    _ThemeOption(
      key: 'burgundy',
      label: 'Deep Navy',
      background: Color(0xFFF4F6FA),
      surface: Colors.white,
      text: Color(0xFF0F1B2D),
      accent: Color(0xFF163E78),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final appearanceAsync = ref.watch(menuAppearanceProvider);
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Aspetto')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundTint, AppColors.background],
          ),
        ),
        child: appearanceAsync.when(
          data: (appearance) {
            _selectedFont ??= appearance.fontPreset;
            _selectedTheme ??= appearance.themePreset;
            _showLogo ??= appearance.showLogo;
            _logoUrl ??= appearance.logoUrl;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroCard(theme),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSectionTitle(context, 'Font'),
                    const SizedBox(height: AppSpacing.md),
                    ..._fontOptions.map(_buildFontOption),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSectionTitle(context, 'Colori'),
                    const SizedBox(height: AppSpacing.md),
                    ..._themeOptions.map(_buildThemeOption),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSectionTitle(context, 'Logo'),
                    const SizedBox(height: AppSpacing.md),
                    _buildLogoCard(),
                    const SizedBox(height: AppSpacing.xxl),
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
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _saving ? 'Salvataggio...' : 'Salva aspetto',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _openPublicMenu,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Apri menu pubblico'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildSectionTitle(context, 'Anteprima rapida'),
                    const SizedBox(height: AppSpacing.md),
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
                                  loading: () => const _SectionLoader(),
                                  error: (e, _) => Text('Errore piatti: $e'),
                                );
                              },
                              loading: () => const _SectionLoader(),
                              error: (e, _) => Text('Errore categorie: $e'),
                            );
                          },
                          loading: () => const _SectionLoader(),
                          error: (e, _) => Text('Errore menu: $e'),
                        );
                      },
                      loading: () => const _SectionLoader(),
                      error: (e, _) => Text('Errore ristorante: $e'),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Errore: $e')),
        ),
      ),
    );
  }

  Widget _buildIntroCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalizza lo stile del menu pubblico',
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Scegli font, palette e logo per dare al menu online un’identità più elegante, pulita e coerente con il brand.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
    );
  }

  Widget _buildLogoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.primary,
            title: const Text('Mostra logo nel menu'),
            subtitle: const Text(
              'Visualizza il logo nella parte alta del menu.',
            ),
            value: _showLogo ?? true,
            onChanged: (value) {
              setState(() {
                _showLogo = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_logoUrl != null && _logoUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logo attuale',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickLogo,
                icon: const Icon(Icons.upload_rounded),
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
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Rimuovi logo'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _resetRecommendedStyle,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Ripristina stile consigliato'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontOption(_FontOption option) {
    final selected = _selectedFont == option.key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
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
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
              color: selected ? AppColors.primarySoft : AppColors.surface,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textMuted,
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
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
            color: selected ? AppColors.primarySoft : AppColors.surface,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textMuted,
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
    try {
      final restaurant = await ref.read(currentRestaurantProvider.future);
      final uri = Uri.parse('https://${restaurant.slug}.mangialoqui.it/menu');

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il menu pubblico')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore apertura menu: $e')));
      }
    }
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
                      color: theme.text.withValues(alpha: 0.7),
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
                      color: theme.text.withValues(alpha: 0.75),
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
                          color: theme.accent.withValues(alpha: 0.18),
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
                                      color: theme.text.withValues(alpha: 0.7),
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
          background: Color(0xFF0E1726),
          surface: Color(0xFF162033),
          text: Color(0xFFF8FAFC),
          accent: Color(0xFF7FB3FF),
        );
      case 'forest':
        return const _PreviewTheme(
          background: Color(0xFFF2F7FF),
          surface: Colors.white,
          text: Color(0xFF11243F),
          accent: Color(0xFF2A5CAA),
        );
      case 'burgundy':
        return const _PreviewTheme(
          background: Color(0xFFF4F6FA),
          surface: Colors.white,
          text: Color(0xFF0F1B2D),
          accent: Color(0xFF163E78),
        );
      case 'cream':
      default:
        return const _PreviewTheme(
          background: Color(0xFFF5F7FB),
          surface: Colors.white,
          text: Color(0xFF0F172A),
          accent: AppColors.primary,
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
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
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
