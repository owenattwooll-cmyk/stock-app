import 'dart:convert';

import 'package:intl/intl.dart';

class WhatnotImportResult {
  const WhatnotImportResult({
    required this.rows,
    required this.readyCount,
    required this.skippedCount,
  });

  final List<WhatnotImportRow> rows;
  final int readyCount;
  final int skippedCount;
}

class WhatnotImportRow {
  const WhatnotImportRow({
    required this.sourceRowNumber,
    required this.itemLabel,
    required this.itemId,
    required this.size,
    required this.quantity,
    required this.salePrice,
    required this.fees,
    required this.shipping,
    required this.soldDate,
    required this.sourceReference,
    required this.ready,
    required this.statusMessage,
    required this.failedOrCancelled,
  });

  final int sourceRowNumber;
  final String itemLabel;
  final String? itemId;
  final String? size;
  final int quantity;
  final num salePrice;
  final num fees;
  final num shipping;
  final DateTime? soldDate;
  final String? sourceReference;
  final bool ready;
  final String statusMessage;
  final bool failedOrCancelled;
}

WhatnotImportResult parseWhatnotSalesCsv({
  required String csv,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> stockRows,
}) {
  final rows = _parseCsv(csv);
  if (rows.length < 2) {
    return const WhatnotImportResult(rows: [], readyCount: 0, skippedCount: 0);
  }

  final headers = rows.first.map(_normalizeHeader).toList();
  final titleIndex = _findIndex(headers, const [
    'item',
    'itemname',
    'itemtitle',
    'productname',
    'listingtitle',
    'title',
  ]);
  final sizeIndex = _findIndex(headers, const ['size', 'variant', 'variation']);
  final priceIndex = _findIndex(headers, const [
    'saleprice',
    'soldprice',
    'price',
    'itemprice',
    'grosssales',
    'subtotal',
  ]);
  final feeIndex = _findIndex(headers, const [
    'fees',
    'whatnotfees',
    'sellerfees',
    'totalfees',
    'fee',
  ]);
  final shippingIndex = _findIndex(headers, const [
    'shipping',
    'shippingcost',
    'shippingcharged',
    'shippingfee',
  ]);
  final dateIndex = _findIndex(headers, const [
    'solddate',
    'saledate',
    'orderdate',
    'createdat',
    'purchasedat',
    'date',
  ]);
  final quantityIndex = _findIndex(headers, const ['quantity', 'qty', 'units', 'count']);
  final refIndex = _findIndex(headers, const ['orderid', 'order', 'transactionid', 'saleid']);
  final statusIndex = _findIndex(headers, const ['cancelledorfailed', 'status']);

  if (titleIndex == -1 || priceIndex == -1) {
    return WhatnotImportResult(
      rows: const [],
      readyCount: 0,
      skippedCount: 1,
    );
  }

  final itemByTitle = <String, Map<String, dynamic>>{};
  for (final item in items) {
    final title = (item['title'] as String?)?.trim();
    if (title == null || title.isEmpty) continue;
    itemByTitle.putIfAbsent(_normalizeValue(title), () => item);
  }

  final remainingStock = <String, int>{};
  for (final row in stockRows) {
    final itemId = row['item_id'] as String?;
    if (itemId == null || itemId.isEmpty) continue;
    final size = _normalizeValue((row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS');
    remainingStock['$itemId|$size'] = (row['quantity'] as int? ?? 0);
  }

  final importRows = <WhatnotImportRow>[];

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final rawTitle = _valueAt(row, titleIndex).trim();
    final rawSize = sizeIndex == -1 ? '' : _valueAt(row, sizeIndex).trim();
    final quantity = quantityIndex == -1 ? 1 : (_parseInt(_valueAt(row, quantityIndex)) ?? 1);
    final salePrice = _parseMoney(_valueAt(row, priceIndex)) ?? 0;
    final fees = feeIndex == -1 ? 0 : (_parseMoney(_valueAt(row, feeIndex)) ?? 0);
    final shipping = shippingIndex == -1 ? 0 : (_parseMoney(_valueAt(row, shippingIndex)) ?? 0);
    final soldDate = dateIndex == -1 ? null : _parseDate(_valueAt(row, dateIndex));
    final sourceReference = refIndex == -1 ? null : _valueAt(row, refIndex).trim();
    final status = statusIndex == -1 ? '' : _valueAt(row, statusIndex).trim().toLowerCase();
    final failedOrCancelled = status.contains('failed') || status.contains('cancel');

    if (rawTitle.isEmpty) {
      importRows.add(
        WhatnotImportRow(
          sourceRowNumber: i + 1,
          itemLabel: 'Missing item',
          itemId: null,
          size: rawSize.isEmpty ? null : rawSize,
          quantity: quantity,
          salePrice: salePrice,
          fees: fees,
          shipping: shipping,
          soldDate: soldDate,
          sourceReference: sourceReference,
          ready: false,
          statusMessage: 'Skipped: no item title found on this row.',
          failedOrCancelled: failedOrCancelled,
        ),
      );
      continue;
    }

    if (failedOrCancelled) {
      importRows.add(
        WhatnotImportRow(
          sourceRowNumber: i + 1,
          itemLabel: rawTitle,
          itemId: null,
          size: rawSize.isEmpty ? null : rawSize,
          quantity: quantity,
          salePrice: salePrice,
          fees: fees,
          shipping: shipping,
          soldDate: soldDate,
          sourceReference: sourceReference,
          ready: false,
          statusMessage: 'Skipped: order is marked as $status.',
          failedOrCancelled: true,
        ),
      );
      continue;
    }

    final matchedItem = itemByTitle[_normalizeValue(rawTitle)];
    final itemId = matchedItem?['id'] as String?;
    if (matchedItem == null || itemId == null || itemId.isEmpty) {
      importRows.add(
        WhatnotImportRow(
          sourceRowNumber: i + 1,
          itemLabel: rawTitle,
          itemId: null,
          size: rawSize.isEmpty ? null : rawSize,
          quantity: quantity,
          salePrice: salePrice,
          fees: fees,
          shipping: shipping,
          soldDate: soldDate,
          sourceReference: sourceReference,
          ready: false,
          statusMessage: 'Skipped: no matching item title exists in the app.',
          failedOrCancelled: failedOrCancelled,
        ),
      );
      continue;
    }

    final itemStockRows = stockRows.where((stock) => stock['item_id'] == itemId).toList();
    String? resolvedSize = rawSize.isEmpty ? null : rawSize;
    if (resolvedSize == null || resolvedSize.trim().isEmpty) {
      if (itemStockRows.length == 1) {
        resolvedSize = (itemStockRows.first['size'] as String?)?.trim().isNotEmpty == true
            ? itemStockRows.first['size'] as String
            : 'OS';
      }
    }

    final stockKey = '$itemId|${_normalizeValue((resolvedSize?.trim().isNotEmpty == true ? resolvedSize : 'OS')!)}';
    final available = remainingStock[stockKey] ?? 0;

    if (salePrice <= 0) {
      importRows.add(
        WhatnotImportRow(
          sourceRowNumber: i + 1,
          itemLabel: rawTitle,
          itemId: itemId,
          size: resolvedSize,
          quantity: quantity,
          salePrice: salePrice,
          fees: fees,
          shipping: shipping,
          soldDate: soldDate,
          sourceReference: sourceReference,
          ready: false,
          statusMessage: 'Skipped: sale price is missing or invalid.',
          failedOrCancelled: failedOrCancelled,
        ),
      );
      continue;
    }

    if (resolvedSize == null || resolvedSize.trim().isEmpty) {
      importRows.add(
        WhatnotImportRow(
          sourceRowNumber: i + 1,
          itemLabel: rawTitle,
          itemId: itemId,
          size: null,
          quantity: quantity,
          salePrice: salePrice,
          fees: fees,
          shipping: shipping,
          soldDate: soldDate,
          sourceReference: sourceReference,
          ready: false,
          statusMessage: 'Skipped: no size could be matched for this item.',
          failedOrCancelled: failedOrCancelled,
        ),
      );
      continue;
    }

    if (available < quantity) {
      importRows.add(
        WhatnotImportRow(
          sourceRowNumber: i + 1,
          itemLabel: rawTitle,
          itemId: itemId,
          size: resolvedSize,
          quantity: quantity,
          salePrice: salePrice,
          fees: fees,
          shipping: shipping,
          soldDate: soldDate,
          sourceReference: sourceReference,
          ready: false,
          statusMessage: 'Skipped: not enough stock is available for $resolvedSize.',
          failedOrCancelled: failedOrCancelled,
        ),
      );
      continue;
    }

    remainingStock[stockKey] = available - quantity;

    importRows.add(
      WhatnotImportRow(
        sourceRowNumber: i + 1,
        itemLabel: rawTitle,
        itemId: itemId,
        size: resolvedSize,
        quantity: quantity,
        salePrice: salePrice,
        fees: fees,
        shipping: shipping,
        soldDate: soldDate,
        sourceReference: sourceReference,
        ready: true,
        statusMessage: 'Ready to import',
        failedOrCancelled: failedOrCancelled,
      ),
    );
  }

  final readyCount = importRows.where((row) => row.ready).length;
  return WhatnotImportResult(
    rows: importRows,
    readyCount: readyCount,
    skippedCount: importRows.length - readyCount,
  );
}

String decodeCsvBytes(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  return text;
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final currentCell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];

    if (char == '"') {
      if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
        currentCell.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && char == ',') {
      currentRow.add(currentCell.toString());
      currentCell.clear();
      continue;
    }

    if (!inQuotes && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i++;
      }
      currentRow.add(currentCell.toString());
      currentCell.clear();
      rows.add(List<String>.from(currentRow));
      currentRow.clear();
      continue;
    }

    currentCell.write(char);
  }

  if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(currentCell.toString());
    rows.add(List<String>.from(currentRow));
  }

  return rows.where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
}

String _normalizeHeader(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _normalizeValue(String value) => value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

int _findIndex(List<String> headers, List<String> candidates) {
  for (final candidate in candidates) {
    final index = headers.indexOf(candidate);
    if (index != -1) return index;
  }
  return -1;
}

String _valueAt(List<String> row, int index) => index >= 0 && index < row.length ? row[index] : '';

num? _parseMoney(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (cleaned.isEmpty) return null;
  final normalized = cleaned.contains(',') && cleaned.contains('.')
      ? cleaned.replaceAll(',', '')
      : RegExp(r'^-?\d{1,3}(,\d{3})+$').hasMatch(cleaned)
          ? cleaned.replaceAll(',', '')
          : cleaned.replaceAll(',', '.');
  return num.tryParse(normalized);
}

int? _parseInt(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[^0-9\-]'), '');
  if (cleaned.isEmpty) return null;
  return int.tryParse(cleaned);
}

DateTime? _parseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final direct = DateTime.tryParse(trimmed);
  if (direct != null) return direct;

  const patterns = [
    'M/d/yyyy',
    'M/d/yyyy H:mm',
    'M/d/yyyy h:mm a',
    'MM/dd/yyyy',
    'MM/dd/yyyy H:mm',
    'MM/dd/yyyy h:mm a',
    'yyyy-MM-dd',
    'yyyy-MM-dd H:mm:ss',
    'yyyy-MM-dd HH:mm:ss',
  ];
  for (final pattern in patterns) {
    try {
      return DateFormat(pattern).parse(trimmed);
    } catch (_) {
      // continue
    }
  }
  return null;
}
