import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/cost_calculations.dart';
import '../utils/csv_export.dart';
import '../utils/reference_id.dart';
import '../utils/whatnot_import.dart';
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
  bool _importingWhatnot = false;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _purchaseDetails = [];

  String _platformFilter = 'All';
  String _timeframe = 'All';
  String _itemFilter = 'All';
  String _brandFilter = 'All';
  String _categoryFilter = 'All';
  String _profitFilter = 'All';
  String _salesView = 'Sales';
  DateTime? _soldFrom;
  DateTime? _soldTo;
  bool _filtersExpanded = false;

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

  Future<void> _load({bool forceRefresh = false}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.fetchSales(userId, forceRefresh: forceRefresh),
      _service.fetchItemStock(userId, forceRefresh: forceRefresh),
      _service.fetchItems(userId, forceRefresh: forceRefresh),
      _service.fetchPurchaseDetails(userId, forceRefresh: forceRefresh),
    ]);
    setState(() {
      _sales = results[0];
      _stock = results[1];
      _items = results[2];
      _purchaseDetails = results[3];
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

    try {
      if (sale == null) {
        await _adjustStockForSale(
          userId: userId,
          itemId: selectedItemId,
          size: selectedSize,
          delta: -1,
        );
        try {
          await _service.createSale(payload);
        } catch (_) {
          await _adjustStockForSale(
            userId: userId,
            itemId: selectedItemId,
            size: selectedSize,
            delta: 1,
          );
          rethrow;
        }
        _showToast('Sale added.');
      } else {
        final previousItemId = sale['item_id'] as String?;
        final previousSize = sale['size'] as String?;
        final selectionChanged = previousItemId != selectedItemId || _normalizeSize(previousSize) != _normalizeSize(selectedSize);

        if (selectionChanged) {
          await _adjustStockForSale(
            userId: userId,
            itemId: previousItemId,
            size: previousSize,
            delta: 1,
          );
          try {
            await _adjustStockForSale(
              userId: userId,
              itemId: selectedItemId,
              size: selectedSize,
              delta: -1,
            );
          } catch (error) {
            await _adjustStockForSale(
              userId: userId,
              itemId: previousItemId,
              size: previousSize,
              delta: -1,
            );
            rethrow;
          }
        }

        try {
          await _service.updateSale(sale['id'] as String, payload);
        } catch (_) {
          if (selectionChanged) {
            await _adjustStockForSale(
              userId: userId,
              itemId: selectedItemId,
              size: selectedSize,
              delta: 1,
            );
            await _adjustStockForSale(
              userId: userId,
              itemId: previousItemId,
              size: previousSize,
              delta: -1,
            );
          }
          rethrow;
        }
        _showToast('Sale updated.');
      }
    } catch (error) {
      _showToast(error.toString().replaceFirst('Exception: ', ''));
      return;
    }
    await _load();
  }

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _adjustStockForSale(
        userId: userId,
        itemId: sale['item_id'] as String?,
        size: sale['size'] as String?,
        delta: 1,
      );
      try {
        await _service.deleteSale(sale['id'] as String);
      } catch (_) {
        await _adjustStockForSale(
          userId: userId,
          itemId: sale['item_id'] as String?,
          size: sale['size'] as String?,
          delta: -1,
        );
        rethrow;
      }
      await _load();
      _showToast('Sale deleted.');
    } catch (error) {
      _showToast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _exportSalesCsv(
    List<Map<String, dynamic>> rows, {
    required bool taxPack,
  }) {
    return exportCsvWithFeedback(
      context: context,
      baseName: taxPack ? 'sales_tax_export' : 'sales_export',
      headers: taxPack
          ? const [
              'Sale Ref',
              'Item Ref',
              'Item',
              'Size',
              'Platform',
              'Sold Date',
              'Sale Price',
              'Fees',
              'Shipping',
              'Avg Cost',
              'Profit',
            ]
          : const [
              'Sale Ref',
              'Item',
              'Size',
              'Platform',
              'Sold Date',
              'Sale Price',
              'Fees',
              'Shipping',
            ],
      rows: rows.map((sale) {
        final item = _items.firstWhere(
          (row) => row['id'] == sale['item_id'],
          orElse: () => {},
        );
        final avgCost = averageUnitCostForItem(_purchaseDetails, sale['item_id'] as String?);
        final profit = (sale['sale_price'] as num? ?? 0) -
            (sale['fees'] as num? ?? 0) -
            (sale['shipping_cost'] as num? ?? 0) -
            avgCost;

        final base = <Object?>[
          formatReferenceId(sale['id'], prefix: 'SAL'),
        ];
        if (taxPack) {
          base.add(formatReferenceId(sale['item_id'], prefix: 'ITM'));
        }
        base.addAll([
          item['title'],
          (sale['size'] as String?)?.trim().isNotEmpty == true ? sale['size'] : 'OS',
          sale['platform'],
          sale['sold_date'] == null
              ? ''
              : DateFormat('yyyy-MM-dd').format(DateTime.parse(sale['sold_date'] as String)),
          sale['sale_price'],
          sale['fees'],
          sale['shipping_cost'],
        ]);
        if (taxPack) {
          base.addAll([
            avgCost,
            profit,
          ]);
        }
        return base;
      }).toList(),
    );
  }

  Future<void> _importWhatnotCsv() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      setState(() => _importingWhatnot = true);
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _importingWhatnot = false);
        return;
      }

      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _importingWhatnot = false);
        _showToast('That CSV file could not be read.');
        return;
      }

      final csvText = decodeCsvBytes(bytes);
      final preview = parseWhatnotSalesCsv(
        csv: csvText,
        items: _items,
        stockRows: _stock,
      );

      if (preview.rows.isEmpty) {
        setState(() => _importingWhatnot = false);
        _showToast('No Whatnot sale rows were found in that CSV.');
        return;
      }

      setState(() => _importingWhatnot = false);
      final rowsToImport = await _showWhatnotImportPreview(preview);
      if (rowsToImport == null || rowsToImport.isEmpty) {
        return;
      }

      setState(() => _importingWhatnot = true);
      var importedCount = 0;

      for (final row in rowsToImport) {
        final soldDate = row.soldDate ?? DateTime.now();
        final unitFees = row.quantity <= 1 ? row.fees : row.fees / row.quantity;
        final unitShipping = row.quantity <= 1 ? row.shipping : row.shipping / row.quantity;

        for (var i = 0; i < row.quantity; i++) {
          await _adjustStockForSale(
            userId: userId,
            itemId: row.itemId,
            size: row.size,
            delta: -1,
          );

          try {
            await _service.createSale({
              'item_id': row.itemId,
              'user_id': userId,
              'size': row.size,
              'platform': 'Whatnot Live',
              'sale_price': row.salePrice / row.quantity,
              'fees': unitFees,
              'shipping_cost': unitShipping,
              'sold_date': soldDate.toIso8601String(),
            });
          } catch (_) {
            await _adjustStockForSale(
              userId: userId,
              itemId: row.itemId,
              size: row.size,
              delta: 1,
            );
            rethrow;
          }

          importedCount++;
        }
      }

      await _load(forceRefresh: true);
      if (mounted) {
        setState(() {
          _salesView = 'Live Streams';
          _importingWhatnot = false;
        });
      }
      _showToast('Imported $importedCount Whatnot sale${importedCount == 1 ? '' : 's'}.');
    } catch (error) {
      if (mounted) {
        setState(() => _importingWhatnot = false);
      }
      _showToast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<List<_ResolvedWhatnotImportRow>?> _showWhatnotImportPreview(WhatnotImportResult preview) {
    final draftRows = preview.rows.map(_ResolvedWhatnotImportRow.fromImportRow).toList();

    return showDialog<List<_ResolvedWhatnotImportRow>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final readyRows = draftRows.where((row) => row.ready).toList();
          final skippedRows = draftRows.where((row) => !row.ready).toList();

          Future<void> linkRow(_ResolvedWhatnotImportRow row) async {
            final pickedItemId = await _showSaleSearchPicker(
              context: context,
              title: 'Link livestream row to item',
              options: _items
                  .map(
                    (item) => _SalePickerOption(
                      value: item['id'] as String,
                      label: item['title'] as String? ?? 'Untitled item',
                      meta: (item['brand'] as String?)?.trim(),
                    ),
                  )
                  .toList(),
              currentValue: row.itemId,
            );
            if (pickedItemId == null) {
              return;
            }

            final sizeOptions = _saleSizeOptions(pickedItemId);
            String? pickedSize;
            if (sizeOptions.length == 1) {
              pickedSize = sizeOptions.first.value;
            } else {
              pickedSize = await _showSaleSearchPicker(
                context: context,
                title: 'Choose stock size',
                options: sizeOptions,
                currentValue: row.size,
              );
            }

            if (pickedSize == null || pickedSize.trim().isEmpty) {
              return;
            }

            setDialogState(() {
              row
                ..itemId = pickedItemId
                ..size = pickedSize
                ..ready = true
                ..statusMessage = 'Linked manually and ready to import';
            });
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Import Whatnot CSV', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Review the matched livestream rows. You can manually link skipped rows to stock items before importing.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _WhatnotImportStat(label: 'Ready', value: readyRows.length.toString()),
                        _WhatnotImportStat(label: 'Skipped', value: skippedRows.length.toString()),
                        _WhatnotImportStat(label: 'Rows', value: draftRows.length.toString()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SectionCard(
                              title: 'Ready to import',
                              expandChild: true,
                              child: readyRows.isEmpty
                                  ? const Center(child: Text('No rows are ready to import.'))
                                  : ListView.separated(
                                      itemCount: readyRows.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final row = readyRows[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(row.itemLabel),
                                          subtitle: Text(
                                            '${row.size ?? 'OS'} | Qty ${row.quantity} | ${row.soldDate == null ? 'No date' : DateFormat('yyyy-MM-dd').format(row.soldDate!)}',
                                          ),
                                          trailing: Text(
                                            _currency(row.salePrice),
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: SectionCard(
                              title: 'Skipped rows',
                              expandChild: true,
                              child: skippedRows.isEmpty
                                  ? const Center(child: Text('No skipped rows.'))
                                  : ListView.separated(
                                      itemCount: skippedRows.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final row = skippedRows[index];
                                        return ListTile(
                                          dense: true,
                                          title: Text(row.itemLabel),
                                          subtitle: Text(row.statusMessage),
                                          trailing: row.failedOrCancelled
                                              ? Text(
                                                  'Row ${row.sourceRowNumber}',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                )
                                              : OutlinedButton(
                                                  onPressed: () => linkRow(row),
                                                  child: const Text('Link to stock item'),
                                                ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: readyRows.isEmpty ? null : () => Navigator.pop(context, readyRows),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: Text('Import ${readyRows.length} Row${readyRows.length == 1 ? '' : 's'}'),
                        ),
                      ],
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

  List<Map<String, dynamic>> _filteredSales() {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    return _sales.where((sale) {
      final isLiveStreamSale = (sale['platform'] as String? ?? '') == 'Whatnot Live';
      if (_salesView == 'Live Streams' && !isLiveStreamSale) {
        return false;
      }
      if (_salesView == 'Sales' && isLiveStreamSale) {
        return false;
      }
      final item = _items.firstWhere(
        (row) => row['id'] == sale['item_id'],
        orElse: () => {},
      );
      final soldDate = sale['sold_date'] == null ? null : DateTime.tryParse(sale['sold_date'] as String)?.toLocal();
      final profit = _saleProfit(sale);
      if (_platformFilter != 'All' && sale['platform'] != _platformFilter) {
        return false;
      }
      if (_itemFilter != 'All' && sale['item_id'] != _itemFilter) {
        return false;
      }
      if (_brandFilter != 'All' && (item['brand'] ?? '') != _brandFilter) {
        return false;
      }
      if (_categoryFilter != 'All' && (item['category'] ?? '') != _categoryFilter) {
        return false;
      }
      if (_profitFilter == 'Profit Only' && profit <= 0) {
        return false;
      }
      if (_profitFilter == 'Break-even / Loss' && profit > 0) {
        return false;
      }
      final matchesQuery = query.isEmpty ||
          [
            item['title'],
            item['brand'],
            item['category'],
            sale['platform'],
            sale['size'],
          ].whereType<String>().any((value) => value.toLowerCase().contains(query));
      if (!matchesQuery) {
        return false;
      }
      if (_timeframe == 'Daily' && soldDate != null) {
        return soldDate.isAfter(now.subtract(const Duration(days: 1)));
      }
      if (_timeframe == 'Weekly' && soldDate != null) {
        return soldDate.isAfter(now.subtract(const Duration(days: 7)));
      }
      if (_timeframe == 'Monthly' && soldDate != null) {
        return soldDate.isAfter(now.subtract(const Duration(days: 30)));
      }
      if (_soldFrom != null && soldDate == null) {
        return false;
      }
      if (_soldFrom != null && soldDate != null && soldDate.isBefore(_startOfDay(_soldFrom!))) {
        return false;
      }
      if (_soldTo != null && soldDate == null) {
        return false;
      }
      if (_soldTo != null && soldDate != null && soldDate.isAfter(_endOfDay(_soldTo!))) {
        return false;
      }
      return true;
    }).toList();
  }

  num _saleProfit(Map<String, dynamic> sale) {
    final avgCost = averageUnitCostForItem(_purchaseDetails, sale['item_id'] as String?);
    return (sale['sale_price'] as num? ?? 0) -
        (sale['fees'] as num? ?? 0) -
        (sale['shipping_cost'] as num? ?? 0) -
        avgCost;
  }

  Future<void> _pickSoldFrom() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _soldFrom ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _soldFrom = picked);
    }
  }

  Future<void> _pickSoldTo() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _soldTo ?? _soldFrom ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _soldTo = picked);
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _itemFilter = 'All';
      _brandFilter = 'All';
      _categoryFilter = 'All';
      _platformFilter = 'All';
      _timeframe = 'All';
      _profitFilter = 'All';
      _soldFrom = null;
      _soldTo = null;
    });
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
    final avgCost = averageUnitCostForItem(_purchaseDetails, sale['item_id'] as String?);
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
                        _deleteSale(sale);
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
        .where((row) => (row['quantity'] as int? ?? 0) > 0)
        .map(
          (row) => _SalePickerOption(
            value: (row['size'] as String?) ?? '',
            label: (row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] as String : 'OS',
            meta: 'Available: ${(row['quantity'] ?? 0)}',
          ),
        )
        .toList();
  }

  Future<void> _adjustStockForSale({
    required String userId,
    required String? itemId,
    required String? size,
    required int delta,
  }) async {
    if (itemId == null || itemId.isEmpty || delta == 0) {
      return;
    }

    final normalizedSize = _normalizeSize(size);
    final matchingRow = _stock.cast<Map<String, dynamic>?>().firstWhere(
          (row) =>
              row?['item_id'] == itemId &&
              _normalizeSize(row?['size'] as String?) == normalizedSize,
          orElse: () => null,
        );

    if (matchingRow == null) {
      if (delta < 0) {
        throw Exception('That stock row is no longer available.');
      }

      final newRow = <String, dynamic>{
        'item_id': itemId,
        'user_id': userId,
        'size': normalizedSize.isEmpty ? null : normalizedSize,
        'quantity': delta,
      };
      await _service.createItemStock(newRow);
      _stock = [..._stock, newRow];
      return;
    }

    final currentQuantity = matchingRow['quantity'] as int? ?? 0;
    final nextQuantity = currentQuantity + delta;
    if (nextQuantity < 0) {
      throw Exception('Not enough stock is available for that sale.');
    }

    final stockId = matchingRow['id'] as String?;
    if (stockId == null || stockId.isEmpty) {
      await _service.upsertItemStock({
        'item_id': itemId,
        'user_id': userId,
        'size': normalizedSize.isEmpty ? null : normalizedSize,
        'quantity': nextQuantity,
      });
    } else {
      await _service.updateItemStock(
        stockId,
        {'quantity': nextQuantity},
      );
    }
    matchingRow['quantity'] = nextQuantity;
  }

  String _normalizeSize(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed;
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
    final brands = [
      'All',
      ..._items
          .map((row) => row['brand'])
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final categories = [
      'All',
      ..._items
          .map((row) => row['category'])
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final itemOptions = [
      'All',
      ..._sales
          .map((row) => row['item_id'])
          .whereType<String>()
          .toSet(),
    ];
    final isLiveStreamsView = _salesView == 'Live Streams';
    final pageTitle = isLiveStreamsView ? 'Live Streams' : 'Sales';
    final totalRevenue = filteredSales.fold<num>(
      0,
      (sum, row) => sum + (row['sale_price'] as num? ?? 0),
    );
    final totalProfit = filteredSales.fold<num>(0, (sum, row) {
      final salePrice = row['sale_price'] as num? ?? 0;
      final fees = row['fees'] as num? ?? 0;
      final shipping = row['shipping_cost'] as num? ?? 0;
      final avgCost = averageUnitCostForItem(_purchaseDetails, row['item_id'] as String?);
      return sum + (salePrice - fees - shipping - avgCost);
    });

    final tableSection = _loading
        ? const Center(child: CircularProgressIndicator())
        : filteredSales.isEmpty
            ? _SalesEmptyState(
                title: pageTitle,
                message: isLiveStreamsView
                    ? 'No imported livestream sales match these filters yet.'
                    : 'No sales match these filters yet.',
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
                title: pageTitle,
                expandChild: true,
                child: ScrollableDataTable(
                  minWidth: 1280,
                  table: DataTable(
                  columns: const [
                    DataColumn(label: Text('Sale Ref')),
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
                          final avgCost = averageUnitCostForItem(_purchaseDetails, sale['item_id'] as String?);
                          final profit = (sale['sale_price'] as num? ?? 0) -
                              (sale['fees'] as num? ?? 0) -
                              (sale['shipping_cost'] as num? ?? 0) -
                              avgCost;
                          return DataRow(
                            cells: [
                              DataCell(Text(formatReferenceId(sale['id'], prefix: 'SAL'))),
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
                                      onPressed: () => _deleteSale(sale),
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
            Text(pageTitle, style: Theme.of(context).textTheme.headlineMedium),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<String>(value: 'Sales', label: Text('Sales')),
                ButtonSegment<String>(value: 'Live Streams', label: Text('Live Streams')),
              ],
              selected: {_salesView},
              onSelectionChanged: (selection) {
                setState(() => _salesView = selection.first);
              },
            ),
            OutlinedButton.icon(
              onPressed: filteredSales.isEmpty ? null : () => _exportSalesCsv(filteredSales, taxPack: false),
              icon: const Icon(Icons.download_outlined),
              label: Text(isLiveStreamsView ? 'Export Streams' : 'Export Sales'),
            ),
            OutlinedButton.icon(
              onPressed: filteredSales.isEmpty ? null : () => _exportSalesCsv(filteredSales, taxPack: true),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Tax CSV'),
            ),
            OutlinedButton.icon(
              onPressed: _loading || !isLiveStreamsView ? null : _importWhatnotCsv,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import Whatnot'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _load(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            FilledButton.icon(
              onPressed: isLiveStreamsView ? null : () => _openSaleDialog(),
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
              childAspectRatio: isPhone ? 1.9 : 6.2,
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
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
            icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_filtersExpanded ? 'Hide Filters' : 'Show Filters'),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
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
                    value: _brandFilter,
                    decoration: const InputDecoration(labelText: 'Brand'),
                    items: brands
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _brandFilter = value ?? 'All'),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: DropdownButtonFormField<String>(
                    value: _categoryFilter,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _categoryFilter = value ?? 'All'),
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
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: DropdownButtonFormField<String>(
                    value: _profitFilter,
                    decoration: const InputDecoration(labelText: 'Profit State'),
                    items: const ['All', 'Profit Only', 'Break-even / Loss']
                        .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _profitFilter = value ?? 'All'),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: _DateFilterField(
                    label: 'Sold From',
                    value: _soldFrom,
                    onTap: _pickSoldFrom,
                    onClear: _soldFrom == null ? null : () => setState(() => _soldFrom = null),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: _DateFilterField(
                    label: 'Sold To',
                    value: _soldTo,
                    onTap: _pickSoldTo,
                    onClear: _soldTo == null ? null : () => setState(() => _soldTo = null),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Filters'),
                ),
              ],
            ),
          ),
          crossFadeState: _filtersExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
        const SizedBox(height: 16),
        if (isMobile) tableSection else Expanded(child: tableSection),
      ],
    );

    final body = isMobile ? SingleChildScrollView(child: content) : content;
    return Stack(
      children: [
        body,
        if (_importingWhatnot)
          Positioned.fill(
            child: Container(
              color: const Color.fromRGBO(3, 7, 18, 0.68),
              child: Center(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF243247)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Importing Whatnot CSV',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Matching livestream rows and saving sales. This may take a moment.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _currency(num value) => NumberFormat.currency(symbol: '\u00A3').format(value);

DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) => DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

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

class _ResolvedWhatnotImportRow {
  _ResolvedWhatnotImportRow({
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

  factory _ResolvedWhatnotImportRow.fromImportRow(WhatnotImportRow row) {
    return _ResolvedWhatnotImportRow(
      sourceRowNumber: row.sourceRowNumber,
      itemLabel: row.itemLabel,
      itemId: row.itemId,
      size: row.size,
      quantity: row.quantity,
      salePrice: row.salePrice,
      fees: row.fees,
      shipping: row.shipping,
      soldDate: row.soldDate,
      sourceReference: row.sourceReference,
      ready: row.ready,
      statusMessage: row.statusMessage,
      failedOrCancelled: row.failedOrCancelled,
    );
  }

  final int sourceRowNumber;
  final String itemLabel;
  String? itemId;
  String? size;
  final int quantity;
  final num salePrice;
  final num fees;
  final num shipping;
  final DateTime? soldDate;
  final String? sourceReference;
  bool ready;
  String statusMessage;
  final bool failedOrCancelled;
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined)
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null ? 'Any date' : DateFormat('yyyy-MM-dd').format(value!),
        ),
      ),
    );
  }
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

class _WhatnotImportStat extends StatelessWidget {
  const _WhatnotImportStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF243247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SalesEmptyState extends StatelessWidget {
  const _SalesEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
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
