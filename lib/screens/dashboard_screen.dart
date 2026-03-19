import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/cost_calculations.dart';
import '../utils/reference_id.dart';

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
        final monthlyPerformance = _salesAndProfitByMonth(
          data.sales,
          data.purchaseDetails,
          months: 6,
        );
        final userLabel = _displayName(user);

        return SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 760;
              final isTablet = constraints.maxWidth < 1180;

              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 18 : 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF111827),
                      Color(0xFF0F172A),
                      Color(0xFF111827),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF293243)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(2, 6, 23, 0.32),
                      blurRadius: 40,
                      offset: Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHero(
                      userLabel: userLabel,
                      todaySalesCount: data.todaySalesCount,
                      todayProfit: data.todayProfit,
                    ),
                    const SizedBox(height: 24),
                    _DashboardActions(isMobile: isMobile),
                    const SizedBox(height: 28),
                    Divider(color: const Color(0xFF334155).withOpacity(0.8), height: 1),
                    const SizedBox(height: 28),
                    GridView.count(
                      crossAxisCount: isMobile ? 1 : isTablet ? 2 : 4,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isMobile ? 2.7 : isTablet ? 2.2 : 1.9,
                      children: [
                        _MetricCard(
                          icon: Icons.trending_up_rounded,
                          iconBackground: const Color(0xFF0F766E),
                          label: 'Profit (30 Days)',
                          value: _currency(data.profit30Days),
                          accentText: _trendText(data.profit30Days),
                          accentColor: _metricAccent(data.profit30Days),
                        ),
                        _MetricCard(
                          icon: Icons.payments_outlined,
                          iconBackground: const Color(0xFFB45309),
                          label: 'Revenue (30 Days)',
                          value: _currency(data.revenue30Days),
                          accentText: _trendText(data.revenue30Days),
                          accentColor: _metricAccent(data.revenue30Days),
                        ),
                        _MetricCard(
                          icon: Icons.inventory_2_outlined,
                          iconBackground: const Color(0xFF1D4ED8),
                          label: 'Items in Stock',
                          value: data.stockUnits.toString(),
                          subtitle: '${data.totalItems} total catalogued',
                        ),
                        _MetricCard(
                          icon: Icons.percent_rounded,
                          iconBackground: const Color(0xFFCA8A04),
                          label: 'ROI',
                          value: '${data.roiPercent.toStringAsFixed(0)}%',
                          subtitle: 'Profit vs inventory cost',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isTablet)
                      Column(
                        children: [
                          _DashboardPanel(
                            title: 'Sales & Profit (Last 6 Months)',
                            child: _DualLineChart(points: monthlyPerformance),
                          ),
                          const SizedBox(height: 18),
                          _DashboardPanel(
                            title: 'Needs Attention',
                            child: _NeedsAttentionList(alerts: data.alerts),
                          ),
                          const SizedBox(height: 18),
                          const _DashboardPanel(
                            title: 'Quick Actions',
                            child: _QuickActions(),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _DashboardPanel(
                              title: 'Sales & Profit (Last 6 Months)',
                              child: _DualLineChart(points: monthlyPerformance),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _DashboardPanel(
                                  title: 'Needs Attention',
                                  child: _NeedsAttentionList(alerts: data.alerts),
                                ),
                                const SizedBox(height: 18),
                                const _DashboardPanel(
                                  title: 'Quick Actions',
                                  child: _QuickActions(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    if (isTablet)
                      Column(
                        children: [
                          _DashboardPanel(
                            title: 'Recent Sales',
                            child: _RecentSalesTable(
                              rows: data.recentSales,
                              purchaseDetails: data.purchaseDetails,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _DashboardPanel(
                            title: 'Stock Health',
                            child: _StockHealthTable(rows: data.stockRows),
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _DashboardPanel(
                              title: 'Recent Sales',
                              child: _RecentSalesTable(
                                rows: data.recentSales,
                                purchaseDetails: data.purchaseDetails,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _DashboardPanel(
                              title: 'Stock Health',
                              child: _StockHealthTable(rows: data.stockRows),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String _displayName(User user) {
  final metaName = user.userMetadata?['full_name'] as String?;
  if (metaName != null && metaName.trim().isNotEmpty) {
    return metaName.trim();
  }

  final email = user.email ?? '';
  if (email.contains('@')) {
    final localPart = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (localPart.isNotEmpty) {
      return localPart
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
    }
  }

  return 'Seller';
}

String _currency(num value) => NumberFormat.currency(symbol: '\u00A3', decimalDigits: value % 1 == 0 ? 0 : 2).format(value);

String _trendText(num value) {
  if (value > 0) return 'Up';
  if (value < 0) return 'Down';
  return 'Flat';
}

Color _metricAccent(num value) {
  if (value > 0) return const Color(0xFF86EFAC);
  if (value < 0) return const Color(0xFFFCA5A5);
  return const Color(0xFFCBD5E1);
}

Future<DashboardData> _loadDashboard(SupabaseService service, String userId) async {
  final items = await service.fetchItems(userId);
  final sales = await service.fetchSales(userId);
  final stock = await service.fetchItemStock(userId);
  final purchaseDetails = await service.fetchPurchaseDetails(userId);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  final stockUnits = stock.fold<int>(0, (sum, row) => sum + (row['quantity'] as int? ?? 0));
  final totalRevenue = sales.fold<num>(0, (sum, row) => sum + (row['sale_price'] as num? ?? 0));
  final totalProfit = sales.fold<num>(0, (sum, row) => sum + _profitForSale(row, purchaseDetails));
  final inventoryCost = inventoryCostFromStock(stock, purchaseDetails);

  final todaySales = sales.where((row) {
    final soldDate = _parseDate(row['sold_date']);
    return soldDate != null && !soldDate.isBefore(todayStart);
  }).toList();
  final todayProfit = todaySales.fold<num>(0, (sum, row) => sum + _profitForSale(row, purchaseDetails));

  final rollingSales = sales.where((row) {
    final soldDate = _parseDate(row['sold_date']);
    return soldDate != null && !soldDate.isBefore(thirtyDaysAgo);
  }).toList();
  final revenue30Days = rollingSales.fold<num>(0, (sum, row) => sum + (row['sale_price'] as num? ?? 0));
  final profit30Days = rollingSales.fold<num>(0, (sum, row) => sum + _profitForSale(row, purchaseDetails));

  final lowStockRows = stock.where((row) => (row['quantity'] as int? ?? 0) <= 1).toList();
  final pendingPurchaseRows = purchaseDetails.where((row) => row['added_to_stock'] != true).toList();
  final staleCutoff = now.subtract(const Duration(days: 30));
  final staleStockRows = stock.where((row) {
    final updated = _parseDate(row['updated_at']);
    return updated != null && updated.isBefore(staleCutoff);
  }).toList();

  final alerts = <DashboardAlert>[
    if (pendingPurchaseRows.isNotEmpty)
      DashboardAlert(
        kind: _DashboardAlertKind.pendingPurchase,
        tone: _AlertTone.critical,
        title: '${pendingPurchaseRows.length} purchases not added',
        subtitle: 'Purchase lines still need to be pushed into stock.',
        rows: pendingPurchaseRows,
        actionLabel: 'Open Purchase History',
        route: '/purchase-history',
      ),
    if (lowStockRows.isNotEmpty)
      DashboardAlert(
        kind: _DashboardAlertKind.lowStock,
        tone: _AlertTone.warning,
        title: '${lowStockRows.length} low-stock item${lowStockRows.length == 1 ? '' : 's'}',
        subtitle: 'Some variants are down to one unit or less.',
        rows: lowStockRows,
        actionLabel: 'Open Stock',
        route: '/stock',
      ),
    if (staleStockRows.isNotEmpty)
      DashboardAlert(
        kind: _DashboardAlertKind.staleStock,
        tone: _AlertTone.info,
        title: '${staleStockRows.length} stale stock update${staleStockRows.length == 1 ? '' : 's'}',
        subtitle: 'Items have not been updated in the last 30 days.',
        rows: staleStockRows,
        actionLabel: 'Review Stock',
        route: '/stock',
      ),
  ];

  final roiPercent = inventoryCost > 0 ? (totalProfit / inventoryCost) * 100 : 0.0;

  return DashboardData(
    totalItems: items.length,
    totalSales: sales.length,
    stockUnits: stockUnits,
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    inventoryCost: inventoryCost,
    revenue30Days: revenue30Days,
    profit30Days: profit30Days,
    roiPercent: roiPercent,
    todaySalesCount: todaySales.length,
    todayProfit: todayProfit,
    recentSales: sales.take(5).toList(),
    sales: sales,
    purchaseDetails: purchaseDetails,
    stockRows: stock.take(5).toList(),
    alerts: alerts,
  );
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

num _profitForSale(Map<String, dynamic> row, List<Map<String, dynamic>> purchaseDetails) {
  final salePrice = row['sale_price'] as num? ?? 0;
  final fees = row['fees'] as num? ?? 0;
  final shipping = row['shipping_cost'] as num? ?? 0;
  final avgCost = averageUnitCostForItem(purchaseDetails, row['item_id'] as String?);
  return salePrice - fees - shipping - avgCost;
}

class DashboardData {
  DashboardData({
    required this.totalItems,
    required this.totalSales,
    required this.stockUnits,
    required this.totalRevenue,
    required this.totalProfit,
    required this.inventoryCost,
    required this.revenue30Days,
    required this.profit30Days,
    required this.roiPercent,
    required this.todaySalesCount,
    required this.todayProfit,
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
  final num revenue30Days;
  final num profit30Days;
  final double roiPercent;
  final int todaySalesCount;
  final num todayProfit;
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
  critical,
}

enum _DashboardAlertKind {
  lowStock,
  pendingPurchase,
  staleStock,
}

List<_PerformancePoint> _salesAndProfitByMonth(
  List<Map<String, dynamic>> sales,
  List<Map<String, dynamic>> purchaseDetails, {
  int months = 6,
}) {
  final now = DateTime.now();
  final buckets = <DateTime, _MonthlyBucket>{};
  for (var i = months - 1; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i);
    buckets[month] = const _MonthlyBucket(revenue: 0, profit: 0);
  }

  for (final row in sales) {
    final soldDate = _parseDate(row['sold_date']);
    if (soldDate == null) continue;
    final monthKey = DateTime(soldDate.year, soldDate.month);
    if (!buckets.containsKey(monthKey)) continue;
    final current = buckets[monthKey]!;
    buckets[monthKey] = _MonthlyBucket(
      revenue: current.revenue + (row['sale_price'] as num? ?? 0),
      profit: current.profit + _profitForSale(row, purchaseDetails),
    );
  }

  return buckets.entries
      .map(
        (entry) => _PerformancePoint(
          label: DateFormat.MMM().format(entry.key),
          revenue: entry.value.revenue,
          profit: entry.value.profit,
        ),
      )
      .toList();
}

class _MonthlyBucket {
  const _MonthlyBucket({
    required this.revenue,
    required this.profit,
  });

  final num revenue;
  final num profit;
}

class _PerformancePoint {
  const _PerformancePoint({
    required this.label,
    required this.revenue,
    required this.profit,
  });

  final String label;
  final num revenue;
  final num profit;
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.userLabel,
    required this.todaySalesCount,
    required this.todayProfit,
  });

  final String userLabel;
  final int todaySalesCount;
  final num todayProfit;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 760;
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userLabel!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Today: $todaySalesCount item${todaySalesCount == 1 ? '' : 's'} sold, ${_currency(todayProfit)} profit',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        if (!isMobile)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF475569), width: 2),
              gradient: const LinearGradient(
                colors: [Color(0xFF334155), Color(0xFF1E293B)],
              ),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
      ],
    );
  }
}

class _DashboardActions extends StatelessWidget {
  const _DashboardActions({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
      children: [
        _ActionButton(
          icon: Icons.sync_rounded,
          label: 'Sync Data',
          onTap: () => context.go('/items'),
        ),
        _ActionButton(
          icon: Icons.email_outlined,
          label: 'Import Purchases',
          onTap: () => context.go('/purchase-history'),
        ),
        _ActionButton(
          icon: Icons.point_of_sale_outlined,
          label: 'Record Sale',
          onTap: () => context.go('/sales'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.72),
        side: const BorderSide(color: Color(0xFF334155)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.value,
    this.subtitle,
    this.accentText,
    this.accentColor,
  });

  final IconData icon;
  final Color iconBackground;
  final String label;
  final String value;
  final String? subtitle;
  final String? accentText;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2232),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.4),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
              ),
              if (accentText != null) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    accentText!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: accentColor ?? const Color(0xFF86EFAC),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _DualLineChart extends StatelessWidget {
  const _DualLineChart({required this.points});

  final List<_PerformancePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _DashboardEmptyState(
        message: 'No sales data yet. Record sales to unlock trend reporting.',
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: CustomPaint(
            painter: _DualLineChartPainter(points: points),
            child: Container(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _ChartLegend(label: 'Profit', color: const Color(0xFF86EFAC)),
            _ChartLegend(label: 'Revenue', color: const Color(0xFF60A5FA)),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  _DualLineChartPainter({required this.points});

  final List<_PerformancePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const topPadding = 18.0;
    const bottomPadding = 28.0;
    const leftPadding = 14.0;
    const rightPadding = 14.0;
    const chartHeight = 214.0;
    final chartTop = topPadding;
    final chartBottom = chartTop + chartHeight;
    final chartWidth = size.width - leftPadding - rightPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    final values = [
      for (final point in points) point.revenue.toDouble(),
      for (final point in points) point.profit.toDouble(),
    ];
    final maxValue = values.fold<double>(0, math.max);
    final minValue = values.fold<double>(0, math.min);
    final range = (maxValue - minValue).abs() < 1 ? 1.0 : (maxValue - minValue).abs();

    for (var i = 0; i < 4; i++) {
      final y = chartTop + ((chartHeight / 3) * i);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);
      final axisValue = maxValue - ((range / 3) * i);
      final textPainter = TextPainter(
        text: TextSpan(text: axisValue.toStringAsFixed(0), style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - 8));
    }

    Offset pointOffset(int index, double value) {
      final denominator = math.max(points.length - 1, 1);
      final x = leftPadding + (chartWidth * (index / denominator));
      final normalized = (value - minValue) / range;
      final y = chartBottom - (normalized * chartHeight);
      return Offset(x, y);
    }

    final revenuePath = Path();
    final profitPath = Path();
    for (var i = 0; i < points.length; i++) {
      final revenueOffset = pointOffset(i, points[i].revenue.toDouble());
      final profitOffset = pointOffset(i, points[i].profit.toDouble());
      if (i == 0) {
        revenuePath.moveTo(revenueOffset.dx, revenueOffset.dy);
        profitPath.moveTo(profitOffset.dx, profitOffset.dy);
      } else {
        revenuePath.lineTo(revenueOffset.dx, revenueOffset.dy);
        profitPath.lineTo(profitOffset.dx, profitOffset.dy);
      }
    }

    final revenuePaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final profitPaint = Paint()
      ..color = const Color(0xFF86EFAC)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(revenuePath, revenuePaint);
    canvas.drawPath(profitPath, profitPaint);

    final pointFill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final revenueOffset = pointOffset(i, points[i].revenue.toDouble());
      final profitOffset = pointOffset(i, points[i].profit.toDouble());
      pointFill.color = const Color(0xFF60A5FA);
      canvas.drawCircle(revenueOffset, 4.5, pointFill);
      pointFill.color = const Color(0xFF86EFAC);
      canvas.drawCircle(profitOffset, 4.5, pointFill);

      final textPainter = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(revenueOffset.dx - (textPainter.width / 2), chartBottom + bottomPadding - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _NeedsAttentionList extends StatelessWidget {
  const _NeedsAttentionList({required this.alerts});

  final List<DashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const _DashboardEmptyState(
        message: 'No alerts right now. Stock and purchases are looking healthy.',
      );
    }

    return Column(
      children: alerts
          .map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AttentionRow(alert: alert),
            ),
          )
          .toList(),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.alert});

  final DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    final tone = switch (alert.tone) {
      _AlertTone.critical => const _AttentionTone(
          icon: Icons.priority_high_rounded,
          color: Color(0xFFEF4444),
        ),
      _AlertTone.warning => const _AttentionTone(
          icon: Icons.warning_amber_rounded,
          color: Color(0xFFFACC15),
        ),
      _AlertTone.info => const _AttentionTone(
          icon: Icons.notifications_active_outlined,
          color: Color(0xFFFB923C),
        ),
    };

    return InkWell(
      onTap: () => _showAlertDialog(context, alert),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2433),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tone.color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(tone.icon, color: tone.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionTile(
          icon: Icons.add_rounded,
          label: 'Add Item',
          onTap: () => context.go('/items'),
        ),
        const SizedBox(height: 12),
        _QuickActionTile(
          icon: Icons.shopping_bag_outlined,
          label: 'Add Purchase',
          onTap: () => context.go('/purchase-history'),
        ),
        const SizedBox(height: 12),
        _QuickActionTile(
          icon: Icons.sell_outlined,
          label: 'Record Sale',
          onTap: () => context.go('/sales'),
        ),
      ],
    );
  }
}

class _AttentionTone {
  const _AttentionTone({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2433),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSalesTable extends StatelessWidget {
  const _RecentSalesTable({
    required this.rows,
    required this.purchaseDetails,
  });

  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> purchaseDetails;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _DashboardEmptyState(
        message: 'No sales yet. Add your first sale to populate this area.',
      );
    }

    return Column(
      children: [
        const _TableHeader(
          columns: ['Item', 'Sale Price', 'Profit', 'Platform', 'Date'],
          flex: [3, 2, 2, 2, 2],
        ),
        ...rows.map((row) {
          final profit = _currency(_profitForSale(row, purchaseDetails));
          return _TableRow(
            columns: [
              row['items']?['title'] as String? ?? formatReferenceId(row['id'], prefix: 'SAL'),
              _currency(row['sale_price'] as num? ?? 0),
              profit,
              row['platform'] as String? ?? '—',
              _friendlyDate(row['sold_date'] as String?),
            ],
            flex: const [3, 2, 2, 2, 2],
            highlightIndex: 2,
            highlightColor: const Color(0xFF86EFAC),
          );
        }),
      ],
    );
  }
}

class _StockHealthTable extends StatelessWidget {
  const _StockHealthTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _DashboardEmptyState(
        message: 'No stock rows yet. Add purchases into stock to see them here.',
      );
    }

    return Column(
      children: [
        const _TableHeader(
          columns: ['Item', 'Quantity', 'Updated', 'Status'],
          flex: [4, 2, 3, 3],
        ),
        ...rows.map((row) {
          final quantity = row['quantity'] as int? ?? 0;
          final updated = _parseDate(row['updated_at']);
          final status = quantity <= 1
              ? const _StockStatus('Low Stock', Color(0xFFEF4444))
              : updated != null &&
                      updated.isBefore(DateTime.now().subtract(const Duration(days: 30)))
                  ? const _StockStatus('Stale Stock', Color(0xFF3B82F6))
                  : const _StockStatus('Healthy', Color(0xFF22C55E));
          return _TableRow(
            columns: [
              row['items']?['title'] as String? ?? formatReferenceId(row['id'], prefix: 'STK'),
              '$quantity',
              _friendlyDate(row['updated_at'] as String?),
              status.label,
            ],
            flex: const [4, 2, 3, 3],
            highlightIndex: 3,
            highlightColor: status.color,
            pillHighlight: true,
          );
        }),
      ],
    );
  }
}

class _StockStatus {
  const _StockStatus(this.label, this.color);

  final String label;
  final Color color;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.columns,
    required this.flex,
  });

  final List<String> columns;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF232D3D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(
                columns[i],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.columns,
    required this.flex,
    this.highlightIndex,
    this.highlightColor,
    this.pillHighlight = false,
  });

  final List<String> columns;
  final List<int> flex;
  final int? highlightIndex;
  final Color? highlightColor;
  final bool pillHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2433),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: flex[i],
              child: i == highlightIndex && pillHighlight
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (highlightColor ?? Colors.white).withOpacity(0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          columns[i],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    )
                  : Text(
                      columns[i],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: i == highlightIndex ? highlightColor ?? Colors.white : Colors.white,
                            fontWeight: i == 0 || i == highlightIndex ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2433),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF94A3B8),
            ),
      ),
    );
  }
}

Future<void> _showAlertDialog(BuildContext context, DashboardAlert alert) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xFF161E2C),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                alert.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF94A3B8),
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
      _DashboardAlertKind.pendingPurchase => '${row['quantity'] ?? 0} x ${_currency(row['unit_price'] as num? ?? 0)}',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2433),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;

  final local = parsed.toLocal();
  final hasTime = local.hour != 0 || local.minute != 0 || local.second != 0;
  if (hasTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }
  return DateFormat('yyyy-MM-dd').format(local);
}

String _friendlyDate(String? value) {
  final parsed = _parseDate(value);
  if (parsed == null) return '—';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(parsed.year, parsed.month, parsed.day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return DateFormat('MMM d').format(parsed);
}
