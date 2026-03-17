import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/item_form_options.dart';
import '../widgets/scrollable_data_table.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  late final SupabaseService _service;
  bool _loading = true;
  List<Map<String, dynamic>> _purchaseOrders = [];
  List<Map<String, dynamic>> _purchaseDetails = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _stock = [];
  String? _selectedPurchaseId;
  String _itemFilter = 'All';
  String _stockFilter = 'All';

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
      _service.fetchPurchases(userId),
      _service.fetchPurchaseDetails(userId),
      _service.fetchItems(userId),
      _service.fetchItemStock(userId),
    ]);
    setState(() {
      _purchaseOrders = results[0];
      _purchaseDetails = results[1];
      _items = results[2];
      _stock = results[3];
      _selectedPurchaseId ??= _purchaseOrders.isEmpty ? null : _purchaseOrders.first['id'] as String?;
      _loading = false;
    });
  }

  Future<String?> _pickOption(String title, List<String> options, [String? current]) {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      barrierColor: const Color.fromRGBO(15, 23, 42, 0.38),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final q = controller.text.trim().toLowerCase();
          final filtered = options.where((e) => e.toLowerCase().contains(q)).toList();
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search...'),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final value = filtered[index];
                          return ListTile(
                            title: Text(value),
                            trailing: value == current ? const Icon(Icons.check, color: Color(0xFF4F46E5)) : null,
                            onTap: () => Navigator.pop(context, value),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Clear')),
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

  String? _itemTitleById(String? id) {
    if (id == null) return null;
    for (final item in _items) {
      if (item['id'] == id) return item['title'] as String?;
    }
    return null;
  }

  String _purchaseLabel(Map<String, dynamic> purchase) {
    final id = purchase['id'] as String?;
    final total = id == null ? 0 : _purchaseTotal(id);
    return '${purchase['bought_date'] ?? 'No date'} • ${_currency(total)}';
  }

  num _purchaseTotal(String purchaseId) => _purchaseDetails.where((row) => row['purchase_id'] == purchaseId).fold<num>(0, (sum, row) => sum + (row['unit_price'] as num? ?? 0) * (row['quantity'] as int? ?? 0));

  List<Map<String, dynamic>> _filteredPurchaseDetails() {
    return _purchaseDetails.where((row) {
      final matchesItem = _itemFilter == 'All' || row['item_id'] == _itemFilter;
      final matchesStock = switch (_stockFilter) {
        'Pending Stock' => row['added_to_stock'] != true,
        'Added to Stock' => row['added_to_stock'] == true,
        _ => true,
      };
      return matchesItem && matchesStock;
    }).toList();
  }

  List<Map<String, dynamic>> _filteredPurchaseOrders(List<Map<String, dynamic>> filteredDetails) {
    if (_itemFilter == 'All' && _stockFilter == 'All') {
      return _purchaseOrders;
    }
    final allowedPurchaseIds = filteredDetails.map((row) => row['purchase_id']).toSet();
    return _purchaseOrders.where((row) => allowedPurchaseIds.contains(row['id'])).toList();
  }

  Future<void> _openPurchaseOrderDialog({Map<String, dynamic>? purchase}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    DateTime? boughtDate =
        purchase?['bought_date'] == null ? DateTime.now() : DateTime.tryParse(purchase!['bought_date']);
    final lines = purchase == null ? <Map<String, dynamic>>[{'item_id': null, 'size': null, 'quantity': 1, 'unit_price': 0}] : <Map<String, dynamic>>[];
    final save = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(15, 23, 42, 0.38),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(purchase == null ? 'Add Purchase' : 'Edit Purchase', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _Labeled(label: 'Purchase Date', child: InkWell(onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: boughtDate ?? DateTime.now()); if (picked != null) setState(() => boughtDate = picked); }, child: InputDecorator(decoration: const InputDecoration(suffixIcon: Icon(Icons.event_outlined)), child: Text(boughtDate == null ? 'Choose a purchase date' : _formatDate(boughtDate!))))),
                  if (purchase == null) ...[
                    const SizedBox(height: 18),
                    Row(children: [Text('Items in this purchase', style: Theme.of(context).textTheme.titleMedium), const Spacer(), FilledButton.tonalIcon(onPressed: () => setState(() => lines.add({'item_id': null, 'size': null, 'quantity': 1, 'unit_price': 0})), icon: const Icon(Icons.add), label: const Text('Add item line'))]),
                    const SizedBox(height: 10),
                    ...lines.asMap().entries.map((entry) {
                      final i = entry.key;
                      final line = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Column(children: [
                            Row(children: [
                              Expanded(child: _Labeled(label: 'Item', child: _PickField(value: _itemTitleById(line['item_id'] as String?), hint: 'Select item', onTap: () async { final picked = await _pickOption('Select item', _items.map((e) => e['title'] as String? ?? '').where((e) => e.isNotEmpty).toList(), _itemTitleById(line['item_id'] as String?)); if (picked == null) return; final item = _items.firstWhere((e) => e['title'] == picked, orElse: () => {}); if (item.isNotEmpty) setState(() => line['item_id'] = item['id']); }))),
                              const SizedBox(width: 12),
                              Expanded(child: _Labeled(label: 'Size', child: _PickField(value: line['size'] as String?, hint: 'Pick a Vinted size', onTap: () async { final picked = await _pickOption('Choose size', vintedSizeOptions, line['size'] as String?); setState(() => line['size'] = picked); }))),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _Labeled(label: 'Quantity', child: TextFormField(initialValue: '${line['quantity']}', keyboardType: TextInputType.number, onChanged: (value) => line['quantity'] = int.tryParse(value) ?? 1))),
                              const SizedBox(width: 12),
                              Expanded(child: _Labeled(label: 'Unit Price', child: TextFormField(initialValue: '${line['unit_price']}', keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (value) => line['unit_price'] = num.tryParse(value) ?? 0))),
                              const SizedBox(width: 12),
                              Padding(padding: const EdgeInsets.only(top: 28), child: IconButton(onPressed: () => setState(() => lines.removeAt(i)), icon: const Icon(Icons.delete_outline))),
                            ]),
                          ]),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), const SizedBox(width: 12), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    if (save != true) return;
    final payload = {
      'user_id': userId,
      'bought_date': boughtDate?.toIso8601String(),
      'total_price': lines.fold<num>(0, (sum, line) => sum + (line['unit_price'] as num? ?? 0) * (line['quantity'] as int? ?? 0)),
    };
    if (purchase == null) {
      final created = await _service.createPurchase(payload);
      final purchaseId = created['id'] as String?;
      if (purchaseId != null) {
        for (final line in lines) {
          await _service.createPurchaseDetail({'purchase_id': purchaseId, 'item_id': line['item_id'], 'user_id': userId, 'quantity': line['quantity'], 'unit_price': line['unit_price'], 'size': line['size'], 'added_to_stock': false});
        }
      }
      _showToast('Purchase added.');
    } else {
      await _service.updatePurchase(purchase['id'] as String, payload);
      _showToast('Purchase updated.');
    }
    await _load();
  }

  Future<void> _openPurchaseDetailDialog({Map<String, dynamic>? detail}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final qty = TextEditingController(text: detail?['quantity']?.toString() ?? '1');
    final price = TextEditingController(text: detail?['unit_price']?.toString() ?? '');
    String? selectedSize = detail?['size'] as String?;
    String? selectedItemId = detail?['item_id'] as String? ?? (_items.isEmpty ? null : _items.first['id'] as String?);
    String? selectedPurchaseId = detail?['purchase_id'] as String? ?? (_purchaseOrders.isEmpty ? null : _purchaseOrders.first['id'] as String?);

    final save = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(15, 23, 42, 0.38),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(detail == null ? 'Add Purchase Item' : 'Edit Purchase Item', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _Labeled(label: 'Purchase', child: _PickField(value: selectedPurchaseId == null ? null : _purchaseLabel(_purchaseOrders.firstWhere((e) => e['id'] == selectedPurchaseId, orElse: () => {})), hint: 'Select purchase', onTap: () async { final picked = await _pickOption('Select purchase', _purchaseOrders.map(_purchaseLabel).toList()); if (picked == null) return; final purchase = _purchaseOrders.firstWhere((e) => _purchaseLabel(e) == picked, orElse: () => {}); if (purchase.isNotEmpty) setState(() => selectedPurchaseId = purchase['id'] as String?); })),
                  const SizedBox(height: 12),
                  _Labeled(label: 'Item', child: _PickField(value: _itemTitleById(selectedItemId), hint: 'Select item', onTap: () async { final picked = await _pickOption('Select item', _items.map((e) => e['title'] as String? ?? '').where((e) => e.isNotEmpty).toList(), _itemTitleById(selectedItemId)); if (picked == null) return; final item = _items.firstWhere((e) => e['title'] == picked, orElse: () => {}); if (item.isNotEmpty) setState(() => selectedItemId = item['id'] as String?); })),
                  const SizedBox(height: 12),
                  _Labeled(label: 'Size (optional)', child: _PickField(value: selectedSize, hint: 'Pick a Vinted size', onTap: () async { final picked = await _pickOption('Choose size', vintedSizeOptions, selectedSize); setState(() => selectedSize = picked); })),
                  const SizedBox(height: 12),
                  Row(children: [Expanded(child: _Labeled(label: 'Quantity', child: TextField(controller: qty, keyboardType: TextInputType.number))), const SizedBox(width: 12), Expanded(child: _Labeled(label: 'Unit Price', child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true))))]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), const SizedBox(width: 12), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    if (save != true || selectedItemId == null || selectedPurchaseId == null) return;
    final payload = {'purchase_id': selectedPurchaseId, 'item_id': selectedItemId, 'user_id': userId, 'quantity': int.tryParse(qty.text) ?? 1, 'unit_price': num.tryParse(price.text) ?? 0, 'size': selectedSize};
    if (detail == null) {
      await _service.createPurchaseDetail({...payload, 'added_to_stock': false});
      _showToast('Purchase item added.');
    } else {
      await _service.updatePurchaseDetail(detail['id'] as String, payload);
      _showToast('Purchase item updated.');
    }
    await _load();
  }
  Future<void> _addToStock(Map<String, dynamic> detail) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final sizeValue = (detail['size'] as String?)?.trim();
      final normalizedSize = sizeValue == null || sizeValue.isEmpty ? 'OS' : sizeValue;
      final existing = _stock.firstWhere((row) => row['item_id'] == detail['item_id'] && (row['size'] ?? 'OS') == normalizedSize, orElse: () => {});
      final existingQuantity = existing['quantity'] as int? ?? 0;
      final addQuantity = detail['quantity'] as int? ?? 0;
      final newQuantity = existingQuantity + addQuantity;
      if (existing.isNotEmpty) {
        await _service.updateItemStock(existing['id'] as String, {'quantity': newQuantity});
      } else {
        await _service.createItemStock({'item_id': detail['item_id'], 'user_id': userId, 'quantity': newQuantity, 'size': normalizedSize});
      }
      await _service.updatePurchaseDetail(detail['id'] as String, {'added_to_stock': true});
      await _load();
      _showToast('Added to stock.');
    } catch (error) {
      _showToast('Unable to add to stock: $error');
    }
  }

  Future<void> _deletePurchaseOrder(String id) async { await _service.deletePurchase(id); await _load(); _showToast('Purchase deleted.'); }
  Future<void> _deletePurchaseDetail(String id) async { await _service.deletePurchaseDetail(id); await _load(); _showToast('Purchase item deleted.'); }
  void _showToast(String message) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  Future<void> _showPurchaseOrderDetails(Map<String, dynamic> purchase) async {
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
              Text('Purchase', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _MobilePurchaseDetailRow(label: 'Bought Date', value: purchase['bought_date'] ?? '-'),
              _MobilePurchaseDetailRow(
                label: 'Total',
                value: _currency(_purchaseTotal(purchase['id'] as String? ?? '')),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openPurchaseOrderDialog(purchase: purchase);
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
                        _deletePurchaseOrder(purchase['id'] as String);
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

  Future<void> _showPurchaseItemDetails(Map<String, dynamic> detail) async {
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
              Text(detail['items']?['title'] ?? '', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _MobilePurchaseDetailRow(label: 'Brand', value: detail['items']?['brand'] ?? '-'),
              _MobilePurchaseDetailRow(label: 'Size', value: detail['size'] ?? '-'),
              _MobilePurchaseDetailRow(label: 'Quantity', value: '${detail['quantity']}'),
              _MobilePurchaseDetailRow(label: 'Unit Price', value: _currency(detail['unit_price'] as num)),
              _MobilePurchaseDetailRow(
                label: 'Line Total',
                value: _currency((detail['unit_price'] as num) * (detail['quantity'] as int)),
              ),
              _MobilePurchaseDetailRow(
                label: 'Stock',
                value: detail['added_to_stock'] == true ? 'Added' : 'Not added',
              ),
              const SizedBox(height: 16),
              if (detail['added_to_stock'] != true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addToStock(detail);
                      },
                      child: const Text('Add to stock'),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openPurchaseDetailDialog(detail: detail);
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
                        _deletePurchaseDetail(detail['id'] as String);
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final filteredDetailsAll = _filteredPurchaseDetails();
    final filteredOrders = _filteredPurchaseOrders(filteredDetailsAll);
    final effectiveSelectedPurchaseId =
        _selectedPurchaseId != null && filteredOrders.any((row) => row['id'] == _selectedPurchaseId)
            ? _selectedPurchaseId
            : (filteredOrders.isEmpty ? null : filteredOrders.first['id'] as String?);
    final totalSpend = _purchaseDetails.fold<num>(0, (sum, row) => sum + (row['unit_price'] as num) * (row['quantity'] as int));
    final totalUnits = _purchaseDetails.fold<int>(0, (sum, row) => sum + (row['quantity'] as int));
    final avgCost = totalUnits == 0 ? 0 : totalSpend / totalUnits;
    final distinctItems = _purchaseDetails.map((row) => row['item_id']).toSet().length;
    final selectedDetails = effectiveSelectedPurchaseId == null
        ? <Map<String, dynamic>>[]
        : filteredDetailsAll.where((row) => row['purchase_id'] == effectiveSelectedPurchaseId).toList();
    final itemOptions = [
      'All',
      ..._items
          .where((item) => item['id'] != null && (item['title'] as String? ?? '').trim().isNotEmpty)
          .map((item) => item['id'] as String)
          .toList(),
    ];

    final tableContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : isMobile
            ? Column(
                children: [
                  SectionCard(
                    title: 'Purchases',
                      child: SizedBox(
                        height: 420,
                        child: ListView.separated(
                        itemCount: filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final purchase = filteredOrders[index];
                          return _MobilePurchaseCard(
                            onTap: () {
                              setState(() => _selectedPurchaseId = purchase['id'] as String?);
                            },
                            title: _currency(_purchaseTotal(purchase['id'] as String? ?? '')),
                            subtitle: purchase['bought_date'] ?? 'No date',
                            selected: purchase['id'] == effectiveSelectedPurchaseId,
                            buttonLabel: 'Details',
                            onButtonTap: () => _showPurchaseOrderDetails(purchase),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Purchase details',
                    child: Column(
                      children: selectedDetails
                          .map(
                            (detail) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MobilePurchaseCard(
                                onTap: () => _showPurchaseItemDetails(detail),
                                title: detail['items']?['title'] ?? '',
                                subtitle: '${detail['size'] ?? '-'} | Qty ${detail['quantity']}',
                                trailing: _currency((detail['unit_price'] as num) * (detail['quantity'] as int)),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              )
            : LayoutBuilder(builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 1100;
            final availableHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 560.0;
            final cardChromeHeight = 120.0;
            final purchasesHeight = isMobile
                ? 220.0
                : isStacked
                    ? 220.0
                    : math.max(availableHeight - cardChromeHeight, 160.0);
            final detailsHeight = isMobile
                ? 320.0
                : isStacked
                    ? 260.0
                    : math.max(availableHeight - cardChromeHeight, 200.0);
            final purchasesCard = SectionCard(title: 'Purchases', child: SizedBox(height: purchasesHeight, child: ScrollableDataTable(minWidth: isMobile ? 420 : 520, table: DataTable(columns: const [DataColumn(label: Text('Total Price')), DataColumn(label: Text('Bought Date')), DataColumn(label: Text('Actions'))], rows: filteredOrders.map((purchase) => DataRow(selected: purchase['id'] == effectiveSelectedPurchaseId, onSelectChanged: (_) => setState(() => _selectedPurchaseId = purchase['id'] as String?), cells: [DataCell(Text(_currency(_purchaseTotal(purchase['id'] as String? ?? '')))), DataCell(Text(purchase['bought_date'] ?? '')), DataCell(Row(children: [IconButton(icon: const Icon(Icons.edit), onPressed: () => _openPurchaseOrderDialog(purchase: purchase)), IconButton(icon: const Icon(Icons.delete), onPressed: () => _deletePurchaseOrder(purchase['id'] as String))]))])).toList()))));
            final detailsCard = SectionCard(
              title: 'Purchase details',
              child: SizedBox(
                height: detailsHeight,
                child: ScrollableDataTable(
                  minWidth: isMobile ? 760 : 720,
                  table: DataTable(
                    horizontalMargin: 18,
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Unit Price')),
                      DataColumn(label: Text('Line Total')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: selectedDetails
                        .map(
                          (detail) => DataRow(
                            cells: [
                              DataCell(Text(detail['items']?['title'] ?? '')),
                              DataCell(Text(detail['size'] ?? '')),
                              DataCell(Text('${detail['quantity']}')),
                              DataCell(Text(_currency(detail['unit_price'] as num))),
                              DataCell(Text(_currency((detail['unit_price'] as num) * (detail['quantity'] as int)))),
                              DataCell(
                                detail['added_to_stock'] == true
                                    ? const Text('Added')
                                    : TextButton(
                                        onPressed: () => _addToStock(detail),
                                        child: const Text('Add'),
                                      ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _openPurchaseDetailDialog(detail: detail),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deletePurchaseDetail(detail['id'] as String),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
            if (isStacked) {
              return Column(children: [purchasesCard, const SizedBox(height: 16), detailsCard]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 5, child: purchasesCard), const SizedBox(width: 16), Expanded(flex: 8, child: detailsCard)]);
          });

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('Purchase History', style: Theme.of(context).textTheme.headlineMedium), FilledButton.icon(onPressed: () => _openPurchaseOrderDialog(), icon: const Icon(Icons.add), label: const Text('Add Purchase')), FilledButton.icon(onPressed: _purchaseOrders.isEmpty ? null : () => _openPurchaseDetailDialog(), icon: const Icon(Icons.playlist_add), label: const Text('Add Purchase Item'))]),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final crossAxisCount = isPhone ? 2 : constraints.maxWidth < 1100 ? 2 : 4;
          return GridView.count(crossAxisCount: crossAxisCount, crossAxisSpacing: 16, mainAxisSpacing: 16, shrinkWrap: true, childAspectRatio: isPhone ? 1.9 : 2.8, physics: const NeverScrollableScrollPhysics(), children: [StatCard(label: 'Total Spend', value: _currency(totalSpend)), StatCard(label: 'Total Units Purchased', value: totalUnits.toString()), StatCard(label: 'Avg Cost / Unit', value: _currency(avgCost)), StatCard(label: 'Distinct Items', value: distinctItems.toString())]);
        }),
        const SizedBox(height: 24),
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
                        child: Text(value == 'All' ? value : (_itemTitleById(value) ?? 'Unknown item')),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _itemFilter = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: _stockFilter,
                decoration: const InputDecoration(labelText: 'Stock Status'),
                items: const ['All', 'Pending Stock', 'Added to Stock']
                    .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _stockFilter = value ?? 'All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isMobile) tableContent else Expanded(child: tableContent),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(child: content);
    }

    return content;
  }
}

String _currency(num value) => NumberFormat.currency(symbol: '£').format(value);
String _formatDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))), const SizedBox(height: 8), child]);
  }
}

class _PickField extends StatelessWidget {
  const _PickField({required this.value, required this.hint, required this.onTap});
  final String? value;
  final String hint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final display = value?.trim();
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: InputDecorator(decoration: const InputDecoration(suffixIcon: Icon(Icons.arrow_drop_down)), child: Text(display == null || display.isEmpty ? hint : display)));
  }
}

class _MobilePurchaseCard extends StatelessWidget {
  const _MobilePurchaseCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.selected = false,
    this.buttonLabel,
    this.onButtonTap,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool selected;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF5F3FF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFFC4B5FD) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    if (buttonLabel != null && onButtonTap != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: onButtonTap,
                        child: Text(buttonLabel!),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (trailing != null) Text(trailing!, style: Theme.of(context).textTheme.titleSmall),
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

class _MobilePurchaseDetailRow extends StatelessWidget {
  const _MobilePurchaseDetailRow({
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


