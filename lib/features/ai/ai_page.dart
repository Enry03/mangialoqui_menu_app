import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../menu_categories/menu_category.dart';
import '../menu_categories/menu_categories_provider.dart';
import '../menu_items/menu_item.dart';
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
    _controller.addListener(_handleComposerChanged);
    _inputFocusNode.addListener(_handleFocusChange);
  }

  Future<void> _toggleListening() async {
    if (_speechToText.isListening) {
      await _stopListening();
      return;
    }

    if (!_speechEnabled) {
      try {
        final speechEnabled = await _speechToText.initialize();

        if (!mounted) return;

        setState(() {
          _speechEnabled = speechEnabled;
        });

        if (!speechEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Per usare la dettatura devi consentire l’accesso al microfono.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile avviare il riconoscimento vocale.',
            ),
          ),
        );
        return;
      }
    }

    await _startListening();
  }

  void _handleFocusChange() {
    if (_inputFocusNode.hasFocus) {
      _ensureComposerVisible();
    }
  }

  void _handleComposerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleComposerChanged);
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.backgroundTint, AppColors.background],
            ),
          ),
          child: SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
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
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _buildChatPanel(isMobile: true);
  }

  Widget _buildComposerInput({
    required bool isMobile,
    required TextStyle composerTextStyle,
    required String? composerGhostText,
  }) {
    final maxLines = isMobile ? 5 : 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        var reservedLines = 1;

        if (composerGhostText != null) {
          final availableTextWidth = constraints.maxWidth > 28
              ? constraints.maxWidth - 28
              : constraints.maxWidth;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '${_controller.text}$composerGhostText',
              style: composerTextStyle,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: maxLines,
          )..layout(maxWidth: availableTextWidth);

          reservedLines = textPainter
              .computeLineMetrics()
              .length
              .clamp(1, maxLines)
              .toInt();
        }

        return Stack(
          children: [
            TextField(
              controller: _controller,
              focusNode: _inputFocusNode,
              minLines: composerGhostText != null ? reservedLines : 1,
              maxLines: maxLines,
              textAlignVertical: TextAlignVertical.top,
              style: composerTextStyle,
              textInputAction: TextInputAction.newline,
              onTap: () => _scrollToBottom(extraOffset: 220),
              decoration: const InputDecoration(
                hintText: 'Scrivi una modifica del menu...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            if (composerGhostText != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: RichText(
                          maxLines: maxLines,
                          overflow: TextOverflow.clip,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            style: composerTextStyle,
                            children: [
                              TextSpan(
                                text: _controller.text,
                                style: composerTextStyle.copyWith(
                                  color: Colors.transparent,
                                ),
                              ),
                              TextSpan(
                                text: composerGhostText,
                                style: composerTextStyle.copyWith(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _isWordCharacter(String value) {
    return RegExp(
      r'[A-Za-zÀ-ÖØ-öø-ÿ0-9]',
    ).hasMatch(value);
  }

  TextSpan _buildAssistantMessageSpan(String text) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    var searchFrom = 0;

    while (searchFrom < text.length) {
      final openingQuote = text.indexOf("'", searchFrom);

      if (openingQuote < 0) {
        break;
      }

      final openingInsideWord =
          openingQuote > 0 &&
          _isWordCharacter(text[openingQuote - 1]);

      if (openingInsideWord) {
        searchFrom = openingQuote + 1;
        continue;
      }

      final closingQuote = text.indexOf("'", openingQuote + 1);

      if (closingQuote < 0) {
        break;
      }

      final closingInsideWord =
          closingQuote + 1 < text.length &&
          _isWordCharacter(text[closingQuote + 1]);

      final highlightedText = text
          .substring(openingQuote + 1, closingQuote)
          .trim();

      if (
        closingInsideWord ||
        highlightedText.isEmpty ||
        highlightedText.contains('\n')
      ) {
        searchFrom = openingQuote + 1;
        continue;
      }

      if (openingQuote > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, openingQuote),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: highlightedText,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      cursor = closingQuote + 1;
      searchFrom = cursor;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildChatPanel({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chat AI',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openPublicMenu,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Apri menu'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Scrivi liberamente oppure usa i suggerimenti per costruire una modifica del menu.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                                ? AppColors.primary
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: message.isUser
                              ? SelectableText(
                                  message.text,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                  ),
                                )
                              : SelectableText.rich(
                                  _buildAssistantMessageSpan(
                                    message.text,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'AI sta elaborando...',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.primary),
              ),
            ),
          _buildComposer(isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildComposer({required bool isMobile}) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final activeCategories =
        ref.watch(menuCategoriesProvider).asData?.value ??
        const <MenuCategory>[];
    final activeItems =
        ref.watch(menuItemsProvider).asData?.value ?? const <MenuItemModel>[];
    final allCategories =
        ref.watch(allMenuCategoriesProvider).asData?.value ?? activeCategories;
    final allItems =
        ref.watch(allMenuItemsProvider).asData?.value ?? activeItems;
    final suggestionGroup = _buildComposerSuggestionGroup(
      activeCategories: activeCategories,
      activeItems: activeItems,
      allCategories: allCategories,
      allItems: allItems,
    );
    final composerGhostText = _buildComposerGhostText(activeCategories);
    final composerTextStyle =
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);

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
            _buildComposerSuggestionArea(suggestionGroup),
            LayoutBuilder(
              builder: (context, constraints) {
                final useStackedLayout = constraints.maxWidth < 430;

                final composerInput = _buildComposerInput(
                  isMobile: isMobile,
                  composerTextStyle: composerTextStyle,
                  composerGhostText: composerGhostText,
                );

                final microphoneButton = IconButton.filledTonal(
                  onPressed: _sending ? null : _toggleListening,
                  icon: Icon(
                    _speechToText.isListening
                        ? Icons.mic
                        : Icons.mic_none,
                  ),
                );

                final sendButton = IconButton.filled(
                  onPressed: _sending ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                );

                if (useStackedLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      composerInput,
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          microphoneButton,
                          const SizedBox(width: 8),
                          sendButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: composerInput),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        microphoneButton,
                        const SizedBox(height: 8),
                        sendButton,
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _buildComposerGhostText(
    List<MenuCategory> activeCategories,
  ) {
    final match = RegExp(
      r'^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s+(.+?)\s*:\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(_controller.text);

    if (match == null) {
      return null;
    }

    final typedCategoryName = match.group(1)?.trim() ?? '';
    final dishName = match.group(2)?.trim() ?? '';

    if (dishName.isNotEmpty) {
      return null;
    }

    final categoryExists = activeCategories.any(
      (category) =>
          _normalizeComposerText(category.name) ==
          _normalizeComposerText(typedCategoryName),
    );

    if (!categoryExists) {
      return null;
    }

    final separator =
        RegExp(r'\s$').hasMatch(_controller.text) ? '' : ' ';

    return '$separator Scrivi qui il nome del piatto';
  }

  Widget _buildComposerSuggestionArea(
    _ComposerSuggestionGroup? suggestionGroup,
  ) {
    final hasSuggestions =
        suggestionGroup != null && suggestionGroup.suggestions.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: !hasSuggestions
            ? const SizedBox.shrink(key: ValueKey('composer-suggestions-empty'))
            : Padding(
                key: ValueKey(suggestionGroup.key),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestionGroup.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < suggestionGroup.suggestions.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 8),
                            ActionChip(
                              avatar:
                                  suggestionGroup.suggestions[index].icon ==
                                      null
                                  ? null
                                  : Icon(
                                      suggestionGroup.suggestions[index].icon,
                                      size: 18,
                                    ),
                              label: Text(
                                suggestionGroup.suggestions[index].label,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _applyComposerText(
                                suggestionGroup.suggestions[index].textToApply,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  _ComposerSuggestionGroup? _buildComposerSuggestionGroup({
    required List<MenuCategory> activeCategories,
    required List<MenuItemModel> activeItems,
    required List<MenuCategory> allCategories,
    required List<MenuItemModel> allItems,
  }) {
    final text = _controller.text;
    final normalizedText = _normalizeComposerText(text);

    if (normalizedText.isEmpty) {
      return const _ComposerSuggestionGroup(
        key: 'initial',
        label: 'Cosa vuoi fare?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Aggiungi',
            icon: Icons.add_rounded,
            textToApply: 'Aggiungi ',
          ),
          _ComposerSuggestion(
            label: 'Nascondi',
            icon: Icons.visibility_off_outlined,
            textToApply: 'Nascondi ',
          ),
          _ComposerSuggestion(
            label: 'Riattiva',
            icon: Icons.visibility_outlined,
            textToApply: 'Riattiva ',
          ),
        ],
      );
    }

    if (normalizedText == 'aggiungi') {
      return const _ComposerSuggestionGroup(
        key: 'add-type',
        label: 'Cosa vuoi aggiungere?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Piatto',
            icon: Icons.restaurant_menu_rounded,
            textToApply: 'Aggiungi un piatto nella categoria ',
          ),
          _ComposerSuggestion(
            label: 'Categoria',
            icon: Icons.category_outlined,
            textToApply: 'Aggiungi categoria ',
          ),
        ],
      );
    }

    final addItemWithCategoryMatch = RegExp(
      r'^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s+(.+?)\s*:\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (addItemWithCategoryMatch != null) {
      final typedCategoryName = addItemWithCategoryMatch.group(1)?.trim() ?? '';
      final dishName = addItemWithCategoryMatch.group(2)?.trim() ?? '';
      MenuCategory? selectedCategory;

      for (final category in activeCategories) {
        if (_normalizeComposerText(category.name) ==
            _normalizeComposerText(typedCategoryName)) {
          selectedCategory = category;
          break;
        }
      }

      if (selectedCategory == null ||
          dishName.isEmpty ||
          _containsComposerPrice(dishName)) {
        return null;
      }

      final naturalPrefix =
          'Aggiungi $dishName nella categoria ${selectedCategory.name} a ';

      return _ComposerSuggestionGroup(
        key: 'add-price',
        label: 'Completa il prezzo',
        suggestions: [
          for (final price in const [5, 8, 10, 12])
            _ComposerSuggestion(
              label: '$price €',
              icon: Icons.euro_rounded,
              textToApply: '$naturalPrefix$price €',
            ),
          _ComposerSuggestion(
            label: 'Altro prezzo',
            icon: Icons.edit_outlined,
            textToApply: naturalPrefix,
          ),
        ],
      );
    }

    final addItemCategoryMatch = RegExp(
      r'^\s*aggiungi\s+un\s+piatto\s+nella\s+categoria\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (addItemCategoryMatch != null) {
      final query = _normalizeComposerText(addItemCategoryMatch.group(1) ?? '');
      final categories = activeCategories
          .where((category) => _matchesComposerQuery(category.name, query))
          .take(20)
          .toList();

      return _ComposerSuggestionGroup(
        key: 'add-category-choice',
        label: 'Scegli una categoria',
        suggestions: [
          for (final category in categories)
            _ComposerSuggestion(
              label: category.name,
              icon: Icons.category_outlined,
              textToApply:
                  'Aggiungi un piatto nella categoria ${category.name}: ',
            ),
          const _ComposerSuggestion(
            label: 'Crea prima una categoria',
            icon: Icons.create_new_folder_outlined,
            textToApply: 'Aggiungi categoria ',
          ),
        ],
      );
    }

    if (normalizedText == 'nascondi') {
      return const _ComposerSuggestionGroup(
        key: 'hide-type',
        label: 'Cosa vuoi nascondere?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Piatto',
            icon: Icons.restaurant_menu_rounded,
            textToApply: 'Nascondi piatto ',
          ),
          _ComposerSuggestion(
            label: 'Categoria',
            icon: Icons.category_outlined,
            textToApply: 'Nascondi categoria ',
          ),
        ],
      );
    }

    final hideCategoryMatch = RegExp(
      r'^\s*nascondi\s+(?:la\s+)?categoria\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (hideCategoryMatch != null) {
      final query = _normalizeComposerText(hideCategoryMatch.group(1) ?? '');
      final suggestions = activeCategories
          .where((category) => _matchesComposerQuery(category.name, query))
          .where(
            (category) =>
                normalizedText !=
                _normalizeComposerText(
                  'Nascondi la categoria ${category.name}',
                ),
          )
          .take(20)
          .map(
            (category) => _ComposerSuggestion(
              label: category.name,
              icon: Icons.visibility_off_outlined,
              textToApply: 'Nascondi la categoria ${category.name}',
            ),
          )
          .toList();

      return _suggestionGroupOrNull(
        key: 'hide-category',
        label: 'Scegli una categoria',
        suggestions: suggestions,
      );
    }

    final activeCategoryById = {
      for (final category in activeCategories) category.id: category,
    };
    final hideItemMatch = RegExp(
      r'^\s*nascondi\s+(?:il\s+)?piatto\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (hideItemMatch != null) {
      final query = _normalizeComposerText(hideItemMatch.group(1) ?? '');
      final suggestions = <_ComposerSuggestion>[];

      for (final item in activeItems) {
        final category = activeCategoryById[item.categoryId];

        if (category == null ||
            !_matchesComposerQuery('${item.name} ${category.name}', query)) {
          continue;
        }

        suggestions.add(
          _ComposerSuggestion(
            label: '${item.name} · ${category.name}',
            icon: Icons.visibility_off_outlined,
            textToApply:
                'Nascondi il piatto ${item.name} della categoria ${category.name}',
          ),
        );

        if (suggestions.length >= 20) {
          break;
        }
      }

      return _suggestionGroupOrNull(
        key: 'hide-item',
        label: 'Scegli un piatto',
        suggestions: suggestions,
      );
    }

    if (normalizedText == 'riattiva') {
      return const _ComposerSuggestionGroup(
        key: 'reactivate-type',
        label: 'Cosa vuoi riattivare?',
        suggestions: [
          _ComposerSuggestion(
            label: 'Piatto',
            icon: Icons.restaurant_menu_rounded,
            textToApply: 'Riattiva piatto ',
          ),
          _ComposerSuggestion(
            label: 'Categoria',
            icon: Icons.category_outlined,
            textToApply: 'Riattiva categoria ',
          ),
        ],
      );
    }

    final reactivateCategoryMatch = RegExp(
      r'^\s*riattiva\s+(?:la\s+)?categoria\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (reactivateCategoryMatch != null) {
      final query = _normalizeComposerText(
        reactivateCategoryMatch.group(1) ?? '',
      );
      final suggestions = allCategories
          .where((category) => !category.menuCategoryActive)
          .where((category) => _matchesComposerQuery(category.name, query))
          .where(
            (category) =>
                normalizedText !=
                _normalizeComposerText(
                  'Riattiva la categoria ${category.name}',
                ),
          )
          .take(20)
          .map(
            (category) => _ComposerSuggestion(
              label: category.name,
              icon: Icons.visibility_outlined,
              textToApply: 'Riattiva la categoria ${category.name}',
            ),
          )
          .toList();

      return _suggestionGroupOrNull(
        key: 'reactivate-category',
        label: 'Scegli una categoria',
        suggestions: suggestions,
      );
    }

    final allCategoryById = {
      for (final category in allCategories) category.id: category,
    };
    final reactivateItemMatch = RegExp(
      r'^\s*riattiva\s+(?:il\s+)?piatto\s*(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (reactivateItemMatch != null) {
      final query = _normalizeComposerText(reactivateItemMatch.group(1) ?? '');
      final suggestions = <_ComposerSuggestion>[];

      for (final item in allItems) {
        final category = allCategoryById[item.categoryId];
        final canReactivateItem =
            category != null &&
            category.menuCategoryActive &&
            !item.menuItemActive;

        if (!canReactivateItem ||
            !_matchesComposerQuery('${item.name} ${category.name}', query)) {
          continue;
        }

        suggestions.add(
          _ComposerSuggestion(
            label: '${item.name} · ${category.name}',
            icon: Icons.visibility_outlined,
            textToApply:
                'Riattiva il piatto ${item.name} della categoria ${category.name}',
          ),
        );

        if (suggestions.length >= 20) {
          break;
        }
      }

      return _suggestionGroupOrNull(
        key: 'reactivate-item',
        label: 'Scegli un piatto',
        suggestions: suggestions,
      );
    }

    return null;
  }

  _ComposerSuggestionGroup? _suggestionGroupOrNull({
    required String key,
    required String label,
    required List<_ComposerSuggestion> suggestions,
  }) {
    if (suggestions.isEmpty) {
      return null;
    }

    return _ComposerSuggestionGroup(
      key: key,
      label: label,
      suggestions: suggestions,
    );
  }

  bool _matchesComposerQuery(String value, String normalizedQuery) {
    return normalizedQuery.isEmpty ||
        _normalizeComposerText(value).contains(normalizedQuery);
  }

  bool _containsComposerPrice(String value) {
    return RegExp(
      r'\d+(?:[.,]\d{1,2})?\s*(?:€|euro)',
      caseSensitive: false,
    ).hasMatch(value);
  }

  String _normalizeComposerText(String value) {
    var normalized = value.toLowerCase();
    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
    };

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _applyComposerText(String text) {
    if (!mounted) {
      return;
    }

    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _inputFocusNode.requestFocus();
    _ensureComposerVisible();
  }

  void _ensureComposerVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels > 24) {
        _scrollToBottom(extraOffset: 180);
      }
    });
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
    ref.invalidate(allMenuCategoriesProvider);
    ref.invalidate(menuItemsProvider);
    ref.invalidate(allMenuItemsProvider);
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

    final category = categories.first;
    final categoryId = category['id'] as String;

    await _client
        .from('menu_categories')
        .update({'menu_category_active': false})
        .eq('menu_id', menuId)
        .eq('id', categoryId);

    debugLines.add(
      'hide_category ok: $categoryName; stato dei piatti invariato',
    );
  }

  Future<void> _reactivateCategoryByName({
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
      debugLines.add(
        'reactivate_category: categoria non trovata: $categoryName',
      );
      return;
    }

    final category = categories.first;
    final categoryId = category['id'] as String;

    await _client
        .from('menu_categories')
        .update({'menu_category_active': true})
        .eq('menu_id', menuId)
        .eq('id', categoryId);

    debugLines.add(
      'reactivate_category ok: $categoryName; stato dei piatti invariato',
    );
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
      final item = raw;
      await _client
          .from('menu_items')
          .update({'menu_item_active': false})
          .eq('menu_id', menuId)
          .eq('id', item['id'] as String);
    }

    debugLines.add('hide_item ok: $itemName');
  }

  Future<_ReactivateItemResult> _reactivateItemByName({
    required String menuId,
    required String itemName,
    required String? categoryName,
    required List<String> debugLines,
  }) async {
    String? requestedCategoryId;

    if (categoryName != null && categoryName.trim().isNotEmpty) {
      final categories = await _client
          .from('menu_categories')
          .select('id')
          .eq('menu_id', menuId)
          .ilike('name', categoryName.trim());

      if ((categories as List).isNotEmpty) {
        requestedCategoryId = categories.first['id'] as String;
      }
    }

    var query = _client
        .from('menu_items')
        .select('id,name,category_id')
        .eq('menu_id', menuId)
        .ilike('name', itemName);

    if (requestedCategoryId != null) {
      query = query.eq('category_id', requestedCategoryId);
    }

    final items = await query;

    if ((items as List).isEmpty) {
      debugLines.add('reactivate_item: piatto non trovato: $itemName');
      return const _ReactivateItemResult(applied: false);
    }

    final categoryIds = <String>{};

    for (final raw in items) {
      final categoryId = raw['category_id'] as String?;

      if (categoryId != null && categoryId.isNotEmpty) {
        categoryIds.add(categoryId);
      }
    }

    for (final categoryId in categoryIds) {
      final categories = await _client
          .from('menu_categories')
          .select('id,name,menu_category_active')
          .eq('menu_id', menuId)
          .eq('id', categoryId)
          .limit(1);

      if ((categories as List).isEmpty) {
        continue;
      }

      final category = categories.first;
      final categoryActive =
          category['menu_category_active'] as bool? ?? true;

      if (!categoryActive) {
        final parentCategoryName =
            category['name'] as String? ?? categoryName ?? 'categoria';

        debugLines.add(
          'reactivate_item bloccata: categoria disattivata: $parentCategoryName',
        );

        return _ReactivateItemResult(
          applied: false,
          replyOverride:
              'Prima di riattivare il piatto "$itemName", devi riattivare la categoria "$parentCategoryName".',
        );
      }
    }

    for (final raw in items) {
      await _client
          .from('menu_items')
          .update({'menu_item_active': true})
          .eq('menu_id', menuId)
          .eq('id', raw['id'] as String);
    }

    debugLines.add('reactivate_item ok: $itemName');

    return const _ReactivateItemResult(applied: true);
  }

  List<Map<String, String>> _buildConversationContext() {
    const maxMessages = 8;
    const maxCharactersPerMessage = 1000;
    const maxTotalCharacters = 6000;

    final recentMessages = _messages.length <= maxMessages
        ? List<_ChatMessage>.from(_messages)
        : _messages.sublist(_messages.length - maxMessages);

    final context = <Map<String, String>>[];
    var remainingCharacters = maxTotalCharacters;

    for (final message in recentMessages.reversed) {
      if (remainingCharacters <= 0) {
        break;
      }

      var content = message.text.trim();

      if (content.isEmpty) {
        continue;
      }

      if (content.length > maxCharactersPerMessage) {
        content = content.substring(0, maxCharactersPerMessage);
      }

      if (content.length > remainingCharacters) {
        content = content.substring(0, remainingCharacters);
      }

      context.insert(0, {
        'role': message.isUser ? 'user' : 'assistant',
        'content': content,
      });

      remainingCharacters -= content.length;
    }

    return context;
  }

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    final conversationContext = _buildConversationContext();

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
        conversationContext: conversationContext,
      );

      int appliedActions = 0;
      String? replyOverride;
      final debugLines = <String>[
        'restaurantId: ${restaurant.id}',
        'menuId: ${menu.id}',
        'messaggi contesto: ${conversationContext.length}',
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

        if (action.type == 'reactivate_category') {
          final name = action.name?.trim();
          if (name == null || name.isEmpty) {
            debugLines.add('reactivate_category saltata: name vuoto');
            continue;
          }

          await _reactivateCategoryByName(
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

        if (action.type == 'reactivate_item') {
          final name = action.name?.trim();
          if (name == null || name.isEmpty) {
            debugLines.add('reactivate_item saltata: name vuoto');
            continue;
          }

          final result = await _reactivateItemByName(
            menuId: menu.id,
            itemName: name,
            categoryName: action.categoryName,
            debugLines: debugLines,
          );

          if (result.replyOverride != null) {
            replyOverride = result.replyOverride;
          }

          if (result.applied) {
            appliedActions++;
          }
          continue;
        }

        debugLines.add('azione non gestita: ${action.type}');
      }

      final finalReply = replyOverride ?? aiResult.reply;

      await aiRepo.saveHistory(
        restaurantId: restaurant.id,
        menuId: menu.id,
        prompt: prompt,
        aiResponse: finalReply,
        actionSummary: replyOverride ?? aiResult.summary,
        source: 'chat',
        menuSnapshot: snapshotBefore,
      );

      for (final line in debugLines) {
        debugPrint('[AI DEBUG] $line');
      }

      final resultMessage = appliedActions > 0
          ? '$finalReply\n\nAzioni applicate: $appliedActions'
          : finalReply;

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

class _ReactivateItemResult {
  final bool applied;
  final String? replyOverride;

  const _ReactivateItemResult({
    required this.applied,
    this.replyOverride,
  });
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

class _ComposerSuggestion {
  final String label;
  final IconData? icon;
  final String textToApply;

  const _ComposerSuggestion({
    required this.label,
    this.icon,
    required this.textToApply,
  });
}

class _ComposerSuggestionGroup {
  final String key;
  final String label;
  final List<_ComposerSuggestion> suggestions;

  const _ComposerSuggestionGroup({
    required this.key,
    required this.label,
    required this.suggestions,
  });
}
