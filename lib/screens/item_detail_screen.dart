import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/cost_calculations.dart';
import '../utils/csv_export.dart';
import '../utils/reference_id.dart';
import '../utils/stock_movement.dart';
import '../widgets/scrollable_data_table.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.itemId,
  });

  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late final SupabaseService _service;
  bool _loading = true;
  Map<String, dynamic>? _item;
  List<Map<String, dynamic>> _stockRows = [];
  List<Map<String, dynamic>> _purchaseRows = [];
  List<Map<String, dynamic>> _salesRows = [];
  List<StockMovementEntry> _movementRows = [];
  num _avgCost = 0;

  @override
  void initState() {
    super.initState();
    _service = SupabaseService(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchItems(userId),
      _service.fetchItemStock(userId),
      _service.fetchPurchaseDetails(userId),
      _service.fetchSales(userId),
    ]);

    final items = results[0];
    final stock = results[1];
    final purchases = results[2];
    final sales = results[3];

    final item = items.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['id'] == widget.itemId,
          orElse: () => null,
        );
    final avgCost = averageUnitCostForItem(
      purchases.cast<Map<String, dynamic>>(),
      widget.itemId,
    );

    setState(() {
      _item = item;
      _stockRows = stock.where((row) => row['item_id'] == widget.itemId).cast<Map<String, dynamic>>().toList();
      _purchaseRows = purchases.where((row) => row['item_id'] == widget.itemId).cast<Map<String, dynamic>>().toList();
      _salesRows = sales.where((row) => row['item_id'] == widget.itemId).cast<Map<String, dynamic>>().toList();
      _movementRows = buildStockMovementHistory(
        stockRows: stock.where((row) => row['item_id'] == widget.itemId).cast<Map<String, dynamic>>().toList(),
        purchaseRows: purchases.where((row) => row['item_id'] == widget.itemId).cast<Map<String, dynamic>>().toList(),
        salesRows: sales.where((row) => row['item_id'] == widget.itemId).cast<Map<String, dynamic>>().toList(),
      );
      _avgCost = avgCost;
      _loading = false;
    });
  }

  Future<void> _exportItemActivityCsv() {
    final item = _item;
    return exportCsvWithFeedback(
      context: context,
      baseName: item == null
          ? 'item_activity_export'
          : 'item_${formatReferenceId(item['id'], prefix: 'ITM').toLowerCase()}_activity',
      headers: const [
        'Movement Ref',
        'Movement Type',
        'Date',
        'Size',
        'Qty Change',
        'Notes',
      ],
      rows: _movementRows
          .map(
            (row) => [
              row.reference,
              _movementTypeLabel(row.type),
              _formatMovementDate(row.date),
              row.size ?? 'OS',
              _formatMovementChange(row.quantityChange),
              row.subtitle,
            ],
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final item = _item;
    if (item == null) {
      return Center(
        child: SectionCard(
          title: 'Item not found',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This item could not be loaded. It may have been deleted.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/items'),
                child: const Text('Back to Items'),
              ),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final totalUnits = _stockRows.fold<int>(0, (sum, row) => sum + (row['quantity'] as int? ?? 0));
    final totalRevenue = _salesRows.fold<num>(
      0,
      (sum, row) => sum + (row['sale_price'] as num? ?? 0),
    );
    final totalProfit = _salesRows.fold<num>(0, (sum, row) {
      final salePrice = row['sale_price'] as num? ?? 0;
      final fees = row['fees'] as num? ?? 0;
      final shipping = row['shipping_cost'] as num? ?? 0;
      return sum + (salePrice - fees - shipping - _avgCost);
    });

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/items'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Items'),
            ),
            OutlinedButton.icon(
              onPressed: _movementRows.isEmpty ? null : _exportItemActivityCsv,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export Item CSV'),
            ),
            Text(
              item['title'] ?? 'Item Detail',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (isMobile)
          Column(
            children: [
              _OverviewCard(item: item),
              const SizedBox(height: 16),
              _NotesCard(description: item['description'] as String?),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _OverviewCard(item: item),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _NotesCard(description: item['description'] as String?),
              ),
            ],
          ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 720;
            final crossAxisCount = isPhone ? 2 : constraints.maxWidth < 1100 ? 2 : 4;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              childAspectRatio: isPhone ? 1.9 : 6.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(label: 'Units In Stock', value: totalUnits.toString()),
                StatCard(label: 'Avg Cost', value: _currency(_avgCost)),
                StatCard(label: 'Total Revenue', value: _currency(totalRevenue)),
                StatCard(label: 'Total Profit', value: _currency(totalProfit)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        if (isMobile)
          Column(
            children: [
              SectionCard(
                title: 'Stock by size',
                child: _StockBreakdownList(rows: _stockRows),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Purchase history',
                child: _PurchaseHistoryList(rows: _purchaseRows),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Sales history',
                child: _SalesHistoryList(rows: _salesRows),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Stock movement history',
                child: _MovementHistoryList(rows: _movementRows),
              ),
            ],
          )
        else
          Column(
            children: [
              SizedBox(
                height: 360,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SectionCard(
                        title: 'Stock by size',
                        expandChild: true,
                        child: _StockBreakdownTable(rows: _stockRows),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: SectionCard(
                        title: 'Purchase history',
                        expandChild: true,
                        child: _PurchaseHistoryTable(rows: _purchaseRows),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 320,
                child: SectionCard(
                  title: 'Sales history',
                  expandChild: true,
                  child: _SalesHistoryTable(rows: _salesRows),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 320,
                child: SectionCard(
                  title: 'Stock movement history',
                  expandChild: true,
                  child: _MovementHistoryTable(rows: _movementRows),
                ),
              ),
            ],
          ),
      ],
    );

    return SingleChildScrollView(child: content);
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Overview',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailImage(
            imageUrl: item['main_image_url'] as String?,
            title: item['title'] as String? ?? '',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((item['brand'] as String?)?.trim().isNotEmpty == true)
                      _MetaChip(label: item['brand'] as String),
                    if ((item['category'] as String?)?.trim().isNotEmpty == true)
                      _MetaChip(label: item['category'] as String),
                    if ((item['created_at'] as String?)?.trim().isNotEmpty == true)
                      _MetaChip(
                        label: 'Created ${DateFormat.yMMMd().format(DateTime.parse(item['created_at'] as String))}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Notes',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF243247)),
        ),
        child: Text(
          (description == null || description!.trim().isEmpty)
              ? 'No notes or description added yet.'
              : description!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: description == null || description!.trim().isEmpty ? const Color(0xFF64748B) : const Color(0xFFE2E8F0),
              ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243247)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _DetailImage extends StatelessWidget {
  const _DetailImage({
    required this.imageUrl,
    required this.title,
  });

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF243247)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _ItemImage(
        imageUrl: imageUrl,
        emptyChild: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF64748B), size: 40),
        errorChild: Center(
          child: Text(
            title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

class _StockBreakdownTable extends StatelessWidget {
  const _StockBreakdownTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No stock rows for this item yet.');
    }
    return ScrollableDataTable(
      minWidth: 380,
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Stock Ref')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Updated')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(formatReferenceId(row['id'], prefix: 'STK'))),
                  DataCell(Text((row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS')),
                  DataCell(Text('${row['quantity'] ?? 0}')),
                  DataCell(Text(_formatTimestamp(row['updated_at'] as String?))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PurchaseHistoryTable extends StatelessWidget {
  const _PurchaseHistoryTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No purchase lines for this item yet.');
    }
    return ScrollableDataTable(
      minWidth: 620,
      table: DataTable(
        horizontalMargin: 18,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Line Ref')),
          DataColumn(label: Text('Bought Date')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Unit Price')),
          DataColumn(label: Text('Stock')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(formatReferenceId(row['id'], prefix: 'LIN'))),
                  DataCell(Text(_formatTimestamp(row['purchases']?['bought_date'] as String?))),
                  DataCell(Text((row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS')),
                  DataCell(Text('${row['quantity'] ?? 0}')),
                  DataCell(Text(_currency(row['unit_price'] as num? ?? 0))),
                  DataCell(Text(row['added_to_stock'] == true ? 'Added' : 'Pending')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SalesHistoryTable extends StatelessWidget {
  const _SalesHistoryTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No sales recorded for this item yet.');
    }
    return ScrollableDataTable(
      minWidth: 680,
      table: DataTable(
        horizontalMargin: 18,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Sale Ref')),
          DataColumn(label: Text('Sold Date')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Platform')),
          DataColumn(label: Text('Sale Price')),
          DataColumn(label: Text('Fees')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(formatReferenceId(row['id'], prefix: 'SAL'))),
                  DataCell(Text(_formatTimestamp(row['sold_date'] as String?))),
                  DataCell(Text((row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS')),
                  DataCell(Text(row['platform'] ?? '')),
                  DataCell(Text(_currency(row['sale_price'] as num? ?? 0))),
                  DataCell(Text(_currency(row['fees'] as num? ?? 0))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StockBreakdownList extends StatelessWidget {
  const _StockBreakdownList({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No stock rows for this item yet.');
    }
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SimpleHistoryCard(
                title: 'Size ${(row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] : 'OS'}',
                subtitle: 'Updated ${_formatTimestamp(row['updated_at'] as String?)}',
                trailing: 'Qty ${row['quantity'] ?? 0}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PurchaseHistoryList extends StatelessWidget {
  const _PurchaseHistoryList({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No purchase lines for this item yet.');
    }
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SimpleHistoryCard(
                title: _currency((row['unit_price'] as num? ?? 0) * (row['quantity'] as int? ?? 0)),
                subtitle:
                    '${_formatTimestamp(row['purchases']?['bought_date'] as String?)} | ${(row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] : 'OS'}',
                trailing: row['added_to_stock'] == true ? 'Added' : 'Pending',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SalesHistoryList extends StatelessWidget {
  const _SalesHistoryList({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No sales recorded for this item yet.');
    }
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SimpleHistoryCard(
                title: _currency(row['sale_price'] as num? ?? 0),
                subtitle:
                    '${_formatTimestamp(row['sold_date'] as String?)} | ${(row['platform'] as String?)?.trim().isNotEmpty == true ? row['platform'] : 'No platform'}',
                trailing: (row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MovementHistoryList extends StatelessWidget {
  const _MovementHistoryList({required this.rows});

  final List<StockMovementEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No stock movement history for this item yet.');
    }
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SimpleHistoryCard(
                title: '${_movementTypeLabel(row.type)} ${_formatMovementChange(row.quantityChange)}'.trim(),
                subtitle: '${_formatMovementDate(row.date)} | ${row.reference} | ${row.subtitle}',
                trailing: row.size ?? 'OS',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MovementHistoryTable extends StatelessWidget {
  const _MovementHistoryTable({required this.rows});

  final List<StockMovementEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptySection(message: 'No stock movement history for this item yet.');
    }
    return ScrollableDataTable(
      minWidth: 760,
      table: DataTable(
        horizontalMargin: 18,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Ref')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Movement')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Qty Change')),
          DataColumn(label: Text('Notes')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(row.reference)),
                  DataCell(Text(_formatMovementDate(row.date))),
                  DataCell(Text(_movementTypeLabel(row.type))),
                  DataCell(Text(row.size ?? 'OS')),
                  DataCell(Text(_formatMovementChange(row.quantityChange))),
                  DataCell(Text(row.subtitle)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SimpleHistoryCard extends StatelessWidget {
  const _SimpleHistoryCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
      ),
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({
    required this.imageUrl,
    required this.emptyChild,
    this.errorChild,
  });

  final String? imageUrl;
  final Widget emptyChild;
  final Widget? errorChild;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return emptyChild;
    }

    if (trimmed.startsWith('data:image/')) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex == -1) {
        return errorChild ?? emptyChild;
      }
      try {
        final bytes = base64Decode(trimmed.substring(commaIndex + 1));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => errorChild ?? emptyChild,
        );
      } catch (_) {
        return errorChild ?? emptyChild;
      }
    }

    return Image.network(
      trimmed,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => errorChild ?? emptyChild,
    );
  }
}

String _currency(num value) => NumberFormat.currency(symbol: '\u00A3').format(value);

String _formatTimestamp(String? value) {
  if (value == null || value.trim().isEmpty) return 'No date';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;

  final hasTime = parsed.hour != 0 || parsed.minute != 0 || parsed.second != 0;
  if (hasTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }
  return DateFormat('yyyy-MM-dd').format(parsed.toLocal());
}

String _formatMovementDate(DateTime? value) {
  if (value == null) return 'No date';
  final local = value.toLocal();
  final hasTime = local.hour != 0 || local.minute != 0 || local.second != 0;
  if (hasTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }
  return DateFormat('yyyy-MM-dd').format(local);
}

String _movementTypeLabel(StockMovementType type) {
  return switch (type) {
    StockMovementType.purchaseIn => 'Purchase In',
    StockMovementType.saleOut => 'Sale Out',
    StockMovementType.stockUpdate => 'Stock Update',
  };
}

String _formatMovementChange(int? value) {
  if (value == null) return '-';
  if (value > 0) return '+$value';
  return '$value';
}
