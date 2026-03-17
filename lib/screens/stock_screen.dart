import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../widgets/scrollable_data_table.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late final SupabaseService _service;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _purchaseDetails = [];
  List<Map<String, dynamic>> _costs = [];
  String _categoryFilter = 'All';
  String _availabilityFilter = 'All';

  @override
  void initState() {
    super.initState();
    _service = SupabaseService(Supabase.instance.client);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchItemStock(userId),
      _service.fetchItems(userId),
      _service.fetchPurchaseDetails(userId),
      _service.fetchItemCosts(userId),
    ]);
    setState(() {
      _stock = results[0];
      _items = results[1];
      _purchaseDetails = results[2];
      _costs = results[3];
      _loading = false;
    });
  }

  Future<void> _openManageDialog(String itemId) async {
    final itemStock = _stock.where((row) => row['item_id'] == itemId).toList();
    final itemPurchases = _purchaseDetails.where((row) => row['item_id'] == itemId).toList();

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700 ? 12 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manage Stock', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Adjust Stock'),
                      Tab(text: 'Purchase History'),
                    ],
                  ),
                  SizedBox(
                    height: 360,
                    child: TabBarView(
                      children: [
                        ListView.builder(
                          itemCount: itemStock.length,
                          itemBuilder: (context, index) {
                            final row = itemStock[index];
                            final controller = TextEditingController(text: row['quantity'].toString());
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(row['size'] ?? 'One Size'),
                              subtitle: Text('Available: ${row['quantity']}'),
                              trailing: SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  onSubmitted: (value) async {
                                    await _service.updateItemStock(
                                      row['id'] as String,
                                      {'quantity': int.tryParse(value) ?? row['quantity']},
                                    );
                                    await _load();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        ListView.builder(
                          itemCount: itemPurchases.length,
                          itemBuilder: (context, index) {
                            final purchase = itemPurchases[index];
                            final purchaseDate = purchase['purchases']?['bought_date'] as String?;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Qty ${purchase['quantity']} @ ${_currency(purchase['unit_price'] as num)}'),
                              subtitle: Text(purchaseDate ?? 'No date'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  await _service.deletePurchaseDetail(purchase['id'] as String);
                                  await _load();
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStockDetails(Map<String, dynamic> item) async {
    final itemStock = _stock.where((row) => row['item_id'] == item['id']).toList();
    final avgCost = _costs
            .firstWhere(
              (cost) => cost['item_id'] == item['id'],
              orElse: () => {'avg_unit_cost': 0},
            )['avg_unit_cost'] as num? ??
        0;
    final totalQty = itemStock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title'] ?? '', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                itemStock.map((row) => '${row['size'] ?? 'OS'}: ${row['quantity']}').join(' | '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _MobileStockDetailRow(label: 'Avg Cost', value: _currency(avgCost)),
              _MobileStockDetailRow(label: 'Total Qty', value: totalQty.toString()),
              _MobileStockDetailRow(label: 'Available', value: totalQty.toString()),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openManageDialog(item['id'] as String);
                },
                icon: const Icon(Icons.tune),
                label: const Text('Manage Stock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredItems() {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      final itemStock = _stock.where((row) => row['item_id'] == item['id']).toList();
      if (itemStock.isEmpty) {
        return false;
      }
      final totalQty = itemStock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
      final matchesCategory = _categoryFilter == 'All' || item['category'] == _categoryFilter;
      final matchesAvailability = switch (_availabilityFilter) {
        'Low Stock' => totalQty <= 2,
        'Healthy Stock' => totalQty > 2,
        _ => true,
      };
      if (!matchesCategory || !matchesAvailability) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }

      final sizeLabels = itemStock
          .map((row) => ((row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS').toLowerCase())
          .join(' ');

      return [
        item['title'],
        item['brand'],
        item['category'],
      ].whereType<String>().any((value) => value.toLowerCase().contains(query)) ||
          sizeLabels.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final categoryOptions = [
      'All',
      ..._items
          .map((item) => item['category'])
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final filteredItems = _filteredItems();
    final totalUnits = _stock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
    final itemsInStock = _stock.map((row) => row['item_id']).toSet().length;
    final inventoryCost = _costs.fold<num>(
      0,
      (sum, cost) => sum + (cost['avg_unit_cost'] as num? ?? 0) * (cost['total_purchased_qty'] as int? ?? 0),
    );
    final totalSpend = _purchaseDetails.fold<num>(
      0,
      (sum, row) => sum + (row['unit_price'] as num) * (row['quantity'] as int),
    );

    final tableSection = _loading
        ? const Center(child: CircularProgressIndicator())
        : filteredItems.isEmpty
            ? const _StockEmptyState(
                message: 'No stock rows match this search yet.',
              )
        : isMobile
            ? Column(
                children: filteredItems
                    .map(
                      (item) {
                        final itemStock = _stock.where((row) => row['item_id'] == item['id']).toList();
                        if (itemStock.isEmpty) return null;
                        final totalQty = itemStock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MobileStockCard(
                            onTap: () => _showStockDetails(item),
                            title: item['title'] ?? '',
                            subtitle: itemStock
                                .take(2)
                                .map((row) => '${row['size'] ?? 'OS'}: ${row['quantity']}')
                                .join(' | '),
                            amount: '$totalQty units',
                          ),
                        );
                      },
                    )
                    .whereType<Widget>()
                    .toList(),
              )
            : SectionCard(
                title: 'Stock',
                expandChild: true,
                child: ScrollableDataTable(
                  minWidth: 1180,
                  table: DataTable(
                  columns: const [
                    DataColumn(label: Text('Image')),
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Sizes')),
                    DataColumn(label: Text('Avg Cost')),
                    DataColumn(label: Text('Total Qty')),
                    DataColumn(label: Text('Available')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filteredItems
                      .map(
                        (item) {
                          final itemStock = _stock.where((row) => row['item_id'] == item['id']).toList();
                          if (itemStock.isEmpty) return null;
                          final avgCost = _costs
                                  .firstWhere(
                                    (cost) => cost['item_id'] == item['id'],
                                    orElse: () => {'avg_unit_cost': 0},
                                  )['avg_unit_cost'] as num? ??
                              0;
                          final totalQty = itemStock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
                          return DataRow(
                            cells: [
                              DataCell(
                                item['main_image_url'] == null
                                    ? const Icon(Icons.image_not_supported)
                                    : Image.network(
                                        item['main_image_url'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              DataCell(Text(item['title'] ?? '')),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: itemStock
                                      .map((row) => Chip(label: Text('${row['size'] ?? 'OS'}: ${row['quantity']}')))
                                      .toList(),
                                ),
                              ),
                              DataCell(Text(_currency(avgCost))),
                              DataCell(Text(totalQty.toString())),
                              DataCell(Text(totalQty.toString())),
                              DataCell(
                                TextButton(
                                  onPressed: () => _openManageDialog(item['id'] as String),
                                  child: const Text('Manage'),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                      .whereType<DataRow>()
                      .toList(),
                ),
              ),
            );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock', style: Theme.of(context).textTheme.headlineMedium),
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
              childAspectRatio: isPhone ? 1.9 : 3.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(label: 'Items in Stock', value: itemsInStock.toString()),
                StatCard(label: 'Total Units', value: totalUnits.toString()),
                StatCard(label: 'Inventory Cost', value: _currency(inventoryCost)),
                StatCard(label: 'Total Spend', value: _currency(totalSpend)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search by item, brand, category, or size',
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: _categoryFilter,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categoryOptions
                    .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _categoryFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: _availabilityFilter,
                decoration: const InputDecoration(labelText: 'Availability'),
                items: const ['All', 'Low Stock', 'Healthy Stock']
                    .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _availabilityFilter = value ?? 'All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isMobile) tableSection else Expanded(child: tableSection),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(child: content);
    }

    return content;
  }
}

String _currency(num value) => NumberFormat.currency(symbol: '\u00A3').format(value);

class _MobileStockCard extends StatelessWidget {
  const _MobileStockCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Color(0xFF4F46E5)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(subtitle.isEmpty ? '-' : subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileStockDetailRow extends StatelessWidget {
  const _MobileStockDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StockEmptyState extends StatelessWidget {
  const _StockEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Stock',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
              ),
        ),
      ),
    );
  }
}
