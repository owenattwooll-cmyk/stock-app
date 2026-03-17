import 'reference_id.dart';

enum StockMovementType {
  purchaseIn,
  saleOut,
  stockUpdate,
}

class StockMovementEntry {
  const StockMovementEntry({
    required this.type,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.reference,
    this.size,
    this.quantityChange,
  });

  final StockMovementType type;
  final DateTime? date;
  final String title;
  final String subtitle;
  final String reference;
  final String? size;
  final int? quantityChange;
}

List<StockMovementEntry> buildStockMovementHistory({
  required List<Map<String, dynamic>> stockRows,
  required List<Map<String, dynamic>> purchaseRows,
  required List<Map<String, dynamic>> salesRows,
}) {
  final entries = <StockMovementEntry>[
    ...purchaseRows
        .where((row) => row['added_to_stock'] == true)
        .map(
          (row) => StockMovementEntry(
            type: StockMovementType.purchaseIn,
            date: _parseDate(row['purchases']?['bought_date'] as String?) ?? _parseDate(row['created_at'] as String?),
            title: 'Added from purchase',
            subtitle: 'Purchase line moved into stock',
            reference: formatReferenceId(row['id'], prefix: 'LIN'),
            size: _normalizeSize(row['size'] as String?),
            quantityChange: row['quantity'] as int? ?? 0,
          ),
        ),
    ...salesRows.map(
      (row) => StockMovementEntry(
        type: StockMovementType.saleOut,
        date: _parseDate(row['sold_date'] as String?) ?? _parseDate(row['created_at'] as String?),
        title: 'Sale recorded',
        subtitle: ((row['platform'] as String?)?.trim().isNotEmpty == true)
            ? 'Sold on ${row['platform']}'
            : 'Sold item',
        reference: formatReferenceId(row['id'], prefix: 'SAL'),
        size: _normalizeSize(row['size'] as String?),
        quantityChange: -1,
      ),
    ),
    ...stockRows.map(
      (row) => StockMovementEntry(
        type: StockMovementType.stockUpdate,
        date: _parseDate(row['updated_at'] as String?),
        title: 'Stock row updated',
        subtitle: 'Current quantity set to ${row['quantity'] ?? 0}',
        reference: formatReferenceId(row['id'], prefix: 'STK'),
        size: _normalizeSize(row['size'] as String?),
        quantityChange: null,
      ),
    ),
  ];

  entries.sort((a, b) {
    final aDate = a.date;
    final bDate = b.date;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return entries;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String _normalizeSize(String? size) {
  if (size == null || size.trim().isEmpty) {
    return 'OS';
  }
  return size;
}
