import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_items_provider.dart';
import 'ai_provider.dart';

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final FocusNode _inputFocusNode = FocusNode();

  final List<_ChatMessage> _messages = [];

  bool _speechEnabled = false;
  bool _sending = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _inputFocusNode.addListener(_handleFocusChange);
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    if (_inputFocusNode.hasFocus) {
      _scrollToBottom(extraOffset: 220);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('AI')),
        body: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;

                  if (isWide) {
                    return _buildChatPanel(isMobile: false);
                  }

                  return _buildMobileLayout();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _buildChatPanel(isMobile: true);
  }

  Widget _buildChatPanel({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        color: Colors.white.withOpacity(0.55),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Scrivi o detta le modifiche del menu.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _openPublicMenu,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Apri menu'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Scrivi una richiesta come:\n'
                        '“Aggiungi categoria pesce”,\n'
                        '“Nascondi categoria pesce dal menu” oppure\n'
                        '“Aggiungi un burger vegetariano a 11€”',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 320 : 640,
                          ),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? Colors.black87
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: SelectableText(
                            message.text,
                            style: TextStyle(
                              color: message.isUser
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'AI sta elaborando...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          _buildComposer(isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildComposer({required bool isMobile}) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          isMobile ? (bottomInset > 0 ? 12 : 16) : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickPromptChip(
                      label: 'Aggiorna prezzi',
                      onTap: () => _controller.text =
                          'Aggiorna i prezzi del menu in modo coerente.',
                    ),
                    const SizedBox(width: 8),
                    _QuickPromptChip(
                      label: 'Nuovi piatti',
                      onTap: () => _controller.text =
                          'Aggiungi due nuovi piatti speciali al menu.',
                    ),
                    const SizedBox(width: 8),
                    _QuickPromptChip(
                      label: 'Aggiungi categoria',
                      onTap: () =>
                          _controller.text = 'Aggiungi categoria pesce',
                    ),
                    const SizedBox(width: 8),
                    _QuickPromptChip(
                      label: 'Nascondi categoria',
                      onTap: () => _controller.text =
                          'Nascondi categoria pesce dal menu',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: isMobile ? 5 : 4,
                    textInputAction: TextInputAction.newline,
                    onTap: () => _scrollToBottom(extraOffset: 220),
                    decoration: InputDecoration(
                      hintText: 'Scrivi una modifica del menu...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _speechEnabled
                          ? (_speechToText.isListening
                                ? _stopListening
                                : _startListening)
                          : null,
                      icon: Icon(
                        _speechToText.isListening ? Icons.mic : Icons.mic_none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _sendMessage,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getNextCategorySortOrder(String menuId) async {
    final rows = await _client
        .from('menu_categories')
        .select('sort_order')
        .eq('menu_id', menuId);

    int next = 0;
    for (final row in (rows as List)) {
      final value = row['sort_order'];
      if (value is int && value >= next) {
        next = value + 1;
      }
    }
    return next;
  }

  Future<int> _getNextItemSortOrder({
    required String menuId,
    required String categoryId,
  }) async {
    final rows = await _client
        .from('menu_items')
        .select('sort_order')
        .eq('menu_id', menuId)
        .eq('category_id', categoryId);

    int next = 0;
    for (final row in (rows as List)) {
      final value = row['sort_order'];
      if (value is int && value >= next) {
        next = value + 1;
      }
    }
    return next;
  }

  Future<Map<String, dynamic>> _buildMenuSnapshot(String menuId) async {
    final categoriesResponse = await _client
        .from('menu_categories')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true);

    final itemsResponse = await _client
        .from('menu_items')
        .select()
        .eq('menu_id', menuId)
        .order('sort_order', ascending: true);

    final categories = (categoriesResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final items = (itemsResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return {'categories': categories, 'items': items};
  }

  Future<void> _refreshMenuState() async {
    ref.invalidate(menuCategoriesProvider);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(currentMenuProvider);
  }

  Future<void> _hideCategoryByName({
    required String menuId,
    required String categoryName,
    required List<String> debugLines,
  }) async {
    final categories = await _client
        .from('menu_categories')
        .select('id,name')
        .eq('menu_id', menuId)
        .ilike('name', categoryName);

    if ((categories as List).isEmpty) {
      debugLines.add('hide_category: categoria non trovata: $categoryName');
      return;
    }

    final category = categories.first as Map<String, dynamic>;
    final categoryId = category['id'] as String;

    await _client
        .from('menu_categories')
        .update({'menu_category_active': false})
        .eq('menu_id', menuId)
        .eq('id', categoryId);

    debugLines.add('hide_category ok: $categoryName');
  }

  Future<void> _hideItemByName({
    required String menuId,
    required String itemName,
    required String? categoryName,
    required List<String> debugLines,
  }) async {
    String? categoryId;

    if (categoryName != null && categoryName.trim().isNotEmpty) {
      final categories = await _client
          .from('menu_categories')
          .select('id')
          .eq('menu_id', menuId)
          .ilike('name', categoryName.trim());

      if ((categories as List).isNotEmpty) {
        categoryId = categories.first['id'] as String;
      }
    }

    var query = _client
        .from('menu_items')
        .select('id,name')
        .eq('menu_id', menuId)
        .ilike('name', itemName);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final items = await query;

    if ((items as List).isEmpty) {
      debugLines.add('hide_item: piatto non trovato: $itemName');
      return;
    }

    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      await _client
          .from('menu_items')
          .update({'menu_item_active': false})
          .eq('menu_id', menuId)
          .eq('id', item['id'] as String);
    }

    debugLines.add('hide_item ok: $itemName');
  }

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(text: prompt, isUser: true));
      _controller.clear();
    });

    _scrollToBottom(extraOffset: 200);

    try {
      final restaurant = await ref.read(currentRestaurantProvider.future);
      final menu = await ref.read(currentMenuProvider.future);
      final aiRepo = ref.read(aiRepositoryProvider);

      final snapshotBefore = await _buildMenuSnapshot(menu.id);

      final aiResult = await aiRepo.askAi(
        restaurantId: restaurant.id,
        menuId: menu.id,
        prompt: prompt,
        menuSnapshot: snapshotBefore,
      );

      int appliedActions = 0;
      final debugLines = <String>[
        'restaurantId: ${restaurant.id}',
        'menuId: ${menu.id}',
        'actions ricevute: ${aiResult.actions.length}',
        'payload raw: ${jsonEncode(aiResult.rawData)}',
      ];

      for (final action in aiResult.actions) {
        debugLines.add('azione: ${action.type} -> ${jsonEncode(action.raw)}');

        if (action.type == 'create_category') {
          final name = action.name?.trim();
          if (name == null || name.isEmpty) {
            debugLines.add('create_category saltata: name vuoto');
            continue;
          }

          final existing = await _client
              .from('menu_categories')
              .select('id')
              .eq('menu_id', menu.id)
              .ilike('name', name);

          if ((existing as List).isNotEmpty) {
            debugLines.add('categoria già esistente: $name');
            continue;
          }

          final nextSortOrder = await _getNextCategorySortOrder(menu.id);

          final inserted = await _client.from('menu_categories').insert({
            'menu_id': menu.id,
            'name': name,
            'sort_order': nextSortOrder,
          }).select();

          debugLines.add('insert categoria ok: ${jsonEncode(inserted)}');
          appliedActions++;
          continue;
        }

        if (action.type == 'delete_category' ||
            action.type == 'hide_category') {
          final name = action.name?.trim();
          if (name == null || name.isEmpty) {
            debugLines.add('hide_category saltata: name vuoto');
            continue;
          }

          await _hideCategoryByName(
            menuId: menu.id,
            categoryName: name,
            debugLines: debugLines,
          );
          appliedActions++;
          continue;
        }

        if (action.type == 'create_item') {
          final name = action.name?.trim();
          final categoryName = action.categoryName?.trim();
          final priceCents = action.priceCents;
          final currency = (action.currency ?? 'EUR').trim();

          if (name == null || name.isEmpty) {
            debugLines.add('create_item saltata: name vuoto');
            continue;
          }
          if (categoryName == null || categoryName.isEmpty) {
            debugLines.add('create_item saltata: categoryName vuoto');
            continue;
          }
          if (priceCents == null) {
            debugLines.add('create_item saltata: priceCents nullo');
            continue;
          }

          final categories = await _client
              .from('menu_categories')
              .select('id,name')
              .eq('menu_id', menu.id)
              .ilike('name', categoryName);

          String? categoryId;

          if ((categories as List).isNotEmpty) {
            categoryId = categories.first['id'] as String;
          } else {
            final nextCategorySortOrder = await _getNextCategorySortOrder(
              menu.id,
            );

            final createdCategory = await _client
                .from('menu_categories')
                .insert({
                  'menu_id': menu.id,
                  'name': categoryName,
                  'sort_order': nextCategorySortOrder,
                })
                .select()
                .single();

            categoryId = createdCategory['id'] as String;
            debugLines.add(
              'categoria auto-creata: ${jsonEncode(createdCategory)}',
            );
          }

          final existingItems = await _client
              .from('menu_items')
              .select('id')
              .eq('menu_id', menu.id)
              .eq('category_id', categoryId)
              .ilike('name', name);

          if ((existingItems as List).isNotEmpty) {
            debugLines.add('piatto già esistente: $name');
            continue;
          }

          final nextItemSortOrder = await _getNextItemSortOrder(
            menuId: menu.id,
            categoryId: categoryId,
          );

          final insertedItem = await _client.from('menu_items').insert({
            'menu_id': menu.id,
            'category_id': categoryId,
            'name': name,
            'description': action.description,
            'price_cents': priceCents,
            'currency': currency,
            'sort_order': nextItemSortOrder,
            'is_sold_out': false,
          }).select();

          debugLines.add('insert piatto ok: ${jsonEncode(insertedItem)}');
          appliedActions++;
          continue;
        }

        if (action.type == 'delete_item' || action.type == 'hide_item') {
          final name = action.name?.trim();
          if (name == null || name.isEmpty) {
            debugLines.add('hide_item saltata: name vuoto');
            continue;
          }

          await _hideItemByName(
            menuId: menu.id,
            itemName: name,
            categoryName: action.categoryName,
            debugLines: debugLines,
          );
          appliedActions++;
          continue;
        }

        debugLines.add('azione non gestita: ${action.type}');
      }

      await aiRepo.saveHistory(
        restaurantId: restaurant.id,
        menuId: menu.id,
        prompt: prompt,
        aiResponse: aiResult.reply,
        actionSummary: aiResult.summary,
        source: 'chat',
        menuSnapshot: snapshotBefore,
      );

      for (final line in debugLines) {
        debugPrint('[AI DEBUG] $line');
      }

      final resultMessage = appliedActions > 0
          ? '${aiResult.reply}\n\nAzioni applicate: $appliedActions'
          : aiResult.reply;

      setState(() {
        _messages.add(_ChatMessage(text: resultMessage, isUser: false));
      });

      await _refreshMenuState();
      _scrollToBottom(extraOffset: 220);
    } on PostgrestException catch (e) {
      debugPrint(
        '[AI ERROR][POSTGREST] '
        'message=${e.message}; '
        'code=${e.code}; '
        'details=${e.details}; '
        'hint=${e.hint}',
      );

      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Non sono riuscito ad applicare la modifica al menu.',
            isUser: false,
          ),
        );
      });
      _scrollToBottom(extraOffset: 220);
    } catch (e, stackTrace) {
      debugPrint('[AI ERROR] $e');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _messages.add(
          const _ChatMessage(
            text: 'Si è verificato un errore durante la richiesta AI.',
            isUser: false,
          ),
        );
      });
      _scrollToBottom(extraOffset: 220);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _controller.text = result.recognizedWords;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
    _scrollToBottom(extraOffset: 220);
  }

  Future<void> _openPublicMenu() async {
    final restaurant = await ref.read(currentRestaurantProvider.future);
    final uri = Uri.https('${restaurant.slug}.mangialoqui.it', '/menu');

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _scrollToBottom({double extraOffset = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent + extraOffset;
        _scrollController.animateTo(
          target.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickPromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
