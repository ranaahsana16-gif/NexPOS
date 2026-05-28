import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/pos_provider.dart';
import '../services/firebase_service.dart';
import '../models/models.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_glass_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sales = [];
  Map<String, double> _paymentSplit = {'Cash': 0, 'Card': 0, 'Transfer': 0, 'Credit': 0};
  List<double> _weeklySales = List.filled(7, 0.0);
  List<String> _weeklyDays = [];
  Map<int, int> _hourlySalesCount = {};
  String _peakHoursString = "No transactions";

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    final provider = Provider.of<POSProvider>(context, listen: false);
    final userId = provider.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final salesData = await FirebaseService.fetchTable('sales', filters: {'user_id': userId});
      
      // Initialize past 7 days list
      final now = DateTime.now();
      final List<DateTime> pastDays = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
      final df = DateFormat('M/d/yyyy');
      _weeklyDays = pastDays.map((d) => DateFormat('E').format(d)).toList();

      final Map<String, double> dailyTotals = {};
      for (var d in pastDays) {
        dailyTotals[df.format(d)] = 0.0;
      }

      final Map<String, double> pSplit = {'Cash': 0, 'Card': 0, 'Transfer': 0, 'Credit': 0};
      final Map<int, int> hourlyCounts = {};

      for (var sale in salesData) {
        // Parse date
        final dateStr = sale['date']?.toString() ?? '';
        final double total = (sale['total'] as num?)?.toDouble() ?? 0.0;
        final method = sale['payment_method']?.toString() ?? 'Cash';

        // Payment split
        if (pSplit.containsKey(method)) {
          pSplit[method] = pSplit[method]! + total;
        } else {
          pSplit['Cash'] = pSplit['Cash']! + total;
        }

        // Daily totals for past 7 days
        // Normalize date format from sale (sometimes M/d/yyyy, sometimes M/dd/yyyy)
        try {
          final parsedDate = _parseReportDate(sale['date']?.toString() ?? '', sale['time']?.toString() ?? '');
          if (parsedDate != null) {
            final key = df.format(parsedDate);
            if (dailyTotals.containsKey(key)) {
              dailyTotals[key] = dailyTotals[key]! + total;
            }

            // Hourly distribution
            final hour = parsedDate.hour;
            hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
          }
        } catch (_) {}
      }

      // Populate weekly list
      for (int i = 0; i < 7; i++) {
        final key = df.format(pastDays[i]);
        _weeklySales[i] = dailyTotals[key] ?? 0.0;
      }

      // Calculate peak hours
      int peakHourStart = -1;
      int maxTransactions = 0;
      hourlyCounts.forEach((hour, count) {
        if (count > maxTransactions) {
          maxTransactions = count;
          peakHourStart = hour;
        }
      });

      if (peakHourStart != -1) {
        final startLabel = DateFormat('h a').format(DateTime(2000, 1, 1, peakHourStart));
        final endLabel = DateFormat('h a').format(DateTime(2000, 1, 1, (peakHourStart + 2) % 24));
        _peakHoursString = "$startLabel - $endLabel ($maxTransactions sales)";
      }

      setState(() {
        _sales = salesData;
        _paymentSplit = pSplit;
        _hourlySalesCount = hourlyCounts;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading analytics data: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  DateTime? _parseReportDate(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        final timeParts = timeStr.split(':');
        final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
        final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
        final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
        
        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    return DateTime.tryParse(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    
    final bg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final purple = const Color(0xFF8B5CF6);
    final accent = theme.primaryColor;
    final danger = theme.colorScheme.error;
    final positive = const Color(0xFF10B981);

    // Filter low stock products
    final lowStockProducts = provider.products.where((p) {
      final limit = p.minStock ?? 5.0;
      return p.stock <= limit;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        title: Text(
          "Business Analytics",
          style: GoogleFonts.plusJakartaSans(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: PremiumBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _fetchAnalyticsData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Graph 1: Weekly Sales
                        PremiumGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Weekly Sales Revenue",
                                style: GoogleFonts.plusJakartaSans(
                                  color: textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Total revenue generated per day for the last 7 days",
                                style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child: _weeklySales.every((v) => v == 0)
                                    ? Center(child: Text("No sales data in this period", style: GoogleFonts.inter(color: textSecondary)))
                                    : LineChart(
                                        LineChartData(
                                          gridData: const FlGridData(show: false),
                                          titlesData: FlTitlesData(
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 45,
                                                getTitlesWidget: (value, meta) {
                                                  if (value == meta.max || value == meta.min) return const SizedBox();
                                                  return Text(
                                                    "Rs.${value.toInt()}",
                                                    style: GoogleFonts.inter(color: textSecondary, fontSize: 8),
                                                  );
                                                },
                                              ),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  final idx = value.toInt();
                                                  if (idx >= 0 && idx < _weeklyDays.length) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 8.0),
                                                      child: Text(_weeklyDays[idx], style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
                                                    );
                                                  }
                                                  return const SizedBox();
                                                },
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: List.generate(7, (i) => FlSpot(i.toDouble(), _weeklySales[i])),
                                              isCurved: true,
                                              color: accent,
                                              barWidth: 3,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(show: true),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                color: accent.withValues(alpha: 0.15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment Splits (Pie Chart) & Peak Hours
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: PremiumGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Payment Split",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 150,
                                      child: _paymentSplit.values.every((v) => v == 0)
                                          ? Center(child: Text("No splits", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)))
                                          : PieChart(
                                              PieChartData(
                                                sectionsSpace: 4,
                                                centerSpaceRadius: 30,
                                                sections: [
                                                  PieChartSectionData(
                                                    color: const Color(0xFFFBBF24), // Yellow
                                                    value: _paymentSplit['Cash']!,
                                                    title: _paymentSplit['Cash']! > 0 ? "Cash" : "",
                                                    radius: 40,
                                                    titleStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                                                  ),
                                                  PieChartSectionData(
                                                    color: purple, // Purple
                                                    value: _paymentSplit['Card']!,
                                                    title: _paymentSplit['Card']! > 0 ? "Card" : "",
                                                    radius: 40,
                                                    titleStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                  PieChartSectionData(
                                                    color: const Color(0xFF3B82F6), // Blue
                                                    value: _paymentSplit['Transfer']!,
                                                    title: _paymentSplit['Transfer']! > 0 ? "Bank" : "",
                                                    radius: 40,
                                                    titleStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                  PieChartSectionData(
                                                    color: const Color(0xFFEC4899), // Pink
                                                    value: _paymentSplit['Credit']!,
                                                    title: _paymentSplit['Credit']! > 0 ? "Khata" : "",
                                                    radius: 40,
                                                    titleStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: PremiumGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Peak Hours",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Icon(Icons.alarm_on_rounded, color: Color(0xFF10B981), size: 36),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Highest Activity Timeframe",
                                      style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _peakHoursString,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Low Stock Alert
                        PremiumGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Low Stock Alerts",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (lowStockProducts.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: danger.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${lowStockProducts.length} Items",
                                        style: GoogleFonts.inter(color: danger, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Products below their minimum warning threshold",
                                style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 16),
                              lowStockProducts.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 20),
                                        child: Text(
                                          "All inventory stock is fully restocked!",
                                          style: GoogleFonts.inter(color: positive, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: lowStockProducts.length,
                                      separatorBuilder: (_, __) => Divider(color: border.withValues(alpha: 0.5)),
                                      itemBuilder: (context, idx) {
                                        final prod = lowStockProducts[idx];
                                        final isOut = prod.stock <= 0;
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    prod.name,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: textPrimary,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Code: ${prod.code} • Min Limit: ${prod.minStock ?? 5}",
                                                    style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isOut ? danger.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isOut ? "OUT OF STOCK" : "${prod.stock.toStringAsFixed(0)} Left",
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: isOut ? danger : Colors.orange,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ],
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
}
