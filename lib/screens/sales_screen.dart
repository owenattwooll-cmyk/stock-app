import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../widgets/scrollable_data_table.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final SupabaseService _service;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _costs = [];

  String _platformFilter = 'All';
  String _timeframe = 'All';
  String _itemFilter = 'All';

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
      _service.fetchSales(userId),
      _service.fetchItemStock(userId),
      _service.fetchItems(userId),
      _service.fetchItemCosts(userId),
    ]);
    setState(() {
      _sales = results[0];
      _stock = results[1];
      _items = results[2];
      _costs = results[3];
      _loading = false;
    });
  }

  Future<void> _openSaleDialog({Map<String, dynamic>? sale}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    String? selectedItemId = sale?['item_id'] as String?;
    String? selectedSize = sale?['size'] as String?;
    DateTime? soldDate = sale?['sold_date'] == null
        ? DateTime.now()
        : DateTime.parse(sale?['sold_date'] as String);

    final platformController = TextEditingController(text: sale?['platform'] ?? '');
    final priceController = TextEditingController(text: sale?['sale_price']?.toString() ?? '');
    final feesController = TextEditingController(text: sale?['fees']?.toString() ?? '');
    final shippingController = TextEditingController(text: sale?['shipping_cost']?.toString() ?? '');
    const platformOptions = ['Vinted', 'Depop', 'eBay', 'Tilt'];

    final result = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(15, 23, 42, 0.38),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sizeOptions = _saleSizeOptions(selectedItemId);
          final selectedItem = _items.cast<Map<String, dynamic>?>().firstWhere(
                (item) => item?['id'] == selectedItemId,
                orElse: () => null,
              );
          final previewSubtitle = [
            if ((selectedItem?['brand'] as String?)?.isNotEmpty == true)
              selectedItem?['brand'] as String,
            if (selectedSize?.isNotEmpty == true) selectedSize!,
            if (platformController.text.trim().isNotEmpty) platformController.text.trim(),
          ].join(' | ');

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale == null ? 'Add Sale' : 'Edit Sale',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select an item with stock, choose the sold size, then record the platform, pricing, and sold date.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 700;

                          final form = Column(
                            children: [
                              _SaleFormField(
                                label: 'Item',
                                child: _SalePickerField(
                                  value: _itemLabel(selectedItemId),
                                  hintText: 'Choose an item',
                                  helperText: _items.isEmpty ? 'No items found yet.' : null,
                                  onTap: () async {
                                    final picked = await _showSaleSearchPicker(
                                      context: context,
                                      title: 'Choose item',
                                      options: _items
                                          .map(
                                            (item) => _SalePickerOption(
                                              value: item['id'] as String,
                                              label: item['title'] as String? ?? 'Untitled item',
                                              meta: (item['brand'] as String?)?.trim(),
                                            ),
                                          )
                                          .toList(),
                                      currentValue: selectedItemId,
                                    );
                                    if (picked == null && selectedItemId == null) return;
                                    setDialogState(() {
                                      selectedItemId = picked;
                                      final validSizes =
                                          _saleSizeOptions(selectedItemId).map((row) => row.value).toSet();
                                      if (!validSizes.contains(selectedSize)) {
                                        selectedSize = null;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SaleFormField(
                                label: 'Size / Stock',
                                child: _SalePickerField(
                                  value: selectedSize,
                                  hintText: selectedItemId == null ? 'Select an item first' : 'Choose a size',
                                  enabled: selectedItemId != null,
                                  helperText: sizeOptions.isEmpty && selectedItemId != null
                                      ? 'No stock rows are available for this item yet.'
                                      : 'Only sizes currently in stock are shown.',
                                  onTap: () async {
                                    if (selectedItemId == null) return;
                                    final picked = await _showSaleSearchPicker(
                                      context: context,
                                      title: 'Choose size / stock',
                                      options: sizeOptions,
                                      currentValue: selectedSize,
                                    );
                                    if (picked != null || selectedSize != null) {
                                      setDialogState(() => selectedSize = picked);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SaleFormField(
                                label: 'Platform',
                                child: _SalePickerField(
                                  value: platformController.text.trim().isEmpty ? null : platformController.text.trim(),
                                  hintText: 'Choose a platform',
                                  onTap: () async {
                                    final picked = await _showSaleSearchPicker(
                                      context: context,
                                      title: 'Choose platform',
                                      options: platformOptions
                                          .map(
                                            (platform) => _SalePickerOption(
                                              value: platform,
                                              label: platform,
                                            ),
                                          )
                                          .toList(),
                                      currentValue:
                                          platformController.text.trim().isEmpty ? null : platformController.text.trim(),
                                    );
                                    if (picked != null || platformController.text.trim().isNotEmpty) {
                                      setDialogState(() => platformController.text = picked ?? '');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _SaleFormField(
                                      label: 'Sale Price',
                                      child: TextField(
                                        controller: priceController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: const InputDecoration(
                                          prefixText: '\u00A3',
                                          hintText: '0.00',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _SaleFormField(
                                      label: 'Fees',
                                      child: TextField(
                                        controller: feesController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: const InputDecoration(
                                          prefixText: '\u00A3',
                                          hintText: '0.00',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _SaleFormField(
                                      label: 'Shipping Cost',
                                      child: TextField(
                                        controller: shippingController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: const InputDecoration(
                                          prefixText: '\u00A3',
                                          hintText: '0.00',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _SaleFormField(
                                      label: 'Sold Date',
                                      child: _SalePickerField(
                                        value: soldDate == null ? null : DateFormat('yyyy-MM-dd').format(soldDate!),
                                        hintText: 'Choose a date',
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now(),
                                            initialDate: soldDate ?? DateTime.now(),
                                          );
                                          if (picked != null) {
                                            setDialogState(() => soldDate = picked);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );

                          final preview = _SalePreviewCard(
                            itemTitle: _itemLabel(selectedItemId) ?? 'Sale preview',
                            subtitle: previewSubtitle,
                            salePrice: num.tryParse(priceController.text) ?? 0,
                            fees: num.tryParse(feesController.text) ?? 0,
                            shipping: num.tryParse(shippingController.text) ?? 0,
                            soldDate: soldDate,
                          );

                          if (stacked) {
                            return Column(
                              children: [
                                form,
                                const SizedBox(height: 18),
                                preview,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: form),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: preview),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(sale == null ? 'Save Sale' : 'Update Sale'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != true || selectedItemId == null) return;

    final payload = {
      'item_id': selectedItemId,
      'user_id': userId,
      'size': selectedSize,
      'platform': platformController.text.trim(),
      'sale_price': num.tryParse(priceController.text) ?? 0,
      'fees': num.tryParse(feesController.text) ?? 0,
      'shipping_cost': num.tryParse(shippingController.text) ?? 0,
      'sold_date': soldDate?.toIso8601String(),
    };

    if (sale == null) {
      await _service.createSale(payload);
      _showToast('Sale added.');
    } else {
      await _service.updateSale(sale['id'] as String, payload);
      _showToast('Sale updated.');
    }
    await _load();
  }

  Future<void> _deleteSale(String id) async {
    await _service.deleteSale(id);
    await _load();
    _showToast('Sale deleted.');
  }

  List<Map<String, dynamic>> _filteredSales() {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    return _sales.where((sale) {
      if (_platformFilter != 'All' && sale['platform'] != _platformFilter) {
        return false;
      }
      final item = _items.firstWhere(
        (row) => row['id'] == sale['item_id'],
        orElse: () => {},
      );
      if (_itemFilter != 'All' && sale['item_id'] != _itemFilter) {
        return false;
      }
      final matchesQuery = query.isEmpty ||
          [
            item['title'],
            sale['platform'],
            sale['size'],
          ].whereType<String>().any((value) => value.toLowerCase().contains(query));
      if (!matchesQuery) {
        return false;
      }
      final soldDate = sale['sold_date'] == null ? null : DateTime.parse(sale['sold_date'] as String);
      if (_timeframe == 'Daily' && soldDate != null) {
        return soldDate.isAfter(now.subtract(const Duration(days: 1)));
      }
      if (_timeframe == 'Weekly' && soldDate != null) {
        return soldDate.isAfter(now.subtract(const Duration(days: 7)));
      }
      if (_timeframe == 'Monthly' && soldDate != null) {
        return soldDate.isAfter(now.subtract(const Duration(days: 30)));
      }
      return true;
    }).toList();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSaleDetails(Map<String, dynamic> sale) async {
    final item = _items.firstWhere(
      (row) => row['id'] == sale['item_id'],
      orElse: () => {},
    );
    final avgCost = _costs
            .firstWhere(
              (cost) => cost['item_id'] == sale['item_id'],
              orElse: () => {'avg_unit_cost': 0},
            )['avg_unit_cost'] as num? ??
        0;
    final profit = (sale['sale_price'] as num? ?? 0) -
        (sale['fees'] as num? ?? 0) -
        (sale['shipping_cost'] as num? ?? 0) -
        avgCost;

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
                [sale['size'] ?? 'OS', sale['platform'] ?? '']
                    .where((value) => (value as String).toString().isNotEmpty)
                    .join(' | '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _MobileSaleDetailRow(label: 'Sale Price', value: _currency(sale['sale_price'] as num? ?? 0)),
              _MobileSaleDetailRow(label: 'Fees', value: _currency(sale['fees'] as num? ?? 0)),
              _MobileSaleDetailRow(label: 'Shipping', value: _currency(sale['shipping_cost'] as num? ?? 0)),
              _MobileSaleDetailRow(label: 'Profit', value: _currency(profit)),
              _MobileSaleDetailRow(
                label: 'Sold Date',
                value: sale['sold_date'] == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd').format(DateTime.parse(sale['sold_date'] as String)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openSaleDialog(sale: sale);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteSale(sale['id'] as String);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _itemLabel(String? itemId) {
    if (itemId == null) return null;
    final item = _items.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['id'] == itemId,
          orElse: () => null,
        );
    return item?['title'] as String?;
  }

  List<_SalePickerOption> _saleSizeOptions(String? itemId) {
    if (itemId == null) return [];
    return _stock
        .where((row) => row['item_id'] == itemId)
        .map(
          (row) => _SalePickerOption(
            value: (row['size'] as String?) ?? '',
            label: (row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS',
            meta: 'Available: ${(row['quantity'] ?? 0)}',
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final filteredSales = _filteredSales();
    final platforms = [
      'All',
      ..._sales
          .map((row) => row['platform'])
          .whereType<String>()
          .where((platform) => platform.isNotEmpty)
          .toSet(),
    ];
    final itemOptions = [
      'All',
      ..._sales
          .map((row) => row['item_id'])
          .whereType<String>()
          .toSet(),
    ];
    final totalRevenue = filteredSales.fold<num>(
      0,
      (sum, row) => sum + (row['sale_price'] as num? ?? 0),
    );
    final totalProfit = filteredSales.fold<num>(0, (sum, row) {
      final salePrice = row['sale_price'] as num? ?? 0;
      final fees = row['fees'] as num? ?? 0;
      final shipping = row['shipping_cost'] as num? ?? 0;
      final itemId = row['item_id'] as String?;
      final avgCost = _costs
              .firstWhere(
                (cost) => cost['item_id'] == itemId,
                orElse: () => {'avg_unit_cost': 0},
              )['avg_unit_cost'] as num? ??
          0;
      return sum + (salePrice - fees - shipping - avgCost);
    });

    final tableSection = _loading
        ? const Center(child: CircularProgressIndicator())
        : filteredSales.isEmpty
            ? const _SalesEmptyState(
                message: 'No sales match these filters yet.',
              )
        : isMobile
            ? Column(
                children: filteredSales
                    .map(
                      (sale) {
                        final item = _items.firstWhere(
                          (row) => row['id'] == sale['item_id'],
                          orElse: () => {},
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MobileSaleCard(
                            onTap: () => _showSaleDetails(sale),
                            title: item['title'] ?? '',
                            subtitle: [sale['size'] ?? 'OS', sale['platform'] ?? '']
                                .where((value) => (value as String).toString().isNotEmpty)
                                .join(' | '),
                            amount: _currency(sale['sale_price'] as num? ?? 0),
                            meta: sale['sold_date'] == null
                                ? 'No date'
                                : DateFormat('yyyy-MM-dd').format(DateTime.parse(sale['sold_date'] as String)),
                          ),
                        );
                      },
                    )
                    .toList(),
              )
            : SectionCard(
                title: 'Sales',
                expandChild: true,
                child: ScrollableDataTable(
                  minWidth: 1280,
                  table: DataTable(
                  columns: const [
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Size')),
                    DataColumn(label: Text('Platform')),
                    DataColumn(label: Text('Sale Price')),
                    DataColumn(label: Text('Fees')),
                    DataColumn(label: Text('Shipping')),
                    DataColumn(label: Text('Sold Date')),
                    DataColumn(label: Text('Profit')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filteredSales
                      .map(
                        (sale) {
                          final item = _items.firstWhere(
                            (item) => item['id'] == sale['item_id'],
                            orElse: () => {},
                          );
                          final avgCost = _costs
                                  .firstWhere(
                                    (cost) => cost['item_id'] == sale['item_id'],
                                    orElse: () => {'avg_unit_cost': 0},
                                  )['avg_unit_cost'] as num? ??
                              0;
                          final profit = (sale['sale_price'] as num? ?? 0) -
                              (sale['fees'] as num? ?? 0) -
                              (sale['shipping_cost'] as num? ?? 0) -
                              avgCost;
                          return DataRow(
                            cells: [
                              DataCell(Text(item['title'] ?? '')),
                              DataCell(Text((sale['size'] as String?)?.isNotEmpty == true ? sale['size'] : 'OS')),
                              DataCell(Text(sale['platform'] ?? '')),
                              DataCell(Text(_currency(sale['sale_price'] as num? ?? 0))),
                              DataCell(Text(_currency(sale['fees'] as num? ?? 0))),
                              DataCell(Text(_currency(sale['shipping_cost'] as num? ?? 0))),
                              DataCell(
                                Text(
                                  sale['sold_date'] == null
                                      ? ''
                                      : DateFormat('yyyy-MM-dd').format(
                                          DateTime.parse(sale['sold_date'] as String),
                                        ),
                                ),
                              ),
                              DataCell(Text(_currency(profit))),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _openSaleDialog(sale: sale),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteSale(sale['id'] as String),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      )
                      .toList(),
                ),
              ),
            );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Sales', style: Theme.of(context).textTheme.headlineMedium),
            FilledButton.icon(
              onPressed: () => _openSaleDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Sale'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 720;
            final crossAxisCount = isPhone ? 2 : constraints.maxWidth < 1100 ? 2 : 3;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              childAspectRatio: isPhone ? 1.9 : 3.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(label: 'Total Revenue', value: _currency(totalRevenue)),
                StatCard(label: 'Total Profit', value: _currency(totalProfit)),
                StatCard(label: 'Number of Sales', value: filteredSales.length.toString()),
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
            hintText: 'Search by item, size, or platform',
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
              width: isMobile ? double.infinity : 240,
              child: DropdownButtonFormField<String>(
                value: _itemFilter,
                decoration: const InputDecoration(labelText: 'Item'),
                items: itemOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value == 'All' ? value : (_itemLabel(value) ?? 'Unknown item')),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _itemFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: _platformFilter,
                decoration: const InputDecoration(labelText: 'Platform'),
                items: platforms
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _platformFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: _timeframe,
                decoration: const InputDecoration(labelText: 'Timeframe'),
                items: const ['All', 'Daily', 'Weekly', 'Monthly']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _timeframe = value ?? 'All'),
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

Future<String?> _showSaleSearchPicker({
  required BuildContext context,
  required String title,
  required List<_SalePickerOption> options,
  required String? currentValue,
}) {
  final searchController = TextEditingController();
  return showDialog<String?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final query = searchController.text.trim().toLowerCase();
        final filtered = options.where((option) {
          final haystacks = [
            option.label.toLowerCase(),
            (option.meta ?? '').toLowerCase(),
          ];
          return query.isEmpty || haystacks.any((value) => value.contains(query));
        }).toList();
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final selected = option.value == currentValue;
                        return ListTile(
                          title: Text(option.label),
                          subtitle: option.meta == null ? null : Text(option.meta!),
                          trailing: selected ? const Icon(Icons.check, color: Color(0xFF4F46E5)) : null,
                          onTap: () => Navigator.pop(context, option.value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _SalePickerOption {
  const _SalePickerOption({
    required this.value,
    required this.label,
    this.meta,
  });

  final String value;
  final String label;
  final String? meta;
}

class _SaleFormField extends StatelessWidget {
  const _SaleFormField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SalePickerField extends StatelessWidget {
  const _SalePickerField({
    required this.value,
    required this.hintText,
    required this.onTap,
    this.enabled = true,
    this.helperText,
  });

  final String? value;
  final String hintText;
  final VoidCallback onTap;
  final bool enabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value?.trim();
    final text = display == null || display.isEmpty ? hintText : display;
    final textStyle = display == null || display.isEmpty
        ? theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF))
        : theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF111827));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon: const Icon(Icons.arrow_drop_down),
              filled: !enabled,
              fillColor: enabled ? null : const Color(0xFFF8FAFC),
            ),
            child: Text(text, style: textStyle),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SalePreviewCard extends StatelessWidget {
  const _SalePreviewCard({
    required this.itemTitle,
    required this.subtitle,
    required this.salePrice,
    required this.fees,
    required this.shipping,
    required this.soldDate,
  });

  final String itemTitle;
  final String subtitle;
  final num salePrice;
  final num fees;
  final num shipping;
  final DateTime? soldDate;

  @override
  Widget build(BuildContext context) {
    final net = salePrice - fees - shipping;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 176,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE0E7FF), Color(0xFFF8FAFC)],
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.sell_outlined, size: 48, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 14),
          Text(
            itemTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle.isEmpty ? 'Platform, size, and pricing will appear here.' : subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _SaleMetricRow(label: 'Sale Price', value: _currency(salePrice)),
          const SizedBox(height: 8),
          _SaleMetricRow(label: 'Fees', value: _currency(fees)),
          const SizedBox(height: 8),
          _SaleMetricRow(label: 'Shipping', value: _currency(shipping)),
          const SizedBox(height: 8),
          _SaleMetricRow(label: 'Net before cost', value: _currency(net)),
          const SizedBox(height: 8),
          _SaleMetricRow(
            label: 'Sold Date',
            value: soldDate == null ? 'Not set' : DateFormat('yyyy-MM-dd').format(soldDate!),
          ),
        ],
      ),
    );
  }
}

class _SaleMetricRow extends StatelessWidget {
  const _SaleMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _MobileSaleCard extends StatelessWidget {
  const _MobileSaleCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.meta,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String amount;
  final String meta;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(subtitle.isEmpty ? '-' : subtitle, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B))),
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

class _MobileSaleDetailRow extends StatelessWidget {
  const _MobileSaleDetailRow({
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

class _SalesEmptyState extends StatelessWidget {
  const _SalesEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Sales',
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
