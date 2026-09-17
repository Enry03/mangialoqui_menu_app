class MenuAllergen {
  static const String gluten = 'gluten';
  static const String crustaceans = 'crustaceans';
  static const String eggs = 'eggs';
  static const String fish = 'fish';
  static const String peanuts = 'peanuts';
  static const String soy = 'soy';
  static const String milk = 'milk';
  static const String nuts = 'nuts';
  static const String celery = 'celery';
  static const String mustard = 'mustard';
  static const String sesame = 'sesame';
  static const String sulphites = 'sulphites';
  static const String lupin = 'lupin';
  static const String molluscs = 'molluscs';

  static const List<String> values = <String>[
    gluten,
    crustaceans,
    eggs,
    fish,
    peanuts,
    soy,
    milk,
    nuts,
    celery,
    mustard,
    sesame,
    sulphites,
    lupin,
    molluscs,
  ];

  static const Map<String, String> _labels = <String, String>{
    gluten: 'Glutine',
    crustaceans: 'Crostacei',
    eggs: 'Uova',
    fish: 'Pesce',
    peanuts: 'Arachidi',
    soy: 'Soia',
    milk: 'Latte',
    nuts: 'Frutta a guscio',
    celery: 'Sedano',
    mustard: 'Senape',
    sesame: 'Sesamo',
    sulphites: 'Solfiti',
    lupin: 'Lupini',
    molluscs: 'Molluschi',
  };

  static const Map<String, String> _aliases = <String, String>{
    gluten: gluten,
    'glutine': gluten,
    crustaceans: crustaceans,
    'crostacei': crustaceans,
    eggs: eggs,
    'uova': eggs,
    fish: fish,
    'pesce': fish,
    peanuts: peanuts,
    'arachidi': peanuts,
    soy: soy,
    'soia': soy,
    milk: milk,
    'latte': milk,
    'lattosio': milk,
    'latte / lattosio': milk,
    nuts: nuts,
    'frutta a guscio': nuts,
    celery: celery,
    'sedano': celery,
    mustard: mustard,
    'senape': mustard,
    sesame: sesame,
    'sesamo': sesame,
    sulphites: sulphites,
    'solfiti': sulphites,
    lupin: lupin,
    'lupini': lupin,
    molluscs: molluscs,
    'molluschi': molluscs,
  };

  static String normalize(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return _aliases[raw] ?? '';
  }

  static List<String> normalizeList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }

    final Iterable<dynamic> rawValues =
        value is Iterable && value is! String
        ? value
        : <dynamic>[value];

    final normalizedValues = <String>[];
    final addedValues = <String>{};

    for (final rawValue in rawValues) {
      final normalized = normalize(rawValue);

      if (normalized.isNotEmpty && addedValues.add(normalized)) {
        normalizedValues.add(normalized);
      }
    }

    return normalizedValues;
  }

  static String label(String value) {
    final normalized = normalize(value);
    return _labels[normalized] ?? value;
  }
}

class MenuItemModel {
  final String id;
  final String menuId;
  final String categoryId;
  final String name;
  final String? description;
  final int priceCents;
  final String currency;
  final bool isSoldOut;
  final bool menuItemActive;
  final int sortOrder;
  final List<String> allergens;
  final DateTime? createdAt;

  const MenuItemModel({
    required this.id,
    required this.menuId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.currency,
    required this.isSoldOut,
    required this.menuItemActive,
    required this.sortOrder,
    required this.allergens,
    required this.createdAt,
  });

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: (map['id'] ?? '').toString(),
      menuId: (map['menu_id'] ?? '').toString(),
      categoryId: (map['category_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: map['description']?.toString(),
      priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] ?? 'EUR').toString(),
      isSoldOut: map['is_sold_out'] == true,
      menuItemActive: map['menu_item_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      allergens: MenuAllergen.normalizeList(map['allergens']),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  String get formattedPrice {
    final value = (priceCents / 100).toStringAsFixed(2);
    return '€ $value';
  }
}