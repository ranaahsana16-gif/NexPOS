import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../providers/pos_provider.dart';
import '../models/models.dart';
import '../widgets/premium_background.dart';
import '../services/printer_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _customerNameController = TextEditingController(text: "Walk-in Customer");
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _discountController = TextEditingController(text: "0");
  final _taxController = TextEditingController(text: "0");
  final _cashReceivedController = TextEditingController();

  String _paymentMethod = "Cash";
  Customer? _selectedCustomer;
  bool _loading = false;
  bool _customerProfileExpanded = false;

  final Map<String, String> _shopInfo = {
    'name': "NexPOS",
    'tagline1': "pos apps",
    'address': "Main bazar",
    'phone': "0339-5121676",
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<POSProvider>(context, listen: false);
    _taxController.text = provider.taxRate.toStringAsFixed(0);
    _discountController.text = provider.defaultDiscount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _customerPhoneController.text = customer.phone;
      _customerAddressController.text = customer.address ?? "";
      _customerProfileExpanded = true;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.text = "Walk-in Customer";
      _customerPhoneController.text = "";
      _customerAddressController.text = "";
      _customerProfileExpanded = false;
    });
  }

  Future<void> _openJazzCash() async {
    final Uri jazzUrl = Uri.parse("jazzcash://");
    final Uri fallbackUrl = Uri.parse("https://www.jazzcash.com.pk/");
    try {
      if (await canLaunchUrl(jazzUrl)) {
        await launchUrl(jazzUrl);
      } else {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorDialog("Could not launch JazzCash. Please open the app manually.");
    }
  }

  // PDF Printing Logic
  Future<pw.Document> _generatePdf(POSProvider provider, double subtotal, double discountAmt, double taxAmt, double totalAmt, double cashRec, double change) async {
    final pdf = pw.Document();
    final invoiceId = "${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}${DateTime.now().second.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text(_shopInfo['name']!, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                pw.Center(child: pw.Text(_shopInfo['tagline1']!, style: const pw.TextStyle(fontSize: 8))),
                pw.Center(child: pw.Text(_shopInfo['address']!, style: const pw.TextStyle(fontSize: 8))),
                pw.Center(child: pw.Text("Tel: ${_shopInfo['phone']}", style: const pw.TextStyle(fontSize: 8))),
                pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),

                pw.Text("Invoice: #$invoiceId", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text("Date: ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute}", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Customer: ${_customerNameController.text}", style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),

                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    ...provider.cart.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 7)),
                          pw.Text("x${item.quantity.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 7)),
                          pw.Text("Rs.${item.subtotal.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right),
                        ],
                      );
                    }),
                  ],
                ),
                pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),

                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Subtotal:", style: const pw.TextStyle(fontSize: 8)), pw.Text("Rs. ${subtotal.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8))]),
                if (discountAmt > 0)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Discount (${_discountController.text}%):", style: const pw.TextStyle(fontSize: 8)), pw.Text("-Rs. ${discountAmt.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8))]),
                if (taxAmt > 0)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Tax (${_taxController.text}%):", style: const pw.TextStyle(fontSize: 8)), pw.Text("+Rs. ${taxAmt.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8))]),
                pw.Divider(borderStyle: pw.BorderStyle.solid, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TOTAL:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${totalAmt.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))]),

                pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Payment Method:", style: const pw.TextStyle(fontSize: 8)), pw.Text(_paymentMethod, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))]),
                if (_paymentMethod == "Cash") ...[
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Cash Received:", style: const pw.TextStyle(fontSize: 8)), pw.Text("Rs. ${cashRec.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8))]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Change Due:", style: const pw.TextStyle(fontSize: 8)), pw.Text("Rs. ${change.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8))]),
                ],

                pw.SizedBox(height: 10),
                pw.Center(child: pw.Text("THANK YOU FOR SHOPPING", style: const pw.TextStyle(fontSize: 8))),
                pw.Center(child: pw.Text("Powered by NexPOS", style: const pw.TextStyle(fontSize: 7))),
              ],
            ),
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> _handlePrint(POSProvider provider, double subtotal, double discountAmt, double taxAmt, double totalAmt, double cashRec, double change) async {
    if (provider.directPrintEnabled) {
      final discountVal = double.tryParse(_discountController.text) ?? 0.0;
      final taxVal = double.tryParse(_taxController.text) ?? 0.0;
      
      final success = await PrinterService().printReceipt(
        shopName: _shopInfo['name'] ?? "NexPOS",
        tagline: _shopInfo['tagline1'] ?? "",
        address: _shopInfo['address'] ?? "",
        phone: _shopInfo['phone'] ?? "",
        cartItems: provider.cart,
        subtotal: subtotal,
        discountPercentage: discountVal,
        discountAmt: discountAmt,
        taxRate: taxVal,
        taxAmt: taxAmt,
        total: totalAmt,
        paymentMethod: _paymentMethod,
        cashReceived: cashRec,
        changeDue: change,
        pricingMode: provider.pricingMode,
        weightSymbol: provider.weightSymbol,
        paperWidth: provider.paperWidth,
        customerName: _customerNameController.text.isNotEmpty && _customerNameController.text != "Walk-in Customer"
            ? _customerNameController.text
            : null,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Receipt printed directly via ${provider.printerType.toUpperCase()}."),
            backgroundColor: Colors.green,
          ),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Direct print failed. Falling back to system print dialog..."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    try {
      final doc = await _generatePdf(provider, subtotal, discountAmt, taxAmt, totalAmt, cashRec, change);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Printing failed: $e");
    }
  }

  Future<void> _handleShare(POSProvider provider, double subtotal, double discountAmt, double taxAmt, double totalAmt, double cashRec, double change) async {
    try {
      final doc = await _generatePdf(provider, subtotal, discountAmt, taxAmt, totalAmt, cashRec, change);
      await Printing.sharePdf(bytes: await doc.save(), filename: 'nexpos-receipt.pdf');
    } catch (e) {
      _showErrorDialog("Sharing failed: $e");
    }
  }

  List<double> _getQuickCashKeys(double total) {
    final List<double> keys = [];
    final exact = total.ceilToDouble();
    keys.add(exact);

    void addKey(double val) {
      if (val > exact && !keys.contains(val)) {
        keys.add(val);
      }
    }

    // Next nearest multiples
    addKey(((exact + 9) ~/ 10) * 10.0);
    addKey(((exact + 49) ~/ 50) * 50.0);
    addKey(((exact + 99) ~/ 100) * 100.0);
    addKey(((exact + 499) ~/ 500) * 500.0);

    // Common denominations
    for (final denom in [100.0, 500.0, 1000.0, 2000.0, 5000.0]) {
      addKey(denom);
    }

    final exactVal = keys.removeAt(0);
    keys.sort();
    return [exactVal, ...keys];
  }

  Future<void> _handleCompleteSale(POSProvider provider, double discountVal, double discountAmt, double taxVal, double taxAmt, double totalAmt, double cashRec, double change) async {
    if (provider.cart.isEmpty) return;

    if (_paymentMethod == "Cash") {
      if (_cashReceivedController.text.trim().isEmpty) {
        _showErrorDialog("Cash Received amount is required for Cash payments.");
        return;
      }
      if (cashRec < totalAmt) {
        _showErrorDialog("Cash received (Rs. ${cashRec.toStringAsFixed(2)}) is less than total amount (Rs. ${totalAmt.toStringAsFixed(2)})");
        return;
      }
    }

    if (_paymentMethod == "Credit") {
      if (_selectedCustomer == null || _customerNameController.text == "Walk-in Customer") {
        _showErrorDialog("A registered customer must be selected to checkout via Credit (Khata).");
        return;
      }
    }

    setState(() {
      _loading = true;
    });

    try {
      await provider.completeSale(
        customerName: _customerNameController.text,
        customerPhone: _customerPhoneController.text.isNotEmpty ? _customerPhoneController.text : null,
        customerAddress: _customerAddressController.text.isNotEmpty ? _customerAddressController.text : null,
        selectedCustomer: _selectedCustomer,
        discountPercentage: discountVal,
        discountAmt: discountAmt,
        taxRateVal: taxVal,
        taxAmt: taxAmt,
        totalAmt: totalAmt,
        paymentMethod: _paymentMethod,
        cashReceived: _paymentMethod == 'Cash' ? cashRec : totalAmt,
        changeDueAmount: _paymentMethod == 'Cash' ? change : 0.0,
      );

      if (mounted) {
        final successTheme = Theme.of(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: successTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Success", style: GoogleFonts.plusJakartaSans(color: successTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: Text("Sale completed successfully!", style: GoogleFonts.plusJakartaSans(color: successTheme.colorScheme.onSurfaceVariant)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                child: Text("OK", style: GoogleFonts.plusJakartaSans(color: successTheme.primaryColor, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorDialog("Failed to complete sale: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showErrorDialog(String msg) {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Error", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text(msg, style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.error, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showTransferQRModal(double totalAmount, POSProvider provider, double discountVal, double discountAmt, double taxVal, double taxAmt, double cashRec, double change) {
    final modalTheme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Scan to Pay", style: GoogleFonts.plusJakartaSans(color: modalTheme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Amount to Transfer", style: GoogleFonts.plusJakartaSans(color: modalTheme.colorScheme.onSurfaceVariant, fontSize: 13)),
              Text(
                "Rs. ${totalAmount.toStringAsFixed(2)}",
                style: GoogleFonts.plusJakartaSans(color: modalTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),

              // QR Code
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/qr.png',
                  height: 220,
                  width: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Scan using JazzCash or any compatible app",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: modalTheme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC00),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openJazzCash,
                      child: Text("Open JazzCash", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleCompleteSale(provider, discountVal, discountAmt, taxVal, taxAmt, totalAmount, cashRec, change);
                      },
                      child: Text("Done", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showCustomerSelectionDialog(POSProvider provider) {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Select Customer", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline, color: dialogTheme.colorScheme.onSurface),
                  title: Text("Walk-in Customer", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface)),
                  onTap: () {
                    _clearCustomer();
                    Navigator.pop(ctx);
                  },
                ),
                Divider(color: dialogTheme.dividerColor),
                Expanded(
                  child: provider.customers.isEmpty
                      ? Center(child: Text("No customers found", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          itemCount: provider.customers.length,
                          itemBuilder: (context, index) {
                            final cust = provider.customers[index];
                            return ListTile(
                              title: Text(cust.name, style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                              subtitle: Text(cust.phone, style: GoogleFonts.inter(color: dialogTheme.colorScheme.onSurfaceVariant)),
                              onTap: () {
                                _selectCustomer(cust);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);


    // Theme values
    final bg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final inputColor = theme.colorScheme.surfaceContainerHighest;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final positive = const Color(0xFF10B981);
    final accent = theme.primaryColor;

    // Calculations
    final subtotal = provider.cartTotal;
    final discountVal = double.tryParse(_discountController.text) ?? 0.0;
    final discountAmt = (subtotal * discountVal) / 100;
    final taxable = subtotal - discountAmt;
    final taxVal = double.tryParse(_taxController.text) ?? 0.0;
    final taxAmt = taxable * (taxVal / 100);
    final totalAmt = taxable + taxAmt;
    final cashRec = double.tryParse(_cashReceivedController.text) ?? 0.0;
    final change = (_paymentMethod == "Cash" && cashRec > totalAmt) ? cashRec - totalAmt : 0.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
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
          "Terminal Checkout",
          style: GoogleFonts.plusJakartaSans(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              // Customer selection card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _customerProfileExpanded = !_customerProfileExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _customerProfileExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                                color: textPrimary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Customer Profile",
                                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_customerProfileExpanded) ...[
                                Text(
                                  _customerNameController.text.isNotEmpty ? _customerNameController.text : "Walk-in Customer",
                                  style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person_search_rounded, size: 14, color: Colors.white),
                                label: Text("Select", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  _showCustomerSelectionDialog(provider);
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    if (_customerProfileExpanded) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _customerNameController,
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Customer Name",
                          hintStyle: GoogleFonts.inter(color: textSecondary),
                          filled: true,
                          fillColor: inputColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: textSecondary, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customerPhoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Phone (optional)",
                          hintStyle: GoogleFonts.inter(color: textSecondary),
                          filled: true,
                          fillColor: inputColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                          prefixIcon: Icon(Icons.phone_outlined, color: textSecondary, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customerAddressController,
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Address (optional)",
                          hintStyle: GoogleFonts.inter(color: textSecondary),
                          filled: true,
                          fillColor: inputColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                          prefixIcon: Icon(Icons.location_on_outlined, color: textSecondary, size: 18),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tax + Discount Inputs
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Discount %", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputColor,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tax %", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _taxController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputColor,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Cart item details
              Text("Cart Summary", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.cart.length,
                itemBuilder: (context, index) {
                  final item = provider.cart[index];
                  final formattedQty = item.product.pricingMode == 'weight'
                      ? item.quantity.toStringAsFixed(1)
                      : item.quantity.toStringAsFixed(0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text("Rs. ${item.product.salePrice.toStringAsFixed(0)} × $formattedQty", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text("Rs. ${item.subtotal.toStringAsFixed(0)}", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Totals Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildRow("Subtotal", "Rs. ${subtotal.toStringAsFixed(2)}", textPrimary, textSecondary),
                    if (discountAmt > 0) ...[
                      const SizedBox(height: 10),
                      _buildRow("Discount", "- Rs. ${discountAmt.toStringAsFixed(2)}", textPrimary, textSecondary),
                    ],
                    if (taxAmt > 0) ...[
                      const SizedBox(height: 10),
                      _buildRow("Tax", "Rs. ${taxAmt.toStringAsFixed(2)}", textPrimary, textSecondary),
                    ],
                    const Divider(height: 24, color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total Amount", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
                        Text(
                          "Rs. ${totalAmt.toStringAsFixed(2)}",
                          style: GoogleFonts.plusJakartaSans(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    if (_paymentMethod == "Cash" && change > 0) ...[
                      const Divider(height: 24, color: Colors.grey),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Change Due", style: GoogleFonts.plusJakartaSans(color: positive, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text("Rs. ${change.toStringAsFixed(2)}", style: GoogleFonts.plusJakartaSans(color: positive, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment Methods
              Text("Payment Method", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ["Cash", "Card", "Transfer", "Credit"].map((m) {
                  final active = _paymentMethod == m;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: active ? accent : cardColor,
                          foregroundColor: active ? theme.colorScheme.onPrimary : textPrimary,
                          side: BorderSide(color: active ? Colors.transparent : border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _paymentMethod = m;
                          });
                        },
                        child: Text(m, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              if (_paymentMethod == "Credit" && _selectedCustomer != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Outstanding Credit Balance",
                            style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Rs. ${_selectedCustomer!.creditBalance.toStringAsFixed(0)}",
                            style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Icon(Icons.account_balance_wallet_rounded, color: accent),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Cash Received Input if cash
              if (_paymentMethod == "Cash") ...[
                TextField(
                  controller: _cashReceivedController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Cash Received",
                    hintStyle: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.normal),
                    filled: true,
                    fillColor: inputColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                    prefixIcon: Icon(Icons.payments_outlined, color: textSecondary, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _getQuickCashKeys(totalAmt).map((val) {
                      final label = val == totalAmt ? "Exact (Rs. ${val.toStringAsFixed(0)})" : "Rs. ${val.toStringAsFixed(0)}";
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: accent.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () {
                            setState(() {
                              _cashReceivedController.text = val.toStringAsFixed(0);
                            });
                          },
                          child: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions - Print and Share Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: Text("Print Receipt", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handlePrint(provider, subtotal, discountAmt, taxAmt, totalAmt, cashRec, change),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text("Share PDF", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleShare(provider, subtotal, discountAmt, taxAmt, totalAmt, cashRec, change),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Checkout Button
              Container(
                decoration: BoxDecoration(
                  gradient: _loading 
                      ? null 
                      : LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.85)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  color: _loading ? Colors.grey : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _loading
                      ? null
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _loading
                      ? null
                      : () {
                          if (_paymentMethod == "Transfer") {
                            _showTransferQRModal(totalAmt, provider, discountVal, discountAmt, taxVal, taxAmt, cashRec, change);
                          } else {
                            _handleCompleteSale(provider, discountVal, discountAmt, taxVal, taxAmt, totalAmt, cashRec, change);
                          }
                        },
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _paymentMethod == "Transfer" ? "CONFIRM TRANSFER & SUBMIT" : "COMPLETE SALE TRANSACTION",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.8),
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String val, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 14)),
        Text(val, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
