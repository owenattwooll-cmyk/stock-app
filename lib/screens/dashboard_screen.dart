import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
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
    return FutureBuilder<DashboardData>(
      future: _loadDashboard(service, user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final revenueByMonth = _revenueByMonth(data.sales, months: 6);
        final profitByMonth = _profitByMonth(data.sales, data.itemCosts, months: 6);
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
                  GridView.count(
                    crossAxisCount: isMobile ? 2 : isCompact ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    childAspectRatio: isMobile ? 1.9 : 3.4,
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

String _currency(num value) => NumberFormat.currency(symbol: '£').format(value);

Future<DashboardData> _loadDashboard(SupabaseService service, String userId) async {
  final items = await service.fetchItems(userId);
  final sales = await service.fetchSales(userId);
  final itemCosts = await service.fetchItemCosts(userId);
  final stock = await service.fetchItemStock(userId);

  final stockUnits = stock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int? ?? 0));
  final totalRevenue = sales.fold<num>(
    0,
    (sum, row) => sum + (row['sale_price'] as num? ?? 0),
  );
  final totalProfit = sales.fold<num>(0, (sum, row) {
    final salePrice = row['sale_price'] as num? ?? 0;
    final fees = row['fees'] as num? ?? 0;
    final shipping = row['shipping_cost'] as num? ?? 0;
    final itemId = row['item_id'] as String?;
    final avgCost = itemCosts
            .firstWhere(
              (cost) => cost['item_id'] == itemId,
              orElse: () => {'avg_unit_cost': 0},
            )['avg_unit_cost'] as num? ??
        0;
    return sum + (salePrice - fees - shipping - avgCost);
  });

  final inventoryCost = itemCosts.fold<num>(
    0,
    (sum, cost) => sum + (cost['avg_unit_cost'] as num? ?? 0) * (cost['total_purchased_qty'] as int? ?? 0),
  );

  return DashboardData(
    totalItems: items.length,
    totalSales: sales.length,
    stockUnits: stockUnits,
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    inventoryCost: inventoryCost,
    recentSales: sales.take(5).toList(),
    sales: sales,
    itemCosts: itemCosts,
    stockRows: stock.take(5).toList(),
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
    required this.itemCosts,
    required this.stockRows,
  });

  final int totalItems;
  final int totalSales;
  final int stockUnits;
  final num totalRevenue;
  final num totalProfit;
  final num inventoryCost;
  final List<Map<String, dynamic>> recentSales;
  final List<Map<String, dynamic>> sales;
  final List<Map<String, dynamic>> itemCosts;
  final List<Map<String, dynamic>> stockRows;
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
  List<Map<String, dynamic>> itemCosts, {
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
    final itemId = row['item_id'] as String?;
    final avgCost = itemCosts
            .firstWhere(
              (cost) => cost['item_id'] == itemId,
              orElse: () => {'avg_unit_cost': 0},
            )['avg_unit_cost'] as num? ??
        0;
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

class _SalesTable extends StatelessWidget {
  const _SalesTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return ScrollableDataTable(
      minWidth: 560,
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Platform')),
          DataColumn(label: Text('Sale Price')),
          DataColumn(label: Text('Sold Date')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
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
    return ScrollableDataTable(
      minWidth: 560,
      table: DataTable(
        columns: const [
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Quantity')),
          DataColumn(label: Text('Last Updated')),
        ],
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
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
