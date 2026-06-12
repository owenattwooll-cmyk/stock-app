import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/cost_calculations.dart';
import '../utils/reference_id.dart';
import '../widgets/section_card.dart';

enum _DashboardRange {
  daily,
  weekly,
  monthly,
}

enum _DashboardMetricType {
  profit,
  revenue,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _future;
  _DashboardRange _selectedRange = _DashboardRange.monthly;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _future = _loadDashboard(SupabaseService(Supabase.instance.client), user.id);
    }
  }

  void _reload() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() {
      _future = _loadDashboard(SupabaseService(Supabase.instance.client), user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<DashboardData>(
      future: _future,
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
                    _reload();
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
        final filteredSummary = _buildRangeSummary(
          sales: data.sales,
          purchaseDetails: data.purchaseDetails,
          range: _selectedRange,
        );
        final monthlyPerformance = _salesAndProfitByMonth(
          data.sales,
          data.purchaseDetails,
          months: 6,
        );
        final chartSummary = _buildChartSummary(monthlyPerformance);
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
                    Divider(color: const Color(0xFF334155).withValues(alpha: 0.8), height: 1),
                    const SizedBox(height: 28),
                    _DashboardMetricGrid(
                      isMobile: isMobile,
                      isTablet: isTablet,
                      header: _DashboardRangePicker(
                        selectedRange: _selectedRange,
                        onChanged: (range) => setState(() => _selectedRange = range),
                      ),
                      cards: [
                        _DashboardMetricCardData(
                          label: 'Profit',
                          value: _currency(filteredSummary.profit),
                          hint: _rangeLabel(_selectedRange),
                          detail: 'Net profit after fees, shipping, and average item cost.',
                          toneColor: const Color(0xFF34D399),
                          statLine: '${filteredSummary.salesCount} sale${filteredSummary.salesCount == 1 ? '' : 's'} in range',
                          onTap: () => context.go(
                            '/dashboard/metric/profit?range=${_rangeQueryValue(_selectedRange)}',
                          ),
                        ),
                        _DashboardMetricCardData(
                          label: 'Revenue',
                          value: _currency(filteredSummary.revenue),
                          hint: _rangeLabel(_selectedRange),
                          detail: 'Gross sales value before costs are removed.',
                          toneColor: const Color(0xFF60A5FA),
                          statLine: 'Average sale ${_currency(filteredSummary.averageSale)}',
                          onTap: () => context.go(
                            '/dashboard/metric/revenue?range=${_rangeQueryValue(_selectedRange)}',
                          ),
                        ),
                        _DashboardMetricCardData(
                          label: 'Items in Stock',
                          value: data.stockUnits.toString(),
                          hint: 'Units available now',
                          detail: '${data.totalItems} catalogued items across your inventory.',
                          toneColor: const Color(0xFF818CF8),
                          statLine: '${data.alerts.where((alert) => alert.kind == _DashboardAlertKind.lowStock).length} low-stock alerts',
                        ),
                        _DashboardMetricCardData(
                          label: 'ROI',
                          value: '${data.roiPercent.toStringAsFixed(0)}%',
                          hint: 'All-time return',
                          detail: 'Profit compared with current inventory cost.',
                          toneColor: const Color(0xFFF59E0B),
                          statLine: 'Inventory cost ${_currency(data.inventoryCost)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isTablet)
                      Column(
                        children: [
                          _DashboardPanel(
                            title: 'Performance Snapshot',
                            child: _PerformanceOverview(
                              points: monthlyPerformance,
                              summary: chartSummary,
                              stacked: true,
                            ),
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
                              title: 'Performance Snapshot',
                              child: _PerformanceOverview(
                                points: monthlyPerformance,
                                summary: chartSummary,
                                stacked: false,
                              ),
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

class DashboardMetricDetailScreen extends StatefulWidget {
  const DashboardMetricDetailScreen({
    super.key,
    required this.metricKey,
    this.initialRangeKey,
  });

  final String metricKey;
  final String? initialRangeKey;

  @override
  State<DashboardMetricDetailScreen> createState() => _DashboardMetricDetailScreenState();
}

class _DashboardMetricDetailScreenState extends State<DashboardMetricDetailScreen> {
  late Future<DashboardData> _future;
  late _DashboardRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = _dashboardRangeFromQuery(widget.initialRangeKey);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _future = _loadDashboard(SupabaseService(Supabase.instance.client), user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final metricType = _metricTypeFromKey(widget.metricKey);

    return FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return SectionCard(
              title: 'Metric unavailable',
              child: Text('${snapshot.error}'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final summary = _buildRangeSummary(
          sales: data.sales,
          purchaseDetails: data.purchaseDetails,
          range: _selectedRange,
        );
        final points = _buildMetricTrendPoints(
          sales: data.sales,
          purchaseDetails: data.purchaseDetails,
          metric: metricType,
          range: _selectedRange,
        );
        final value = metricType == _DashboardMetricType.profit ? summary.profit : summary.revenue;
        final title = metricType == _DashboardMetricType.profit ? 'Profit Details' : 'Revenue Details';
        final detailRows = _rowsForRange(
          sales: data.sales,
          range: _selectedRange,
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${_rangeLabel(_selectedRange)} overview with chart and sale-by-sale context.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DashboardRangePicker(
                selectedRange: _selectedRange,
                onChanged: (range) {
                  setState(() => _selectedRange = range);
                  context.go('/dashboard/metric/${widget.metricKey}?range=${_rangeQueryValue(range)}');
                },
              ),
              const SizedBox(height: 20),
              _DashboardMetricGrid(
                isMobile: MediaQuery.sizeOf(context).width < 760,
                isTablet: MediaQuery.sizeOf(context).width < 1180,
                cards: [
                  _DashboardMetricCardData(
                    label: metricType == _DashboardMetricType.profit ? 'Profit' : 'Revenue',
                    value: _currency(value),
                    hint: _rangeLabel(_selectedRange),
                    detail: metricType == _DashboardMetricType.profit
                        ? 'Net figure after fees, shipping, and cost of goods.'
                        : 'Gross value from completed sales in the selected period.',
                    toneColor: metricType == _DashboardMetricType.profit
                        ? const Color(0xFF34D399)
                        : const Color(0xFF60A5FA),
                    statLine: '${summary.salesCount} sale${summary.salesCount == 1 ? '' : 's'} in range',
                  ),
                  _DashboardMetricCardData(
                    label: 'Average Sale',
                    value: _currency(summary.averageSale),
                    hint: 'Selected range',
                    detail: 'Average sale price across matching completed sales.',
                    toneColor: const Color(0xFF818CF8),
                    statLine: 'Revenue ${_currency(summary.revenue)}',
                  ),
                  _DashboardMetricCardData(
                    label: 'Average Profit',
                    value: _currency(summary.averageProfitPerSale),
                    hint: 'Selected range',
                    detail: 'Average profit contribution per sale in this time window.',
                    toneColor: const Color(0xFFF59E0B),
                    statLine: 'Profit ${_currency(summary.profit)}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DashboardPanel(
                title: '${metricType == _DashboardMetricType.profit ? 'Profit' : 'Revenue'} Trend',
                child: _MetricDetailOverview(
                  metric: metricType,
                  range: _selectedRange,
                  points: points,
                  rows: detailRows,
                  purchaseDetails: data.purchaseDetails,
                ),
              ),
            ],
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

String _rangeLabel(_DashboardRange range) {
  return switch (range) {
    _DashboardRange.daily => 'Today',
    _DashboardRange.weekly => 'Last 7 days',
    _DashboardRange.monthly => 'Last 30 days',
  };
}

String _rangeQueryValue(_DashboardRange range) {
  return switch (range) {
    _DashboardRange.daily => 'daily',
    _DashboardRange.weekly => 'weekly',
    _DashboardRange.monthly => 'monthly',
  };
}

_DashboardRange _dashboardRangeFromQuery(String? value) {
  return switch (value) {
    'daily' => _DashboardRange.daily,
    'weekly' => _DashboardRange.weekly,
    _ => _DashboardRange.monthly,
  };
}

_DashboardMetricType _metricTypeFromKey(String value) {
  return value == 'profit' ? _DashboardMetricType.profit : _DashboardMetricType.revenue;
}

DateTime _rangeStart(DateTime now, _DashboardRange range) {
  return switch (range) {
    _DashboardRange.daily => DateTime(now.year, now.month, now.day),
    _DashboardRange.weekly => now.subtract(const Duration(days: 7)),
    _DashboardRange.monthly => now.subtract(const Duration(days: 30)),
  };
}

class _RangeSummary {
  const _RangeSummary({
    required this.revenue,
    required this.profit,
    required this.salesCount,
    required this.averageSale,
    required this.averageProfitPerSale,
  });

  final num revenue;
  final num profit;
  final int salesCount;
  final num averageSale;
  final num averageProfitPerSale;
}

_RangeSummary _buildRangeSummary({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> purchaseDetails,
  required _DashboardRange range,
}) {
  final rows = _rowsForRange(sales: sales, range: range);
  final revenue = rows.fold<num>(0, (sum, row) => sum + (row['sale_price'] as num? ?? 0));
  final profit = rows.fold<num>(0, (sum, row) => sum + _profitForSale(row, purchaseDetails));
  final salesCount = rows.length;

  return _RangeSummary(
    revenue: revenue,
    profit: profit,
    salesCount: salesCount,
    averageSale: salesCount == 0 ? 0 : revenue / salesCount,
    averageProfitPerSale: salesCount == 0 ? 0 : profit / salesCount,
  );
}

List<Map<String, dynamic>> _rowsForRange({
  required List<Map<String, dynamic>> sales,
  required _DashboardRange range,
}) {
  final now = DateTime.now();
  final start = _rangeStart(now, range);
  return sales.where((row) {
    final soldDate = _parseDate(row['sold_date']);
    return soldDate != null && !soldDate.isBefore(start);
  }).toList()
    ..sort((a, b) {
      final left = _parseDate(a['sold_date']);
      final right = _parseDate(b['sold_date']);
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
}

_ChartSummary _buildChartSummary(List<_PerformancePoint> points) {
  if (points.isEmpty) {
    return const _ChartSummary(
      totalRevenue: 0,
      totalProfit: 0,
      bestRevenueMonth: 'No data',
      bestProfitMonth: 'No data',
      averageRevenue: 0,
      averageProfit: 0,
    );
  }

  var totalRevenue = 0.0;
  var totalProfit = 0.0;
  var bestRevenue = points.first;
  var bestProfit = points.first;

  for (final point in points) {
    totalRevenue += point.revenue.toDouble();
    totalProfit += point.profit.toDouble();
    if (point.revenue > bestRevenue.revenue) {
      bestRevenue = point;
    }
    if (point.profit > bestProfit.profit) {
      bestProfit = point;
    }
  }

  return _ChartSummary(
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    bestRevenueMonth: bestRevenue.label,
    bestProfitMonth: bestProfit.label,
    averageRevenue: totalRevenue / points.length,
    averageProfit: totalProfit / points.length,
  );
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
        backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.72),
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

class _DashboardMetricCardData {
  const _DashboardMetricCardData({
    required this.label,
    required this.value,
    required this.hint,
    required this.detail,
    required this.toneColor,
    required this.statLine,
    this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final String detail;
  final Color toneColor;
  final String statLine;
  final VoidCallback? onTap;
}

class _DashboardMetricGrid extends StatelessWidget {
  const _DashboardMetricGrid({
    required this.isMobile,
    required this.isTablet,
    required this.cards,
    this.header,
  });

  final bool isMobile;
  final bool isTablet;
  final List<_DashboardMetricCardData> cards;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: 18),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 1 : isTablet ? 2 : 4,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            mainAxisExtent: isMobile ? 172 : 184,
          ),
          itemBuilder: (context, index) => _SimpleMetricCard(data: cards[index]),
        ),
      ],
    );
  }
}

class _DashboardRangePicker extends StatelessWidget {
  const _DashboardRangePicker({
    required this.selectedRange,
    required this.onChanged,
  });

  final _DashboardRange selectedRange;
  final ValueChanged<_DashboardRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Profit & Revenue Range',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        for (final range in _DashboardRange.values)
          ChoiceChip(
            label: Text(
              switch (range) {
                _DashboardRange.daily => 'Daily',
                _DashboardRange.weekly => '1 Week',
                _DashboardRange.monthly => 'Month',
              },
            ),
            selected: range == selectedRange,
            onSelected: (_) => onChanged(range),
          ),
      ],
    );
  }
}

class _SimpleMetricCard extends StatelessWidget {
  const _SimpleMetricCard({required this.data});

  final _DashboardMetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2232),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: data.toneColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (data.onTap != null)
                    const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                data.value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                data.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFCBD5E1),
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF293243)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 16, color: data.toneColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.statLine,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _ChartSummary {
  const _ChartSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.bestRevenueMonth,
    required this.bestProfitMonth,
    required this.averageRevenue,
    required this.averageProfit,
  });

  final double totalRevenue;
  final double totalProfit;
  final String bestRevenueMonth;
  final String bestProfitMonth;
  final double averageRevenue;
  final double averageProfit;
}

class _PerformanceOverview extends StatelessWidget {
  const _PerformanceOverview({
    required this.points,
    required this.summary,
    required this.stacked,
  });

  final List<_PerformancePoint> points;
  final _ChartSummary summary;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final chart = _DualLineChart(points: points);
    final insights = _PerformanceInsights(summary: summary);

    if (stacked) {
      return Column(
        children: [
          chart,
          const SizedBox(height: 18),
          insights,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: chart),
        const SizedBox(width: 18),
        Expanded(flex: 3, child: insights),
      ],
    );
  }
}

class _PerformanceInsights extends StatelessWidget {
  const _PerformanceInsights({required this.summary});

  final _ChartSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InsightTile(
          label: '6-Month Revenue',
          value: _currency(summary.totalRevenue),
          subtitle: 'Combined revenue across the chart period',
        ),
        const SizedBox(height: 12),
        _InsightTile(
          label: '6-Month Profit',
          value: _currency(summary.totalProfit),
          subtitle: 'Combined profit after costs',
        ),
        const SizedBox(height: 12),
        _InsightTile(
          label: 'Best Revenue Month',
          value: summary.bestRevenueMonth,
          subtitle: 'Average ${_currency(summary.averageRevenue)} per month',
        ),
        const SizedBox(height: 12),
        _InsightTile(
          label: 'Best Profit Month',
          value: summary.bestProfitMonth,
          subtitle: 'Average ${_currency(summary.averageProfit)} per month',
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2433),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCBD5E1),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricTrendPoint {
  const _MetricTrendPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

List<_MetricTrendPoint> _buildMetricTrendPoints({
  required List<Map<String, dynamic>> sales,
  required List<Map<String, dynamic>> purchaseDetails,
  required _DashboardMetricType metric,
  required _DashboardRange range,
}) {
  final now = DateTime.now();
  switch (range) {
    case _DashboardRange.daily:
      final buckets = <int, double>{for (var hour = 0; hour < 24; hour += 4) hour: 0};
      final start = DateTime(now.year, now.month, now.day);
      for (final row in sales) {
        final soldDate = _parseDate(row['sold_date']);
        if (soldDate == null || soldDate.isBefore(start)) continue;
        final bucketHour = (soldDate.hour ~/ 4) * 4;
        final value = metric == _DashboardMetricType.profit
            ? _profitForSale(row, purchaseDetails).toDouble()
            : (row['sale_price'] as num? ?? 0).toDouble();
        buckets[bucketHour] = (buckets[bucketHour] ?? 0) + value;
      }
      return buckets.entries
          .map((entry) => _MetricTrendPoint(
                label: '${entry.key.toString().padLeft(2, '0')}:00',
                value: entry.value,
              ))
          .toList();
    case _DashboardRange.weekly:
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final buckets = <DateTime, double>{};
      for (var i = 0; i < 7; i++) {
        final day = DateTime(start.year, start.month, start.day + i);
        buckets[day] = 0;
      }
      for (final row in sales) {
        final soldDate = _parseDate(row['sold_date']);
        if (soldDate == null) continue;
        final dayKey = DateTime(soldDate.year, soldDate.month, soldDate.day);
        if (!buckets.containsKey(dayKey)) continue;
        final value = metric == _DashboardMetricType.profit
            ? _profitForSale(row, purchaseDetails).toDouble()
            : (row['sale_price'] as num? ?? 0).toDouble();
        buckets[dayKey] = (buckets[dayKey] ?? 0) + value;
      }
      return buckets.entries
          .map((entry) => _MetricTrendPoint(
                label: DateFormat.E().format(entry.key),
                value: entry.value,
              ))
          .toList();
    case _DashboardRange.monthly:
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      final buckets = <int, double>{for (var i = 0; i < 5; i++) i: 0};
      for (final row in sales) {
        final soldDate = _parseDate(row['sold_date']);
        if (soldDate == null || soldDate.isBefore(start)) continue;
        final index = ((soldDate.difference(start).inDays) ~/ 7).clamp(0, 4);
        final value = metric == _DashboardMetricType.profit
            ? _profitForSale(row, purchaseDetails).toDouble()
            : (row['sale_price'] as num? ?? 0).toDouble();
        buckets[index] = (buckets[index] ?? 0) + value;
      }
      return buckets.entries
          .map((entry) => _MetricTrendPoint(
                label: 'Week ${entry.key + 1}',
                value: entry.value,
              ))
          .toList();
  }
}

class _MetricDetailOverview extends StatelessWidget {
  const _MetricDetailOverview({
    required this.metric,
    required this.range,
    required this.points,
    required this.rows,
    required this.purchaseDetails,
  });

  final _DashboardMetricType metric;
  final _DashboardRange range;
  final List<_MetricTrendPoint> points;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> purchaseDetails;

  @override
  Widget build(BuildContext context) {
    final tone = metric == _DashboardMetricType.profit
        ? const Color(0xFF34D399)
        : const Color(0xFF60A5FA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chart',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 14),
        _SingleMetricChart(
          points: points,
          color: tone,
          emptyMessage: 'No sales found for ${_rangeLabel(range).toLowerCase()}.',
        ),
        const SizedBox(height: 24),
        Text(
          'Included Sales',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _DashboardEmptyState(
            message: 'No completed sales in this range yet.',
          )
        else
          Column(
            children: rows.take(8).map((row) {
              final trailing = metric == _DashboardMetricType.profit
                  ? _currency(_profitForSale(row, purchaseDetails))
                  : _currency(row['sale_price'] as num? ?? 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MetricSaleRow(
                  title: row['items']?['title'] as String? ?? formatReferenceId(row['id'], prefix: 'SAL'),
                  subtitle:
                      '${row['platform'] as String? ?? 'Unknown platform'} • ${_friendlyDate(row['sold_date'] as String?)}',
                  trailing: trailing,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _MetricSaleRow extends StatelessWidget {
  const _MetricSaleRow({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2433),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SingleMetricChart extends StatelessWidget {
  const _SingleMetricChart({
    required this.points,
    required this.color,
    required this.emptyMessage,
  });

  final List<_MetricTrendPoint> points;
  final Color color;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final hasValues = points.any((point) => point.value != 0);
    if (points.isEmpty || !hasValues) {
      return _DashboardEmptyState(message: emptyMessage);
    }

    return SizedBox(
      height: 260,
      child: CustomPaint(
        painter: _SingleMetricChartPainter(points: points, color: color),
        child: Container(),
      ),
    );
  }
}

class _SingleMetricChartPainter extends CustomPainter {
  _SingleMetricChartPainter({
    required this.points,
    required this.color,
  });

  final List<_MetricTrendPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
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

    final maxValue = points.map((point) => point.value).fold<double>(0, math.max);
    final minValue = points.map((point) => point.value).fold<double>(0, math.min);
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

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = pointOffset(i, points[i].value);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    final pointFill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    for (var i = 0; i < points.length; i++) {
      final offset = pointOffset(i, points[i].value);
      canvas.drawCircle(offset, 4.5, pointFill);
      final textPainter = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(offset.dx - (textPainter.width / 2), chartBottom + bottomPadding - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SingleMetricChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
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
                  color: tone.color.withValues(alpha: 0.14),
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
                          color: (highlightColor ?? Colors.white).withValues(alpha: 0.22),
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
