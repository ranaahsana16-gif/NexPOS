import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/pos_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_glass_card.dart';

class ReportsScreen extends StatefulWidget {
  final String? initialTab;
  const ReportsScreen({super.key, this.initialTab});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _activeTab = "sales"; // sales, suppliers, cash
  String _timeframe = "daily"; // daily, weekly, monthly, yearly
  bool _loading = true;

  List<Map<String, dynamic>> _salesReport = [];
  List<Map<String, dynamic>> _supplierReport = [];
  List<Map<String, dynamic>> _cashReport = [];

  final Set<String> _expandedSuppliers = {};

  // Today's Stats
  double _todaySales = 0.0;
  double _todayProfit = 0.0;
  int _todayOrders = 0;

  double _todaySupplierCost = 0.0;
  int _todaySupplierPurchases = 0;

  double _todayCashIn = 0.0;
  double _todayCashOut = 0.0;

  double _doubleFromVal(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }

  DateTime? _parseReportDate(Map<String, dynamic> item) {
    final dateVal = item['date'];
    if (dateVal == null) return null;
    if (dateVal is DateTime) return dateVal;
    
    final dateStr = dateVal.toString();
    final parsedIso = DateTime.tryParse(dateStr);
    if (parsedIso != null) return parsedIso;

    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        final timeStr = item['time']?.toString() ?? "00:00:00";
        final timeParts = timeStr.split(':');
        final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
        final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
        final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
        
        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _activeTab = widget.initialTab!;
    }
    _fetchReportsData();
  }

  Future<void> _fetchReportsData() async {
    final provider = Provider.of<POSProvider>(context, listen: false);
    final userId = provider.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // 1. Fetch Sales
      final salesData = await FirebaseService.fetchTable('sales', filters: {'user_id': userId});
      salesData.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      _salesReport = salesData;

      // 2. Fetch Supplier reports
      final supplierData = await FirebaseService.fetchTable('supplier_reports', filters: {'user_id': userId});
      supplierData.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      _supplierReport = supplierData;

      // 3. Fetch Cash transactions
      final cashData = await FirebaseService.fetchTable('cash_transactions', filters: {'user_id': userId});
      cashData.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      _cashReport = cashData;

      // 4. Calculate Today's Stats
      final todayStr = DateFormat('M/d/yyyy').format(DateTime.now());
      
      // Sales
      final todaySalesList = _salesReport.where((s) => s['date'] == todayStr || s['date'].toString().startsWith(todayStr)).toList();
      _todaySales = todaySalesList.fold(0.0, (sum, s) => sum + _doubleFromVal(s['total']));
      _todayProfit = todaySalesList.fold(0.0, (sum, s) => sum + _doubleFromVal(s['profit']));
      _todayOrders = todaySalesList.length;

      // Suppliers
      final todaySuppliersList = _supplierReport.where((s) => s['date'] == todayStr || s['date'].toString().startsWith(todayStr)).toList();
      _todaySupplierCost = todaySuppliersList.fold(0.0, (sum, s) => sum + _doubleFromVal(s['total_cost']));
      _todaySupplierPurchases = todaySuppliersList.length;

      // Cash Flow
      final todayCashList = _cashReport.where((c) {
        final dt = _parseReportDate(c);
        if (dt == null) return false;
        final now = DateTime.now();
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      }).toList();
      _todayCashIn = todayCashList.where((c) => c['type'] == 'IN').fold(0.0, (sum, c) => sum + _doubleFromVal(c['amount']));
      _todayCashOut = todayCashList.where((c) => c['type'] == 'OUT').fold(0.0, (sum, c) => sum + _doubleFromVal(c['amount']));

    } catch (e) {
      debugPrint("fetch reports error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getActiveSourceList() {
    if (_activeTab == "sales") return _salesReport;
    if (_activeTab == "suppliers") return _supplierReport;
    return _cashReport;
  }

  List<Map<String, dynamic>> _getItemsForDateRange(DateTime start, DateTime end) {
    final sourceList = _getActiveSourceList();
    return sourceList.where((item) {
      final dt = _parseReportDate(item);
      return dt != null && dt.isAfter(start.subtract(const Duration(seconds: 1))) && dt.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  // Retention filters
  List<Map<String, dynamic>> _getDailyRecords() {
    final now = DateTime.now();
    final limit24h = now.subtract(const Duration(hours: 24));
    final sourceList = _getActiveSourceList();
    
    return sourceList.where((item) {
      final dt = _parseReportDate(item);
      return dt != null && dt.isAfter(limit24h);
    }).toList();
  }

  List<Map<String, dynamic>> _compileWeeklySummary() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    
    final weeks = [
      {"weekNum": 1, "start": 1, "end": 7},
      {"weekNum": 2, "start": 8, "end": 14},
      {"weekNum": 3, "start": 15, "end": 21},
      {"weekNum": 4, "start": 22, "end": lastDay},
    ];

    final List<Map<String, dynamic>> compiled = [];

    for (final w in weeks) {
      final startDay = w["start"] as int;
      final endDay = w["end"] as int;
      final weekNum = w["weekNum"] as int;

      final items = _getItemsForDateRange(
        DateTime(year, month, startDay),
        DateTime(year, month, endDay, 23, 59, 59),
      );

      double totalVal = 0.0;
      double secondaryVal = 0.0;
      int count = items.length;

      if (_activeTab == "sales") {
        for (final item in items) {
          totalVal += _doubleFromVal(item['total']);
          secondaryVal += _doubleFromVal(item['profit']);
        }
      } else if (_activeTab == "suppliers") {
        for (final item in items) {
          totalVal += _doubleFromVal(item['total_cost']);
        }
      } else if (_activeTab == "cash") {
        for (final item in items) {
          final amount = _doubleFromVal(item['amount']);
          if (item['type'] == "IN") {
            totalVal += amount;
          } else {
            secondaryVal += amount;
          }
        }
      }

      compiled.add({
        "weekNum": weekNum,
        "startDay": startDay,
        "endDay": endDay,
        "month": month,
        "year": year,
        "total": totalVal,
        "secondary": secondaryVal,
        "count": count,
      });
    }

    return compiled;
  }

  List<Map<String, dynamic>> _compileMonthlySummary() {
    final now = DateTime.now();
    final year = now.year;
    
    final List<Map<String, dynamic>> compiled = [];

    for (int m = 1; m <= 12; m++) {
      final lastDay = DateTime(year, m + 1, 0).day;
      final items = _getItemsForDateRange(
        DateTime(year, m, 1),
        DateTime(year, m, lastDay, 23, 59, 59),
      );

      double totalVal = 0.0;
      double secondaryVal = 0.0;
      int count = items.length;

      if (_activeTab == "sales") {
        for (final item in items) {
          totalVal += _doubleFromVal(item['total']);
          secondaryVal += _doubleFromVal(item['profit']);
        }
      } else if (_activeTab == "suppliers") {
        for (final item in items) {
          totalVal += _doubleFromVal(item['total_cost']);
        }
      } else if (_activeTab == "cash") {
        for (final item in items) {
          final amount = _doubleFromVal(item['amount']);
          if (item['type'] == "IN") {
            totalVal += amount;
          } else {
            secondaryVal += amount;
          }
        }
      }

      compiled.add({
        "month": m,
        "year": year,
        "total": totalVal,
        "secondary": secondaryVal,
        "count": count,
      });
    }

    // Show only months in the current year up to this point
    return compiled.where((m) => m["month"] <= now.month).toList().reversed.toList();
  }

  List<Map<String, dynamic>> _compileYearlySummary() {
    final sourceList = _getActiveSourceList();
    
    final Set<int> years = {};
    for (final item in sourceList) {
      final dt = _parseReportDate(item);
      if (dt != null) {
        years.add(dt.year);
      }
    }
    
    if (years.isEmpty) {
      years.add(DateTime.now().year);
    }

    final List<Map<String, dynamic>> compiled = [];

    for (final y in years) {
      final items = _getItemsForDateRange(
        DateTime(y, 1, 1),
        DateTime(y, 12, 31, 23, 59, 59),
      );

      double totalVal = 0.0;
      double secondaryVal = 0.0;
      int count = items.length;

      if (_activeTab == "sales") {
        for (final item in items) {
          totalVal += _doubleFromVal(item['total']);
          secondaryVal += _doubleFromVal(item['profit']);
        }
      } else if (_activeTab == "suppliers") {
        for (final item in items) {
          totalVal += _doubleFromVal(item['total_cost']);
        }
      } else if (_activeTab == "cash") {
        for (final item in items) {
          final amount = _doubleFromVal(item['amount']);
          if (item['type'] == "IN") {
            totalVal += amount;
          } else {
            secondaryVal += amount;
          }
        }
      }

      compiled.add({
        "year": y,
        "total": totalVal,
        "secondary": secondaryVal,
        "count": count,
      });
    }

    compiled.sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));
    return compiled;
  }

  Map<String, List<Map<String, dynamic>>> _groupSupplierReportsBySupplier() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final report in _supplierReport) {
      final supplierName = report['supplier']?.toString() ?? 'Unknown Supplier';
      if (!grouped.containsKey(supplierName)) {
        grouped[supplierName] = [];
      }
      grouped[supplierName]!.add(report);
    }
    return grouped;
  }

  void _toggleSupplierExpanded(String supplierName) {
    setState(() {
      if (_expandedSuppliers.contains(supplierName)) {
        _expandedSuppliers.remove(supplierName);
      } else {
        _expandedSuppliers.add(supplierName);
      }
    });
  }

  // --- PDF Export Logic ---

  Future<void> _exportSupplierPDF(String supplierName, List<Map<String, dynamic>> records) async {
    final pdf = pw.Document();
    final title = "Supplier Purchasing Report - $supplierName";

    double grandTotal = 0.0;
    for (final r in records) {
      grandTotal += _doubleFromVal(r['total_cost']);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("NexPOS - $title", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Product", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Quantity", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Cost Price", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Date", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ...records.map((r) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r['product']?.toString() ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${r['quantity']} ${r['unit']}")),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${_doubleFromVal(r['total_cost']).toStringAsFixed(2)}")),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r['date']?.toString() ?? '')),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Purchases:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.Text(records.length.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Total Cost paid:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text("Report generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())} via NexPOS",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportDailyPDF() async {
    final pdf = pw.Document();
    final items = _getDailyRecords();
    final title = "${_activeTab.toUpperCase()} Daily Report - Last 24 Hours";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("NexPOS - $title", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: _activeTab == "sales"
                      ? [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Invoice ID", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Date & Time", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Customer", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Profit", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                            ],
                          ),
                          ...items.map((i) {
                            return pw.TableRow(
                              children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("#${i['id']}")),
                                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${i['date']} ${i['time']}")),
                                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${i['customer']}")),
                                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${_doubleFromVal(i['total']).toStringAsFixed(2)}")),
                                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${_doubleFromVal(i['profit']).toStringAsFixed(2)}")),
                              ],
                            );
                          }),
                        ]
                      : _activeTab == "suppliers"
                          ? [
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                                children: [
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Supplier", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Product", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Quantity", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Cost", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Date", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                ],
                              ),
                              ...items.map((i) {
                                return pw.TableRow(
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${i['supplier']}")),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${i['product']}")),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${i['quantity']} ${i['unit']}")),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${_doubleFromVal(i['total_cost']).toStringAsFixed(2)}")),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("${i['date']}")),
                                  ],
                                );
                              }),
                            ]
                          : [
                              pw.TableRow(
                                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                                children: [
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Type", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Purpose", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Time", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Balance After", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                                ],
                              ),
                              ...items.map((i) {
                                final timeStr = i['time']?.toString() ?? '';
                                final formattedTime = timeStr.isNotEmpty ? timeStr : DateFormat('h:mm a').format(_parseReportDate(i) ?? DateTime.now());
                                return pw.TableRow(
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i['type'].toString(), style: pw.TextStyle(color: i['type'] == "IN" ? PdfColors.green : PdfColors.red, fontWeight: pw.FontWeight.bold))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${_doubleFromVal(i['amount']).toStringAsFixed(2)}")),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(i['purpose'].toString())),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(formattedTime)),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${_doubleFromVal(i['balance_after']).toStringAsFixed(2)}")),
                                  ],
                                );
                              }),
                            ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text("Report generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())} via NexPOS",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportWeeklyPDF(Map<String, dynamic> weekData) async {
    final int weekNum = weekData["weekNum"];
    final int startDay = weekData["startDay"];
    final int endDay = weekData["endDay"];
    final int month = weekData["month"];
    final int year = weekData["year"];

    final pdf = pw.Document();
    final monthName = DateFormat('MMMM').format(DateTime(year, month, 1));
    final title = "${_activeTab.toUpperCase()} Weekly Report - Week $weekNum ($monthName $startDay - $endDay, $year)";

    final List<Map<String, dynamic>> dailyRows = [];
    double grandTotal = 0.0;
    double grandSecondary = 0.0;
    int grandCount = 0;

    for (int d = startDay; d <= endDay; d++) {
      final items = _getItemsForDateRange(
        DateTime(year, month, d),
        DateTime(year, month, d, 23, 59, 59),
      );

      double total = 0.0;
      double secondary = 0.0;
      int count = items.length;

      if (_activeTab == "sales") {
        for (final item in items) {
          total += _doubleFromVal(item['total']);
          secondary += _doubleFromVal(item['profit']);
        }
      } else if (_activeTab == "suppliers") {
        for (final item in items) {
          total += _doubleFromVal(item['total_cost']);
        }
      } else if (_activeTab == "cash") {
        for (final item in items) {
          final amt = _doubleFromVal(item['amount']);
          if (item['type'] == "IN") {
            total += amt;
          } else {
            secondary += amt;
          }
        }
      }

      grandTotal += total;
      grandSecondary += secondary;
      grandCount += count;

      dailyRows.add({
        "date": "$monthName $d, $year",
        "total": total,
        "secondary": secondary,
        "count": count,
      });
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("NexPOS - $title", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: _getTableHeaderCells(),
                    ),
                    ...dailyRows.map((row) {
                      return pw.TableRow(
                        children: _getTableCellWidgets(row),
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                _getPDFTotalsRow(grandTotal, grandSecondary, grandCount),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text("Report generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())} via NexPOS",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportMonthlyPDF(Map<String, dynamic> monthData) async {
    final int month = monthData["month"];
    final int year = monthData["year"];

    final pdf = pw.Document();
    final monthName = DateFormat('MMMM').format(DateTime(year, month, 1));
    final title = "${_activeTab.toUpperCase()} Monthly Report - $monthName $year";

    final lastDay = DateTime(year, month + 1, 0).day;
    final weeks = [
      {"weekNum": 1, "start": 1, "end": 7},
      {"weekNum": 2, "start": 8, "end": 14},
      {"weekNum": 3, "start": 15, "end": 21},
      {"weekNum": 4, "start": 22, "end": lastDay},
    ];

    final List<Map<String, dynamic>> weeklyRows = [];
    double grandTotal = 0.0;
    double grandSecondary = 0.0;
    int grandCount = 0;

    for (final w in weeks) {
      final startDay = w["start"] as int;
      final endDay = w["end"] as int;
      final weekNum = w["weekNum"] as int;

      final items = _getItemsForDateRange(
        DateTime(year, month, startDay),
        DateTime(year, month, endDay, 23, 59, 59),
      );

      double total = 0.0;
      double secondary = 0.0;
      int count = items.length;

      if (_activeTab == "sales") {
        for (final item in items) {
          total += _doubleFromVal(item['total']);
          secondary += _doubleFromVal(item['profit']);
        }
      } else if (_activeTab == "suppliers") {
        for (final item in items) {
          total += _doubleFromVal(item['total_cost']);
        }
      } else if (_activeTab == "cash") {
        for (final item in items) {
          final amt = _doubleFromVal(item['amount']);
          if (item['type'] == "IN") {
            total += amt;
          } else {
            secondary += amt;
          }
        }
      }

      grandTotal += total;
      grandSecondary += secondary;
      grandCount += count;

      weeklyRows.add({
        "date": "Week $weekNum ($monthName $startDay-$endDay)",
        "total": total,
        "secondary": secondary,
        "count": count,
      });
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("NexPOS - $title", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: _getTableHeaderCells(),
                    ),
                    ...weeklyRows.map((row) {
                      return pw.TableRow(
                        children: _getTableCellWidgets(row),
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                _getPDFTotalsRow(grandTotal, grandSecondary, grandCount),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text("Report generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())} via NexPOS",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportYearlyPDF(Map<String, dynamic> yearData) async {
    final int year = yearData["year"];

    final pdf = pw.Document();
    final title = "${_activeTab.toUpperCase()} Yearly Report - Year $year";

    final List<Map<String, dynamic>> monthlyRows = [];
    double grandTotal = 0.0;
    double grandSecondary = 0.0;
    int grandCount = 0;

    for (int m = 1; m <= 12; m++) {
      final lastDay = DateTime(year, m + 1, 0).day;
      final items = _getItemsForDateRange(
        DateTime(year, m, 1),
        DateTime(year, m, lastDay, 23, 59, 59),
      );

      double total = 0.0;
      double secondary = 0.0;
      int count = items.length;

      if (_activeTab == "sales") {
        for (final item in items) {
          total += _doubleFromVal(item['total']);
          secondary += _doubleFromVal(item['profit']);
        }
      } else if (_activeTab == "suppliers") {
        for (final item in items) {
          total += _doubleFromVal(item['total_cost']);
        }
      } else if (_activeTab == "cash") {
        for (final item in items) {
          final amt = _doubleFromVal(item['amount']);
          if (item['type'] == "IN") {
            total += amt;
          } else {
            secondary += amt;
          }
        }
      }

      grandTotal += total;
      grandSecondary += secondary;
      grandCount += count;

      monthlyRows.add({
        "date": DateFormat('MMMM').format(DateTime(year, m, 1)),
        "total": total,
        "secondary": secondary,
        "count": count,
      });
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("NexPOS - $title", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: _getTableHeaderCells(),
                    ),
                    ...monthlyRows.map((row) {
                      return pw.TableRow(
                        children: _getTableCellWidgets(row),
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                _getPDFTotalsRow(grandTotal, grandSecondary, grandCount),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text("Report generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())} via NexPOS",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  List<pw.Widget> _getTableHeaderCells() {
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final padding = const pw.EdgeInsets.all(6);
    
    if (_activeTab == "sales") {
      return [
        pw.Padding(padding: padding, child: pw.Text("Date/Timeframe", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Orders", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Profit", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Sales Volume", style: bold)),
      ];
    } else if (_activeTab == "suppliers") {
      return [
        pw.Padding(padding: padding, child: pw.Text("Date/Timeframe", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Purchases Count", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Total Cost", style: bold)),
      ];
    } else { // cash
      return [
        pw.Padding(padding: padding, child: pw.Text("Date/Timeframe", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Cash Deposited (In)", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Cash Withdrawn (Out)", style: bold)),
        pw.Padding(padding: padding, child: pw.Text("Net Cash Flow", style: bold)),
      ];
    }
  }

  List<pw.Widget> _getTableCellWidgets(Map<String, dynamic> row) {
    final padding = const pw.EdgeInsets.all(6);
    final dateText = row['date'].toString();
    
    if (_activeTab == "sales") {
      return [
        pw.Padding(padding: padding, child: pw.Text(dateText)),
        pw.Padding(padding: padding, child: pw.Text(row['count'].toString())),
        pw.Padding(padding: padding, child: pw.Text("Rs. ${(row['secondary'] as double).toStringAsFixed(2)}")),
        pw.Padding(padding: padding, child: pw.Text("Rs. ${(row['total'] as double).toStringAsFixed(2)}")),
      ];
    } else if (_activeTab == "suppliers") {
      return [
        pw.Padding(padding: padding, child: pw.Text(dateText)),
        pw.Padding(padding: padding, child: pw.Text(row['count'].toString())),
        pw.Padding(padding: padding, child: pw.Text("Rs. ${(row['total'] as double).toStringAsFixed(2)}")),
      ];
    } else { // cash
      final net = (row['total'] as double) - (row['secondary'] as double);
      return [
        pw.Padding(padding: padding, child: pw.Text(dateText)),
        pw.Padding(padding: padding, child: pw.Text("Rs. ${(row['total'] as double).toStringAsFixed(2)}")),
        pw.Padding(padding: padding, child: pw.Text("Rs. ${(row['secondary'] as double).toStringAsFixed(2)}")),
        pw.Padding(padding: padding, child: pw.Text("${net >= 0 ? '+' : ''}Rs. ${net.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: net >= 0 ? PdfColors.green : PdfColors.red))),
      ];
    }
  }

  pw.Widget _getPDFTotalsRow(double grandTotal, double grandSecondary, int grandCount) {
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13);
    
    if (_activeTab == "sales") {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Orders:", style: bold), pw.Text(grandCount.toString(), style: bold)]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Profit:", style: bold), pw.Text("Rs. ${grandSecondary.toStringAsFixed(2)}", style: bold)]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Sales Volume:", style: bold), pw.Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: bold)]),
        ],
      );
    } else if (_activeTab == "suppliers") {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Purchases:", style: bold), pw.Text(grandCount.toString(), style: bold)]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Cost paid:", style: bold), pw.Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: bold)]),
        ],
      );
    } else { // cash
      final net = grandTotal - grandSecondary;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Cash Deposited (In):", style: bold), pw.Text("Rs. ${grandTotal.toStringAsFixed(2)}", style: bold)]),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Cash Withdrawn (Out):", style: bold), pw.Text("Rs. ${grandSecondary.toStringAsFixed(2)}", style: bold)]),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Net Cash Flow:", style: bold), pw.Text("${net >= 0 ? '+' : ''}Rs. ${net.toStringAsFixed(2)}", style: bold)]),
        ],
      );
    }
  }

  // Export Individual Sale/Supply invoice
  Future<void> _exportIndividualPDF(Map<String, dynamic> item, String type) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          if (type == "sale") {
            List<dynamic> itemsList = [];
            if (item['items'] != null) {
              if (item['items'] is String) {
                itemsList = jsonDecode(item['items']);
              } else {
                itemsList = item['items'] as List<dynamic>;
              }
            }

            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: pw.Text("NexPOS - Invoice Details", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 16),
                  pw.Text("Invoice ID: #${item['id']}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Date: ${item['date']} ${item['time']}"),
                  pw.Text("Customer Name: ${item['customer']}"),
                  pw.Text("Phone Number: ${item['customer_phone'] ?? 'N/A'}"),
                  pw.SizedBox(height: 20),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Item Name", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Quantity", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Unit Price", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      ...itemsList.map((it) {
                        final price = _doubleFromVal(it['price']);
                        final qty = _doubleFromVal(it['quantity']) == 0.0 ? 1.0 : _doubleFromVal(it['quantity']);
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['name']?.toString() ?? '')),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(qty.toStringAsFixed(0))),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${price.toStringAsFixed(2)}")),
                            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${(price * qty).toStringAsFixed(2)}")),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Subtotal:"), pw.Text("Rs. ${_doubleFromVal(item['subtotal']).toStringAsFixed(2)}")]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Discount:"), pw.Text("Rs. ${_doubleFromVal(item['discount_amount']).toStringAsFixed(2)}")]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Tax:"), pw.Text("Rs. ${_doubleFromVal(item['tax']).toStringAsFixed(2)}")]),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Amount:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${_doubleFromVal(item['total']).toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                ],
              ),
            );
          } else {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: pw.Text("NexPOS - Supply Report", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 16),
                  pw.Text("Supplier: ${item['supplier']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Product Name: ${item['product']}"),
                  pw.Text("Quantity Received: ${item['quantity']} ${item['unit']}"),
                  pw.Text("Cost Price: Rs. ${_doubleFromVal(item['cost_per_unit']).toStringAsFixed(2)}"),
                  pw.Text("Sale Price Set: Rs. ${_doubleFromVal(item['sale_per_unit']).toStringAsFixed(2)}"),
                  pw.Divider(),
                  pw.Text("Total Cost paid: Rs. ${_doubleFromVal(item['total_cost']).toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text("Purchase Date: ${item['date']}"),
                ],
              ),
            );
          }
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- UI Widget Builders ---

  Widget _buildTabButton(String tab, String label) {
    final active = _activeTab == tab;
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final activeColor = tab == "sales" 
        ? theme.primaryColor 
        : (tab == "suppliers" ? const Color(0xFF8B5CF6) : const Color(0xFF10B981));
        
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: active ? activeColor : theme.cardColor.withValues(alpha: 0.6),
            foregroundColor: active ? Colors.white : textPrimary,
            side: BorderSide(color: active ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
          onPressed: () => setState(() => _activeTab = tab),
          child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildTimeframeChip(String timeframe, String label) {
    final active = _timeframe == timeframe;
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: theme.primaryColor,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: active ? theme.colorScheme.onPrimary : textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _timeframe = timeframe;
          });
        }
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color, Color textSecondary) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.plusJakartaSans(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  List<Widget> _buildTodayStats(Color blue, Color green, Color orange, Color textSecondary) {
    final provider = Provider.of<POSProvider>(context, listen: false);
    
    if (_activeTab == "sales") {
      return [
        _buildStatItem("Sales Volume", "Rs. ${_todaySales.toStringAsFixed(0)}", blue, textSecondary),
        _buildStatItem("Total Profit", "Rs. ${_todayProfit.toStringAsFixed(0)}", green, textSecondary),
        _buildStatItem("Total Orders", _todayOrders.toString(), orange, textSecondary),
      ];
    } else if (_activeTab == "suppliers") {
      return [
        _buildStatItem("Purchasing Cost", "Rs. ${_todaySupplierCost.toStringAsFixed(0)}", orange, textSecondary),
        _buildStatItem("Total Purchases", _todaySupplierPurchases.toString(), blue, textSecondary),
        _buildStatItem("Active Suppliers", provider.suppliers.length.toString(), green, textSecondary),
      ];
    } else { // cash
      return [
        _buildStatItem("Total Cash In", "Rs. ${_todayCashIn.toStringAsFixed(0)}", green, textSecondary),
        _buildStatItem("Total Cash Out", "Rs. ${_todayCashOut.toStringAsFixed(0)}", const Color(0xFFEF4444), textSecondary),
        _buildStatItem("Drawer Cash", "Rs. ${provider.cashBalance.toStringAsFixed(0)}", blue, textSecondary),
      ];
    }
  }

  Widget _buildDailyCashItem(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final border = theme.dividerColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    
    final isCashIn = item['type'] == "IN";
    final green = const Color(0xFF10B981);
    final red = theme.colorScheme.error;
    final indicatorColor = isCashIn ? green : red;
    
    final timeStr = item['time']?.toString() ?? '';
    final formattedTime = timeStr.isNotEmpty ? timeStr : DateFormat('h:mm a').format(_parseReportDate(item) ?? DateTime.now());
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: indicatorColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCashIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: indicatorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCashIn ? "Cash Deposited" : "Cash Withdrawn",
                            style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${item['purpose']} • $formattedTime",
                            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${isCashIn ? '+' : '-'} Rs. ${_doubleFromVal(item['amount']).toStringAsFixed(2)}",
                        style: GoogleFonts.plusJakartaSans(color: indicatorColor, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Bal: Rs. ${_doubleFromVal(item['balance_after']).toStringAsFixed(0)}",
                        style: GoogleFonts.inter(color: textSecondary, fontSize: 10),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompiledCard(Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final border = theme.dividerColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    
    final activeColor = _activeTab == "sales" 
        ? const Color(0xFF10B981)
        : (_activeTab == "suppliers" ? const Color(0xFFF59E0B) : theme.primaryColor);

    String title = "";
    String subtitle = "";
    String amountText = "";

    if (_timeframe == "weekly") {
      final weekNum = data["weekNum"];
      final startDay = data["startDay"];
      final endDay = data["endDay"];
      final monthName = DateFormat('MMM').format(DateTime(data["year"], data["month"], 1));
      
      title = "Week $weekNum ($monthName $startDay - $endDay)";
      
      if (_activeTab == "sales") {
        subtitle = "Orders: ${data['count']} • Profit: Rs. ${(data['secondary'] as double).toStringAsFixed(0)}";
        amountText = "Rs. ${(data['total'] as double).toStringAsFixed(0)}";
      } else if (_activeTab == "suppliers") {
        subtitle = "Purchases: ${data['count']}";
        amountText = "Rs. ${(data['total'] as double).toStringAsFixed(0)}";
      } else if (_activeTab == "cash") {
        subtitle = "In: Rs. ${(data['total'] as double).toStringAsFixed(0)} • Out: Rs. ${(data['secondary'] as double).toStringAsFixed(0)}";
        final net = (data['total'] as double) - (data['secondary'] as double);
        amountText = "${net >= 0 ? '+' : ''}Rs. ${net.toStringAsFixed(0)}";
      }
    } else if (_timeframe == "monthly") {
      final monthName = DateFormat('MMMM yyyy').format(DateTime(data["year"], data["month"], 1));
      title = monthName;
      
      if (_activeTab == "sales") {
        subtitle = "Orders: ${data['count']} • Profit: Rs. ${(data['secondary'] as double).toStringAsFixed(0)}";
        amountText = "Rs. ${(data['total'] as double).toStringAsFixed(0)}";
      } else if (_activeTab == "suppliers") {
        subtitle = "Purchases: ${data['count']}";
        amountText = "Rs. ${(data['total'] as double).toStringAsFixed(0)}";
      } else if (_activeTab == "cash") {
        subtitle = "In: Rs. ${(data['total'] as double).toStringAsFixed(0)} • Out: Rs. ${(data['secondary'] as double).toStringAsFixed(0)}";
        final net = (data['total'] as double) - (data['secondary'] as double);
        amountText = "${net >= 0 ? '+' : ''}Rs. ${net.toStringAsFixed(0)}";
      }
    } else if (_timeframe == "yearly") {
      title = "Year ${data['year']}";
      
      if (_activeTab == "sales") {
        subtitle = "Orders: ${data['count']} • Profit: Rs. ${(data['secondary'] as double).toStringAsFixed(0)}";
        amountText = "Rs. ${(data['total'] as double).toStringAsFixed(0)}";
      } else if (_activeTab == "suppliers") {
        subtitle = "Purchases: ${data['count']}";
        amountText = "Rs. ${(data['total'] as double).toStringAsFixed(0)}";
      } else if (_activeTab == "cash") {
        subtitle = "In: Rs. ${(data['total'] as double).toStringAsFixed(0)} • Out: Rs. ${(data['secondary'] as double).toStringAsFixed(0)}";
        final net = (data['total'] as double) - (data['secondary'] as double);
        amountText = "${net >= 0 ? '+' : ''}Rs. ${net.toStringAsFixed(0)}";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: activeColor),
            ),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              title: Text(
                title,
                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      amountText,
                      style: GoogleFonts.inter(
                        color: activeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  ],
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.download_for_offline_outlined, color: theme.primaryColor, size: 24),
                onPressed: () {
                  if (_timeframe == "weekly") {
                    _exportWeeklyPDF(data);
                  } else if (_timeframe == "monthly") {
                    _exportMonthlyPDF(data);
                  } else if (_timeframe == "yearly") {
                    _exportYearlyPDF(data);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierNameCard(String supplierName, List<Map<String, dynamic>> records) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final purple = const Color(0xFF8B5CF6);
    final isExpanded = _expandedSuppliers.contains(supplierName);

    double totalCost = records.fold(0.0, (sum, r) => sum + _doubleFromVal(r['total_cost']));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Supplier Card Header
            InkWell(
              onTap: () => _toggleSupplierExpanded(supplierName),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: theme.cardColor.withValues(alpha: 0.6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_shipping_rounded, color: purple, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplierName,
                            style: GoogleFonts.plusJakartaSans(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${records.length} purchases • Rs. ${totalCost.toStringAsFixed(0)}",
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.download_for_offline_outlined, color: theme.primaryColor, size: 24),
                      onPressed: () => _exportSupplierPDF(supplierName, records),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            // Supplier Card Body (Expanded Purchases list)
            if (isExpanded)
              Container(
                color: theme.brightness == Brightness.dark 
                    ? Colors.black.withValues(alpha: 0.2) 
                    : Colors.black.withValues(alpha: 0.02),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: records.map((rec) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rec['product']?.toString() ?? '',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Qty: ${rec['quantity']} ${rec['unit']} • Date: ${rec['date']}",
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Rs. ${_doubleFromVal(rec['total_cost']).toStringAsFixed(0)}",
                            style: GoogleFonts.inter(
                              color: purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.download_outlined, color: theme.primaryColor, size: 20),
                            onPressed: () => _exportIndividualPDF(rec, "supplier"),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList(ThemeData theme, Color cardColor, Color border, Color textPrimary, Color textSecondary, Color green, Color orange, Color blue) {
    if (_activeTab == "suppliers") {
      final grouped = _groupSupplierReportsBySupplier();
      if (grouped.isEmpty) {
        return Center(
          child: Text("No records found", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14)),
        );
      }
      final supplierNames = grouped.keys.toList();
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: supplierNames.length,
        itemBuilder: (ctx, idx) {
          final sName = supplierNames[idx];
          return _buildSupplierNameCard(sName, grouped[sName]!);
        },
      );
    }

    if (_timeframe == "daily") {
      final items = _getDailyRecords();
      if (items.isEmpty) {
        return Center(
          child: Text("No records in the last 24 hours", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14)),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, idx) {
          final item = items[idx];
          
          if (_activeTab == "sales") {
            final itemColor = green;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(color: itemColor),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      title: Text(
                        "Invoice #${item['id']}",
                        style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Customer: ${item['customer']} • Date: ${item['date']}",
                              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Total: Rs. ${item['total']} (Profit: Rs. ${item['profit']})",
                              style: GoogleFonts.inter(
                                color: itemColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.download_outlined, color: blue, size: 22),
                        onPressed: () => _exportIndividualPDF(item, "sale"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else { // cash
            return _buildDailyCashItem(item);
          }
        },
      );
    } else {
      // Compiled views (weekly, monthly, yearly)
      List<Map<String, dynamic>> compiledItems = [];
      if (_timeframe == "weekly") {
        compiledItems = _compileWeeklySummary();
      } else if (_timeframe == "monthly") {
        compiledItems = _compileMonthlySummary();
      } else if (_timeframe == "yearly") {
        compiledItems = _compileYearlySummary();
      }
      
      if (compiledItems.isEmpty) {
        return Center(
          child: Text("No records found", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14)),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: compiledItems.length,
        itemBuilder: (ctx, idx) {
          final item = compiledItems[idx];
          return _buildCompiledCard(item);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final green = const Color(0xFF10B981);
    final blue = theme.primaryColor;
    final orange = const Color(0xFFF59E0B);

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
          "Reports",
          style: GoogleFonts.plusJakartaSans(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: blue))
              : Column(
                  children: [
                    // Dynamic Performance card wrapped in PremiumGlassCard
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: PremiumGlassCard(
                        blur: 20,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Summary", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: _buildTodayStats(blue, green, orange, textSecondary),
                            )
                          ],
                        ),
                      ),
                    ),

                    // Tab Toggles
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildTabButton("sales", "Sales"),
                          const SizedBox(width: 8),
                          _buildTabButton("suppliers", "Suppliers"),
                          const SizedBox(width: 8),
                          _buildTabButton("cash", "Cash Ledger"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timeframe chips (hidden if Suppliers tab is active)
                    if (_activeTab != "suppliers")
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTimeframeChip("daily", "Daily"),
                              const SizedBox(width: 8),
                              _buildTimeframeChip("weekly", "Weekly"),
                              const SizedBox(width: 8),
                              _buildTimeframeChip("monthly", "Monthly"),
                              const SizedBox(width: 8),
                              _buildTimeframeChip("yearly", "Yearly"),
                            ],
                          ),
                        ),
                      ),
                    if (_activeTab != "suppliers") const SizedBox(height: 16),

                    // PDF export action (only shown in Daily view and when not in suppliers)
                    if (_timeframe == "daily" && _activeTab != "suppliers")
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_for_offline_rounded, size: 18, color: Colors.white),
                          label: Text(
                            "EXPORT 24H ${_activeTab.toUpperCase()} PDF", 
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _exportDailyPDF,
                        ),
                      ),
                    if (_timeframe == "daily" && _activeTab != "suppliers") const SizedBox(height: 16),

                    // Records list
                    Expanded(
                      child: _buildRecordsList(theme, theme.cardColor, border, textPrimary, textSecondary, green, orange, blue),
                    )
                  ],
                ),
        ),
      ),
    );
  }
}
