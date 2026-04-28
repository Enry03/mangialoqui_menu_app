import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'menu_categories_provider.dart';
import 'menu_category.dart';

class MenuCategoriesScreen extends ConsumerWidget {
  const MenuCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorie menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessuna categoria trovata',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea la prima categoria del tuo menu.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openCreateDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuova categoria'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                child: ListTile(
                  title: Text(category.name),
                  subtitle: Text('Ordine: ${category.sortOrder}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _openEditDialog(context, ref, category);
                      } else if (value == 'delete') {
                        await _confirmDelete(context, ref, category);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifica')),
                      PopupMenuItem(value: 'delete', child: Text('Elimina')),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Errore: $error'),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final menu = await ref.read(currentMenuProvider.future);
    final categories = await ref.read(menuCategoriesProvider.future);

    if (!context.mounted) return;

    final nameController = TextEditingController();
    final sortOrderController = TextEditingController(
      text: categories.length.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuova categoria'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome categoria',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ordine'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final sortOrder =
                              int.tryParse(sortOrderController.text.trim()) ??
                              0;

                          if (name.isEmpty) return;

                          setState(() => isSaving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .createCategory(
                                  menuId: menu.id,
                                  name: name,
                                  sortOrder: sortOrder,
                                );

                            ref.invalidate(menuCategoriesProvider);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Categoria creata'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Errore: $e')),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    MenuCategory category,
  ) async {
    final nameController = TextEditingController(text: category.name);
    final sortOrderController = TextEditingController(
      text: category.sortOrder.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica categoria'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome categoria',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ordine'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final sortOrder =
                              int.tryParse(sortOrderController.text.trim()) ??
                              0;

                          if (name.isEmpty) return;

                          setState(() => isSaving = true);

                          try {
                            await ref
                                .read(menuCategoriesRepositoryProvider)
                                .updateCategory(
                                  id: category.id,
                                  name: name,
                                  sortOrder: sortOrder,
                                );

                            ref.invalidate(menuCategoriesProvider);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Categoria aggiornata'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Errore: $e')),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MenuCategory category,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina categoria'),
            content: Text('Vuoi eliminare "${category.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ref
          .read(menuCategoriesRepositoryProvider)
          .deleteCategory(category.id);
      ref.invalidate(menuCategoriesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Categoria eliminata')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}
