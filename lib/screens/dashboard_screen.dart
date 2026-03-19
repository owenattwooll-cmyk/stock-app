import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/cost_calculations.dart';
import '../utils/reference_id.dart';
import '../widgets/scrollable_data_table.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final service = SupabaseService(Supabase.instance.client);
    Future<DashboardData> loadData() => _loadDashboard(service, user.id);
    return FutureBuilder<DashboardData>(
      future: loadData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionCard(
            title: 'Dashboard unavailable',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The dashboard could not be loaded on this device right now.'),
                const SizedBox(height: 12),
                Text(
                  '${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB91C1C),
                      ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    SupabaseService.clearCache();
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final revenueByMonth = _revenueByMonth(data.sales, months: 6);
        final profitByMonth = _profitByMonth(data.sales, data.purchaseDetails, months: 6);
        final stockRatio = data.stockUnits == 0 && data.totalSales == 0
            ? 0.0
            : data.stockUnits / (data.stockUnits + data.totalSales);

        return SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 980;
              final isMobile = constraints.maxWidth < 700;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/items'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/purchase-history'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Add Purchase'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/sales'),
                        icon: const Icon(Icons.sell_outlined),
                        label: const Text('Add Sale'),
                      ),
                    ],
                  ),
                  if (data.alerts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Alerts',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: data.alerts
                            .map(
                              (alert) => _AlertPill(
                                tone: alert.tone,
                                title: alert.title,
                                subtitle: alert.subtitle,
                                onTap: () => _showAlertDialog(context, alert),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: isMobile ? 2 : isCompact ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    childAspectRatio: isMobile ? 1.9 : 3.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatCard(label: 'Total Items', value: data.totalItems.toString()),
                      StatCard(label: 'Total Sales', value: data.totalSales.toString()),
                      StatCard(label: 'Units In Stock', value: data.stockUnits.toString()),
                      StatCard(label: 'Inventory Cost', value: _currency(data.inventoryCost)),
                      StatCard(label: 'Total Revenue', value: _currency(data.totalRevenue)),
                      StatCard(label: 'Total Profit', value: _currency(data.totalProfit)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isCompact)
                    Column(
                      children: [
                        SectionCard(
                          title: 'Revenue (last 6 months)',
                          child: _BarChart(points: revenueByMonth),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Profit trend',
                          child: _LineChart(points: profitByMonth),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Stock health',
                          child: _StockHealth(
                            stockRatio: stockRatio,
                            stockCount: data.stockUnits,
                            soldCount: data.totalSales,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SectionCard(
                            title: 'Revenue (last 6 months)',
                            child: _BarChart(points: revenueByMonth),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SectionCard(
                            title: 'Profit trend',
                            child: _LineChart(points: profitByMonth),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SectionCard(
                            title: 'Stock health',
                            child: _StockHealth(
                              stockRatio: stockRatio,
                              stockCount: data.stockUnits,
                              soldCount: data.totalSales,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (isCompact)
                    Column(
                      children: [
                        SectionCard(
                          title: 'Recent Sales',
                          child: _SalesTable(rows: data.recentSales),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Stock on hand',
                          child: _StockTable(rows: data.stockRows),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SectionCard(
                            title: 'Recent Sales',
                            child: _SalesTable(rows: data.recentSales),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SectionCard(
                            title: 'Stock on hand',
                            child: _StockTable(rows: data.stockRows),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

String _currency(num value) => NumberFormat.currency(symbol: '\u00A3').format(value);

Future<DashboardData> _loadDashboard(SupabaseService service, String userId) async {
  final items = await service.fetchItems(userId);
  final sales = await service.fetchSales(userId);
  final stock = await service.fetchItemStock(userId);
  final purchaseDetails = await service.fetchPurchaseDetails(userId);

  final stockUnits = stock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int? ?? 0));
  final totalRevenue = sales.fold<num>(
    0,
    (sum, row) => sum + (row['sale_price'] as num? ?? 0),
  );
  final totalProfit = sales.fold<num>(0, (sum, row) {
    final salePrice = row['sale_price'] as num? ?? 0;
    final fees = row['fees'] as num? ?? 0;
    final shipping = row['shipping_cost'] as num? ?? 0;
    final avgCost = averageUnitCostForItem(purchaseDetails, row['item_id'] as String?);
    return sum + (salePrice - fees - shipping - avgCost);
  });

  final inventoryCost = inventoryCostFromStock(stock, purchaseDetails);

  final lowStockCount = stock.where((row) => (row['quantity'] as int? ?? 0) <= 1).length;
  final lowStockRows = stock.where((row) => (row['quantity'] as int? ?? 0) <= 1).toList();
  final pendingPurchaseCount = purchaseDetails.where((row) => row['added_to_stock'] != true).length;
  final pendingPurchaseRows = purchaseDetails.where((row) => row['added_to_stock'] != true).toList();
  final staleCutoff = DateTime.now().subtract(const Duration(days: 30));
  final staleStockRows = stock.where((row) {
    final updated = DateTime.tryParse(row['updated_at'] as String? ?? '');
    return updated != null && updated.isBefore(staleCutoff);
  }).toList();
  final staleStockCount = staleStockRows.length;

  final alerts = <DashboardAlert>[
    if (lowStockCount > 0)
      DashboardAlert(
        kind: _DashboardAlertKind.lowStock,
        tone: _AlertTone.warning,
        title: '$lowStockCount low-stock item${lowStockCount == 1 ? '' : 's'}',
        subtitle: 'Some sizes are down to one unit or less.',
        rows: lowStockRows,
        actionLabel: 'Open Stock',
        route: '/stock',
      ),
    if (pendingPurchaseCount > 0)
      DashboardAlert(
        kind: _DashboardAlertKind.pendingPurchase,
        tone: _AlertTone.info,
        title: '$pendingPurchaseCount purchase line${pendingPurchaseCount == 1 ? '' : 's'} pending',
        subtitle: 'Purchases still need to be added into stock.',
        rows: pendingPurchaseRows,
        actionLabel: 'Open Purchase History',
        route: '/purchase-history',
      ),
    if (staleStockCount > 0)
      DashboardAlert(
        kind: _DashboardAlertKind.staleStock,
        tone: _AlertTone.neutral,
        title: '$staleStockCount stale stock update${staleStockCount == 1 ? '' : 's'}',
        subtitle: 'Items have not been updated in the last 30 days.',
        rows: staleStockRows,
        actionLabel: 'Open Stock',
        route: '/stock',
      ),
  ];

  return DashboardData(
    totalItems: items.length,
    totalSales: sales.length,
    stockUnits: stockUnits,
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    inventoryCost: inventoryCost,
    recentSales: sales.take(5).toList(),
    sales: sales,
    purchaseDetails: purchaseDetails,
    stockRows: stock.take(5).toList(),
    alerts: alerts,
  );
}

class DashboardData {
  DashboardData({
    required this.totalItems,
    required this.totalSales,
    required this.stockUnits,
    required this.totalRevenue,
    required this.totalProfit,
    required this.inventoryCost,
    required this.recentSales,
    required this.sales,
    required this.purchaseDetails,
    required this.stockRows,
    required this.alerts,
  });

  final int totalItems;
  final int totalSales;
  final int stockUnits;
  final num totalRevenue;
  final num totalProfit;
  final num inventoryCost;
  final List<Map<String, dynamic>> recentSales;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> purchaseDetails;
  final List<Map<String, dynamic>> stockRows;
  final List<DashboardAlert> alerts;
}

class DashboardAlert {
  const DashboardAlert({
    required this.kind,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.actionLabel,
    required this.route,
  });

  final _DashboardAlertKind kind;
  final _AlertTone tone;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> rows;
  final String actionLabel;
  final String route;
}

enum _AlertTone {
  info,
  warning,
  neutral,
}

enum _DashboardAlertKind {
  lowStock,
  pendingPurchase,
  staleStock,
}

List<_ChartPoint> _revenueByMonth(List<Map<String, dynamic>> sales, {int months = 6}) {
  final now = DateTime.now();
  final buckets = <DateTime, num>{};
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i);
    buckets[month] = 0;
  }

  for (final row in sales) {
    final dateValue = row['sold_date'];
    final soldDate = dateValue == null ? null : DateTime.tryParse(dateValue as String);
    if (soldDate == null) continue;
    final monthKey = DateTime(soldDate.year, soldDate.month);
    if (!buckets.containsKey(monthKey)) continue;
    buckets[monthKey] = (buckets[monthKey] ?? 0) + (row['sale_price'] as num? ?? 0);
  }

  return buckets.entries
      .map(
        (entry) => _ChartPoint(
          label: DateFormat.MMM().format(entry.key),
          value: entry.value,
        ),
      )
      .toList();
}

List<_ChartPoint> _profitByMonth(
  List<Map<String, dynamic>> sales,
  List<Map<String, dynamic>> purchaseDetails, {
  int months = 6,
}) {
  final now = DateTime.now();
  final buckets = <DateTime, num>{};
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i);
    buckets[month] = 0;
  }

  for (final row in sales) {
    final dateValue = row['sold_date'];
    final soldDate = dateValue == null ? null : DateTime.tryParse(dateValue as String);
    if (soldDate == null) continue;
    final monthKey = DateTime(soldDate.year, soldDate.month);
    if (!buckets.containsKey(monthKey)) continue;
    final salePrice = row['sale_price'] as num? ?? 0;
    final fees = row['fees'] as num? ?? 0;
    final shipping = row['shipping_cost'] as num? ?? 0;
    final avgCost = averageUnitCostForItem(purchaseDetails, row['item_id'] as String?);
    buckets[monthKey] = (buckets[monthKey] ?? 0) + (salePrice - fees - shipping - avgCost);
  }

  return buckets.entries
      .map(
        (entry) => _ChartPoint(
          label: DateFormat.MMM().format(entry.key),
          value: entry.value,
        ),
      )
      .toList();
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.value});

  final String label;
  final num value;
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.points});

  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = points.map((point) => point.value).fold<num>(0, (max, value) => value > max ? value : max);

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final totalSpacing = points.length > 1 ? (points.length - 1) * spacing : 0.0;
                final barWidth = points.isEmpty ? 0.0 : (constraints.maxWidth - totalSpacing) / points.length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(points.length, (index) {
                    final point = points[index];
                    final isLast = index == points.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : spacing),
                      child: SizedBox(
                        width: barWidth,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: maxValue == 0 ? 4 : (point.value / maxValue) * 140 + 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(point.label, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Total: ${_currency(points.fold<num>(0, (sum, point) => sum + point.value))}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});

  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(points: points, color: theme.colorScheme.primary),
              child: Container(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: points
                .map(
                  (point) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${point.label} ${_currency(point.value)}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.color});

  final List<_ChartPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxValue = points.map((point) => point.value).fold<num>(0, (max, value) => value > max ? value : max);
    final minValue = points.map((point) => point.value).fold<num>(0, (min, value) => value < min ? value : min);
    final range = (maxValue - minValue).abs();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final denominator = points.length - 1;
      final x = denominator == 0 ? 0.0 : size.width * (i / denominator);
      final normalized = range == 0 ? 0.5 : ((points[i].value - minValue) / range);
      final y = size.height - (normalized.toDouble() * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _StockHealth extends StatelessWidget {
  const _StockHealth({
    required this.stockRatio,
    required this.stockCount,
    required this.soldCount,
  });

  final double stockRatio;
  final int stockCount;
  final int soldCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock vs Sold', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: stockRatio,
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: const Color(0xFFE2E8F0),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _HealthPill(label: 'In stock', value: stockCount.toString(), color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            _HealthPill(label: 'Sold', value: soldCount.toString(), color: const Color(0xFF94A3B8)),
          ],
        ),
      ],
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _AlertPill extends StatelessWidget {
  const _AlertPill({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final _AlertTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _AlertTone.info => (
          background: const Color(0xFFEEF2FF),
          border: const Color(0xFFC7D2FE),
          accent: const Color(0xFF4F46E5),
        ),
      _AlertTone.warning => (
          background: const Color(0xFFFFF7ED),
          border: const Color(0xFFFED7AA),
          accent: const Color(0xFFEA580C),
        ),
      _AlertTone.neutral => (
          background: const Color(0xFFF8FAFC),
          border: const Color(0xFFE2E8F0),
          accent: const Color(0xFF475569),
        ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Material(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAlertDialog(BuildContext context, DashboardAlert alert) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                alert.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: alert.rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AlertRowCard(
                    alert: alert,
                    row: alert.rows[index],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.go(alert.route);
                    },
                    child: Text(alert.actionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AlertRowCard extends StatelessWidget {
  const _AlertRowCard({
    required this.alert,
    required this.row,
  });

  final DashboardAlert alert;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final title = switch (alert.kind) {
      _DashboardAlertKind.lowStock => row['items']?['title'] as String? ?? 'Untitled item',
      _DashboardAlertKind.staleStock => row['items']?['title'] as String? ?? 'Untitled item',
      _DashboardAlertKind.pendingPurchase => row['items']?['title'] as String? ?? 'Purchase item',
    };

    final subtitle = switch (alert.kind) {
      _DashboardAlertKind.lowStock => 'Size ${(row['size'] as String?)?.trim().isNotEmpty == true ? row['size'] : 'OS'}',
      _DashboardAlertKind.staleStock => 'Last updated ${_formatTimestamp(row['updated_at'] as String?)}',
      _DashboardAlertKind.pendingPurchase => 'Bought ${_formatTimestamp(row['purchases']?['bought_date'] as String?)}',
    };

    final trailing = switch (alert.kind) {
      _DashboardAlertKind.lowStock => 'Qty ${row['quantity'] ?? 0}',
      _DashboardAlertKind.staleStock => 'Qty ${row['quantity'] ?? 0}',
      _DashboardAlertKind.pendingPurchase =>
        '${row['quantity'] ?? 0} x ${_currency(row['unit_price'] as num? ?? 0)}',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SalesTable extends StatelessWidget {
  const _SalesTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _DashboardEmptyState(
        message: 'No sales yet. Add your first sale to populate this table.',
      );
    }

    return ScrollableDataTable(
      minWidth: 560,
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Sale Ref')),
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Platform')),
          DataColumn(label: Text('Sale Price')),
          DataColumn(label: Text('Sold Date')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(formatReferenceId(row['id'], prefix: 'SAL'))),
                  DataCell(Text(row['items']?['title'] ?? '')),
                  DataCell(Text(row['platform'] ?? '')),
                  DataCell(Text(_currency(row['sale_price'] as num? ?? 0))),
                  DataCell(Text(_formatTimestamp(row['sold_date'] as String?))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _DashboardEmptyState(
        message: 'No stock rows yet. Add purchases into stock to see them here.',
      );
    }

    return ScrollableDataTable(
      minWidth: 560,
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Stock Ref')),
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Quantity')),
          DataColumn(label: Text('Last Updated')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(formatReferenceId(row['id'], prefix: 'STK'))),
                  DataCell(Text(row['items']?['title'] ?? '')),
                  DataCell(Text(row['size'] ?? 'OS')),
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

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.message});

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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
            ),
      ),
    );
  }
}

String _formatTimestamp(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;

  final hasTime = parsed.hour != 0 || parsed.minute != 0 || parsed.second != 0;
  if (hasTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }
  return DateFormat('yyyy-MM-dd').format(parsed.toLocal());
}
