num averageUnitCostForItem(
  List<Map<String, dynamic>> purchaseRows,
  String? itemId,
) {
  if (itemId == null || itemId.isEmpty) {
    return 0;
  }

  num totalSpend = 0;
  int totalUnits = 0;

  for (final row in purchaseRows) {
    if (row['item_id'] != itemId) {
      continue;
    }

    final quantity = _toInt(row['quantity']);
    final unitPrice = _toNum(row['unit_price']);
    if (quantity <= 0) {
      continue;
    }

    totalUnits += quantity;
    totalSpend += unitPrice * quantity;
  }

  if (totalUnits == 0) {
    return 0;
  }

  return totalSpend / totalUnits;
}

num inventoryCostFromStock(
  List<Map<String, dynamic>> stockRows,
  List<Map<String, dynamic>> purchaseRows,
) {
  num total = 0;

  for (final stockRow in stockRows) {
    final quantity = _toInt(stockRow['quantity']);
    if (quantity <= 0) {
      continue;
    }

    total += averageUnitCostForItem(purchaseRows, stockRow['item_id'] as String?) * quantity;
  }

  return total;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}

num _toNum(dynamic value) {
  if (value is num) {
    return value;
  }
  return num.tryParse('$value') ?? 0;
}
