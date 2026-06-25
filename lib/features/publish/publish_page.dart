import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../menu/menu.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';
import 'menu_publish_provider.dart';
import 'menu_publish_repository.dart';

class PublishPage extends ConsumerStatefulWidget {
  const PublishPage({super.key});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  bool _showQrCode = false;
  bool _savingQr = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(currentRestaurantProvider);
    final menuAsync = ref.watch(currentMenuProvider);
    final categoriesAsync = ref.watch(menuCategoriesProvider);
    final itemsAsync = ref.watch(menuItemsProvider);
    final versionsAsync = ref.watch(menuVersionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pubblica')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            restaurantAsync.when(
              data: (restaurant) => menuAsync.when(
                data: (menu) =>
                    _HeaderPreview(restaurantSlug: restaurant.slug, menu: menu),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore menu: $e'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Errore ristorante: $e'),
            ),
            const SizedBox(height: 24),
            restaurantAsync.when(
              data: (restaurant) => _QrCodeSection(
                restaurantSlug: restaurant.slug,
                showQrCode: _showQrCode,
                savingQr: _savingQr,
                screenshotController: _screenshotController,
                onGenerate: () {
                  setState(() {
                    _showQrCode = true;
                  });
                },
                onShare: () => _sharePublicMenuLink(restaurant.slug),
                onSave: () => _saveQrCodeToGallery(restaurant.slug),
                onOpen: () => _openPublicMenu(restaurant.slug),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Errore QR code: $e'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Anteprima menu pubblico',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            restaurantAsync.when(
              data: (restaurant) => Text(
                'Questa è una preview rapida di come appare il menu su https://${restaurant.slug}.mangialoqui.it/menu.',
                style: TextStyle(color: Colors.black.withOpacity(0.7)),
              ),
              loading: () => Text(
                'Caricamento URL pubblico...',
                style: TextStyle(color: Colors.black.withOpacity(0.7)),
              ),
              error: (e, _) => Text(
                'Errore ristorante: $e',
                style: TextStyle(color: Colors.black.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 16),
            _PreviewCard(
              categoriesAsync: categoriesAsync,
              itemsAsync: itemsAsync,
            ),
            const SizedBox(height: 24),
            const Text(
              'Stato pubblicazione',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            versionsAsync.when(
              data: (versions) => _PublishSection(versions: versions),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Errore versioni: $e'),
            ),
          ],
        ),
      ),
    );
  }

  String _publicMenuUrl(String slug) {
    return 'https://$slug.mangialoqui.it/menu';
  }

  Future<void> _openPublicMenu(String slug) async {
    try {
      final uri = Uri.parse(_publicMenuUrl(slug));
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
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

  Future<void> _sharePublicMenuLink(String slug) async {
    try {
      final url = _publicMenuUrl(slug);
      await Share.share(
        'Ecco il menu del ristorante:\n$url',
        subject: 'Menu pubblico',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore condivisione: $e')));
      }
    }
  }

  Future<void> _saveQrCodeToGallery(String slug) async {
    try {
      setState(() {
        _savingQr = true;
      });

      if (!_showQrCode) {
        setState(() {
          _showQrCode = true;
        });
        await Future.delayed(const Duration(milliseconds: 150));
      }

      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) {
        throw Exception('Impossibile generare l’immagine del QR code');
      }

      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'menu_qr_$slug',
      );

      final success =
          result is Map &&
          (result['isSuccess'] == true || result['success'] == true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'QR code salvato sul telefono'
                  : 'Salvataggio non riuscito',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore salvataggio QR: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingQr = false;
        });
      }
    }
  }
}

class _HeaderPreview extends StatelessWidget {
  final String restaurantSlug;
  final MenuModel menu;

  const _HeaderPreview({required this.restaurantSlug, required this.menu});

  @override
  Widget build(BuildContext context) {
    final Uri publicUrl = Uri.parse(
      'https://$restaurantSlug.mangialoqui.it/menu',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu pubblico',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            menu.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  publicUrl.toString(),
                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await launchUrl(
                    publicUrl,
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Apri'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrCodeSection extends StatelessWidget {
  final String restaurantSlug;
  final bool showQrCode;
  final bool savingQr;
  final ScreenshotController screenshotController;
  final VoidCallback onGenerate;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  const _QrCodeSection({
    required this.restaurantSlug,
    required this.showQrCode,
    required this.savingQr,
    required this.screenshotController,
    required this.onGenerate,
    required this.onShare,
    required this.onSave,
    required this.onOpen,
  });

  String get _qrUrl => 'https://$restaurantSlug.mangialoqui.it/menu';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QR code del menu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Questo QR code è unico per il ristorante e resta sempre lo stesso. '
            'Se il menu cambia, il QR non cambia.',
            style: TextStyle(color: Colors.black.withOpacity(0.7)),
          ),
          const SizedBox(height: 12),
          if (!showQrCode)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Genera QR code'),
              ),
            ),
          if (showQrCode) ...[
            Center(
              child: Screenshot(
                controller: screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _qrUrl,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 240,
                        child: Text(
                          _qrUrl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share),
                  label: const Text('Condividi link'),
                ),
                OutlinedButton.icon(
                  onPressed: savingQr ? null : onSave,
                  icon: savingQr
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    savingQr ? 'Salvataggio...' : 'Salva sul telefono',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Apri menu'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final AsyncValue categoriesAsync;
  final AsyncValue itemsAsync;

  const _PreviewCard({required this.categoriesAsync, required this.itemsAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: categoriesAsync.when(
          data: (categories) {
            return itemsAsync.when(
              data: (items) {
                if (categories.isEmpty || items.isEmpty) {
                  return const Text(
                    'Il menu è vuoto. Aggiungi piatti per vedere la preview.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category in categories) ...[
                      const SizedBox(height: 12),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Divider(color: Colors.black.withOpacity(0.08)),
                      ...items
                          .where((item) => item.categoryId == category.id)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (item.description != null &&
                                            item.description!.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              item.description!,
                                              style: TextStyle(
                                                color: Colors.black.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (item.isSoldOut)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Sold out',
                                              style: TextStyle(
                                                color: Colors.redAccent
                                                    .withOpacity(0.9),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    item.formattedPrice,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Errore piatti: $e'),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Errore categorie: $e'),
        ),
      ),
    );
  }
}

class _PublishSection extends ConsumerStatefulWidget {
  final List<MenuVersion> versions;

  const _PublishSection({required this.versions});

  @override
  ConsumerState<_PublishSection> createState() => _PublishSectionState();
}

class _PublishSectionState extends ConsumerState<_PublishSection> {
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    final hasPublished = widget.versions.any((v) => v.isPublished);

    MenuVersion? currentPublished;
    if (hasPublished) {
      currentPublished = widget.versions.firstWhere((v) => v.isPublished);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasPublished)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: const Text(
              'Nessuna versione è pubblicata al momento.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (currentPublished != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Versione attualmente online',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${currentPublished.versionNumber}'
                  '${currentPublished.label != null ? ' – ${currentPublished.label}' : ''}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _publishing ? null : _publishNewVersion,
                icon: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  _publishing
                      ? 'Pubblicazione...'
                      : 'Pubblica versione corrente',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Cronologia versioni',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.versions.isEmpty)
          const Text('Ancora nessuna versione salvata.'),
        if (widget.versions.isNotEmpty)
          Column(
            children: widget.versions.map((v) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'v${v.versionNumber}'
                  '${v.label != null ? ' – ${v.label}' : ''}',
                ),
                subtitle: Text(v.createdAt.toString()),
                trailing: v.isPublished
                    ? const Chip(label: Text('Online'))
                    : TextButton(
                        onPressed: _publishing
                            ? null
                            : () => _restoreVersion(v),
                        child: const Text('Ripristina'),
                      ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _publishNewVersion() async {
    setState(() => _publishing = true);

    try {
      final tuple = await ref.read(menuAndRestaurantProvider.future);
      final restaurant = tuple.first;
      final menu = tuple.second;
      final repository = ref.read(menuPublishRepositoryProvider);

      final createdVersion = await repository.createDraftVersion(
        restaurant: restaurant,
        menu: menu,
        label: 'Pubblicazione ${DateTime.now()}',
      );

      await repository.publishVersion(menu: menu, versionId: createdVersion.id);

      ref.invalidate(menuVersionsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Menu pubblicato')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  Future<void> _restoreVersion(MenuVersion version) async {
    setState(() => _publishing = true);

    try {
      final menu = await ref.read(currentMenuProvider.future);

      await ref
          .read(menuPublishRepositoryProvider)
          .publishVersion(menu: menu, versionId: version.id);

      ref.invalidate(menuVersionsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Versione ripristinata')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }
}
