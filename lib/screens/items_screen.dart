import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/image_picker_helper.dart';
import '../utils/item_form_options.dart';
import '../widgets/scrollable_data_table.dart';
import '../widgets/section_card.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();
  late final SupabaseService _service;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _categoryFilter = 'All';
  String _brandFilter = 'All';

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
    final items = await _service.fetchItems(userId);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openItemDialog({Map<String, dynamic>? item}) async {
    final titleController = TextEditingController(text: item?['title'] ?? '');
    final descriptionController = TextEditingController(text: item?['description'] ?? '');
    final brandController = TextEditingController(text: item?['brand'] ?? '');
    String? selectedCategory = item?['category'] as String?;
    String? imageData = item?['main_image_url'] as String?;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(15, 23, 42, 0.38),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 700 ? 12 : 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item == null ? 'Add Item' : 'Edit Item',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use the same category and sizing options as the Vue app, then upload an image from your files.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 680;
                        final form = Column(
                          children: [
                            _FormField(
                              label: 'Title',
                              child: TextField(
                                controller: titleController,
                                onChanged: (_) => setDialogState(() {}),
                                decoration: const InputDecoration(hintText: 'Vintage tee, cargo pants...'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormField(
                              label: 'Description',
                              child: TextField(
                                controller: descriptionController,
                                minLines: 4,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                  hintText: 'Condition, fit, flaws, styling notes...',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _FormField(
                                    label: 'Brand',
                                    child: TextField(
                                      controller: brandController,
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: const InputDecoration(hintText: 'Nike'),
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
                                  child: _FormField(
                                    label: 'Category',
                                    child: _PickerField(
                                      value: selectedCategory,
                                      hintText: 'Pick a category',
                                      onTap: () async {
                                        final picked = await _showSearchPicker(
                                          context: context,
                                          title: 'Choose category',
                                          options: vintedCategoryOptions,
                                          currentValue: selectedCategory,
                                        );
                                        if (picked != null || selectedCategory != null) {
                                          setDialogState(() => selectedCategory = picked);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _FormField(
                              label: 'Photo',
                              child: Row(
                                children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final picked = await pickImageAsDataUrl();
                                        if (picked == null || picked.isEmpty) return;
                                        setDialogState(() {
                                          imageData = picked;
                                        });
                                      },
                                      icon: const Icon(Icons.upload_file_outlined),
                                      label: Text(imageData == null ? 'Choose image' : 'Replace image'),
                                  ),
                                  const SizedBox(width: 12),
                                  if (imageData != null && imageData!.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () => setDialogState(() => imageData = null),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Remove'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final preview = _ImagePreviewCard(
                          imageUrl: imageData?.trim() ?? '',
                          title: titleController.text.trim(),
                            subtitle: [
                              brandController.text.trim(),
                              selectedCategory ?? '',
                            ].where((value) => value.isNotEmpty).join(' · '),
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
                          child: const Text('Save Item'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result != true) return;

    final payload = {
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      'brand': brandController.text.trim().isEmpty ? null : brandController.text.trim(),
      'category': selectedCategory,
      'size': null,
      'colour': null,
      'main_image_url': imageData,
      'user_id': userId,
    };

    if (item == null) {
      await _service.createItem(payload);
    } else {
      await _service.updateItem(item['id'] as String, payload);
    }
    await _load();
  }

  Future<void> _deleteItem(String id) async {
    await _service.deleteItem(id);
    await _load();
  }

  Future<void> _showItemDetails(Map<String, dynamic> item) async {
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
              Row(
                children: [
                  _ItemThumbnail(
                    imageUrl: item['main_image_url'] as String?,
                    title: item['title'] as String? ?? '',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          [item['brand'] ?? '', item['category'] ?? '']
                              .where((value) => (value as String).toString().isNotEmpty)
                              .join(' | '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MobileDetailRow(label: 'Brand', value: item['brand'] ?? '-'),
              _MobileDetailRow(label: 'Category', value: item['category'] ?? '-'),
              _MobileDetailRow(
                label: 'Created',
                value: DateFormat.yMMMd().format(DateTime.parse(item['created_at'] as String)),
              ),
              _MobileDetailRow(label: 'Description', value: item['description'] ?? '-'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openItemDialog(item: item);
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
                        _deleteItem(item['id'] as String);
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
    final brandOptions = [
      'All',
      ..._items
          .map((item) => item['brand'])
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final filteredItems = _items.where((item) {
      final term = _searchController.text.toLowerCase();
      final matchesSearch = term.isEmpty ||
          (item['title'] as String).toLowerCase().contains(term) ||
          (item['brand'] as String? ?? '').toLowerCase().contains(term);
      final matchesCategory = _categoryFilter == 'All' || item['category'] == _categoryFilter;
      final matchesBrand = _brandFilter == 'All' || item['brand'] == _brandFilter;
      return matchesSearch && matchesCategory && matchesBrand;
    }).toList();

    final tableSection = _loading
        ? const Center(child: CircularProgressIndicator())
        : isMobile
            ? Column(
                children: filteredItems
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MobileSummaryCard(
                          onTap: () => _showItemDetails(item),
                          leading: _ItemThumbnail(
                            imageUrl: item['main_image_url'] as String?,
                            title: item['title'] as String? ?? '',
                          ),
                          title: item['title'] ?? '',
                          subtitle: [item['brand'] ?? '', item['category'] ?? '']
                              .where((value) => (value as String).toString().isNotEmpty)
                              .join(' | '),
                          trailing: DateFormat.yMMMd().format(DateTime.parse(item['created_at'] as String)),
                        ),
                      ),
                    )
                    .toList(),
              )
            : SectionCard(
                title: 'Items',
                expandChild: true,
                child: ScrollableDataTable(
                  minWidth: 1040,
                  table: DataTable(
                  columns: const [
                    DataColumn(label: Text('Image')),
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Brand')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filteredItems
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(
                              _ItemThumbnail(
                                imageUrl: item['main_image_url'] as String?,
                                title: item['title'] as String? ?? '',
                              ),
                            ),
                            DataCell(Text(item['title'] ?? '')),
                            DataCell(Text(item['brand'] ?? '')),
                            DataCell(Text(item['category'] ?? '')),
                            DataCell(Text(DateFormat.yMMMd().format(DateTime.parse(item['created_at'] as String)))),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _openItemDialog(item: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteItem(item['id'] as String),
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
            Text('Items', style: Theme.of(context).textTheme.headlineMedium),
            FilledButton.icon(
              onPressed: () => _openItemDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by title or brand'),
          onChanged: (_) => setState(() {}),
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
                value: _brandFilter,
                decoration: const InputDecoration(labelText: 'Brand'),
                items: brandOptions
                    .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _brandFilter = value ?? 'All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isMobile) tableSection else Expanded(child: tableSection),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        child: content,
      );
    }

    return content;
  }
}

Future<String?> _showSearchPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String? currentValue,
}) {
  final searchController = TextEditingController();
  return showDialog<String?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final query = searchController.text.trim().toLowerCase();
        final filtered = options.where((option) => option.toLowerCase().contains(query)).toList();
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
                        final selected = option == currentValue;
                        return ListTile(
                          title: Text(option),
                          trailing: selected ? const Icon(Icons.check, color: Color(0xFF4F46E5)) : null,
                          onTap: () => Navigator.pop(context, option),
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

class _FormField extends StatelessWidget {
  const _FormField({
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.hintText,
    required this.onTap,
  });

  final String? value;
  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value?.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          display == null || display.isEmpty ? hintText : display,
          style: display == null || display.isEmpty
              ? theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA3AF))
              : theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  const _ImagePreviewCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  final String imageUrl;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
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
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _ItemImage(
                imageUrl: imageUrl,
                emptyChild: Container(
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 42, color: Color(0xFF64748B)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title.isEmpty ? 'Item preview' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle.isEmpty ? 'Brand, category, and size will appear here.' : subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ItemThumbnail extends StatelessWidget {
  const _ItemThumbnail({
    required this.imageUrl,
    required this.title,
  });

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _ItemImage(
        imageUrl: imageUrl,
        emptyChild: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF64748B)),
        errorChild: Center(
          child: Text(
            title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
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

class _MobileSummaryCard extends StatelessWidget {
  const _MobileSummaryCard({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final String trailing;

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
              leading,
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
                  Text(trailing, style: Theme.of(context).textTheme.bodySmall),
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

class _MobileDetailRow extends StatelessWidget {
  const _MobileDetailRow({
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
