//* Servizio unico per gestire i prezzi.
//* Nel database i prezzi restano sempre in centesimi interi.
//* La UI può mostrare euro, ma i calcoli importanti devono usare cents.

class MoneyService {
  static int? euroTextToCents(String rawText) {
    final text = rawText.trim().replaceAll('€', '').replaceAll(' ', '');

    if (text.isEmpty) return null;

    //* Accetta:
    //* 12
    //* 12,5
    //* 12,50
    //* 12.50
    //*
    //* Rifiuta:
    //* 1.200
    //* 12,345
    //* 12,50,3
    final valid = RegExp(r'^\d+([,.]\d{1,2})?$').hasMatch(text);
    if (!valid) return null;

    final normalized = text.replaceAll(',', '.');
    final parts = normalized.split('.');

    final euro = int.tryParse(parts[0]);
    if (euro == null) return null;

    int cents = 0;
    if (parts.length == 2) {
      final centsText = parts[1].padRight(2, '0');
      cents = int.tryParse(centsText) ?? 0;
    }

    return (euro * 100) + cents;
  }

  static int euroToCents(double euro) {
    return (euro * 100).round();
  }

  static double centsToEuro(int cents) {
    return cents / 100.0;
  }

  static int centsFromDynamic(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final cents = value.toInt();
      return cents < 0 ? 0 : cents;
    }

    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed < 0) return 0;

    return parsed;
  }

  static int lineTotalCents({
    required int unitPriceCents,
    required int quantity,
  }) {
    if (unitPriceCents <= 0 || quantity <= 0) return 0;
    return unitPriceCents * quantity;
  }

  static String centsToEuroText(int cents, {bool withSymbol = true}) {
    final negative = cents < 0;
    final safeCents = cents.abs();

    final euro = safeCents ~/ 100;
    final rest = safeCents % 100;

    final text =
        '${negative ? '-' : ''}$euro,${rest.toString().padLeft(2, '0')}';

    return withSymbol ? '$text €' : text;
  }
}
