import 'package:supabase_flutter/supabase_flutter.dart';

class AiHistoryItem {
  final String id;
  final String restaurantId;
  final String? menuId;
  final String prompt;
  final String? aiResponse;
  final String? actionSummary;
  final String status;
  final String source;
  final DateTime createdAt;
  final String? restoredFromId;
  final Map<String, dynamic>? menuSnapshot;

  const AiHistoryItem({
    required this.id,
    required this.restaurantId,
    required this.menuId,
    required this.prompt,
    required this.aiResponse,
    required this.actionSummary,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.restoredFromId,
    required this.menuSnapshot,
  });

  factory AiHistoryItem.fromMap(Map<String, dynamic> map) {
    final snapshot = map['menu_snapshot'];
    return AiHistoryItem(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      menuId: map['menu_id'] as String?,
      prompt: map['prompt'] as String,
      aiResponse: map['ai_response'] as String?,
      actionSummary: map['action_summary'] as String?,
      status: map['status'] as String? ?? 'completed',
      source: map['source'] as String? ?? 'chat',
      createdAt: DateTime.parse(map['created_at'] as String),
      restoredFromId: map['restored_from_id'] as String?,
      menuSnapshot: snapshot is Map<String, dynamic> ? snapshot : null,
    );
  }
}

class AiAction {
  final String type;
  final Map<String, dynamic> raw;

  const AiAction({required this.type, required this.raw});

  String? get name => raw['name'] as String?;
  String? get categoryName => raw['categoryName'] as String?;
  String? get description => raw['description'] as String?;
  String? get currency => raw['currency'] as String?;

  int? get priceCents {
    final value = raw['priceCents'];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class AiResponsePayload {
  final String reply;
  final String summary;
  final List<AiAction> actions;
  final List<String> warnings;
  final Map<String, dynamic> rawData;

  const AiResponsePayload({
    required this.reply,
    required this.summary,
    required this.actions,
    required this.warnings,
    required this.rawData,
  });
}

class AiRepository {
  final SupabaseClient _client;

  AiRepository(this._client);

  Future<List<AiHistoryItem>> getHistory(String restaurantId) async {
    final response = await _client
        .from('ai_menu_history')
        .select()
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false)
        .limit(20);

    return (response as List)
        .map((e) => AiHistoryItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<AiResponsePayload> askAi({
    required String restaurantId,
    required String? menuId,
    required String prompt,
    required Map<String, dynamic> menuSnapshot,
    required List<Map<String, String>> conversationContext,
  }) async {
    final response = await _client.functions.invoke(
      'menu-ai',
      body: {
        'restaurantId': restaurantId,
        'menuId': menuId,
        'prompt': prompt,
        'menuSnapshot': menuSnapshot,
        'conversationContext': conversationContext,
      },
    );

    return _parseAiResponse(response.data);
  }

  AiResponsePayload _parseAiResponse(dynamic data) {
    if (data == null) {
      throw Exception('La function ha risposto senza body');
    }

    if (data is! Map<String, dynamic>) {
      throw Exception('Formato risposta non valido: $data');
    }

    final actions = <AiAction>[];
    final rawActions = data['actions'];

    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is Map<String, dynamic>) {
          final type = item['type'] as String?;
          if (type != null && type.isNotEmpty) {
            actions.add(AiAction(type: type, raw: item));
          }
        }
      }
    }

    final warnings = <String>[];
    final rawWarnings = data['warnings'];

    if (rawWarnings is List) {
      for (final item in rawWarnings) {
        if (item is String && item.trim().isNotEmpty) {
          warnings.add(item.trim());
        }
      }
    }

    return AiResponsePayload(
      reply: data['reply'] as String? ?? 'Ho elaborato la richiesta.',
      summary: data['summary'] as String? ?? 'Modifica menu',
      actions: actions,
      warnings: warnings,
      rawData: data,
    );
  }

  Future<void> saveHistory({
    required String restaurantId,
    required String? menuId,
    required String prompt,
    required String aiResponse,
    required String actionSummary,
    required String source,
    required Map<String, dynamic>? menuSnapshot,
  }) async {
    final userId = _client.auth.currentUser?.id;

    await _client.from('ai_menu_history').insert({
      'restaurant_id': restaurantId,
      'menu_id': menuId,
      'prompt': prompt,
      'ai_response': aiResponse,
      'action_summary': actionSummary,
      'status': 'completed',
      'source': source,
      'created_by': userId,
      'menu_snapshot': menuSnapshot,
    });
  }

  Future<void> saveRestoreHistory({
    required String restaurantId,
    required String? menuId,
    required AiHistoryItem item,
    required Map<String, dynamic>? menuSnapshot,
  }) async {
    final userId = _client.auth.currentUser?.id;

    await _client.from('ai_menu_history').insert({
      'restaurant_id': restaurantId,
      'menu_id': menuId,
      'prompt': 'Ripristino versione precedente',
      'ai_response': item.aiResponse,
      'action_summary': 'Ripristinata: ${item.actionSummary ?? 'Versione AI'}',
      'status': 'restored',
      'source': 'history_restore',
      'created_by': userId,
      'restored_from_id': item.id,
      'menu_snapshot': menuSnapshot,
    });
  }
}
