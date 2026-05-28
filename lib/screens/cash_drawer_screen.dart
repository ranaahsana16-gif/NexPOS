import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/pos_provider.dart';
import 'reports_screen.dart';


class CashDrawerScreen extends StatefulWidget {
  const CashDrawerScreen({super.key});

  @override
  State<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends State<CashDrawerScreen> {
  final _amountController = TextEditingController();
  String _transactionType = "IN";
  String _purpose = "Day Start";

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveTransaction(POSProvider provider) async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showErrorDialog("Please enter an amount.");
      return;
      
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showErrorDialog("Please enter a valid positive number.");
      return;
    }

    if (_transactionType == "OUT" && amount > provider.cashBalance) {
      _showErrorDialog("Cannot withdraw more than available cash.");
      return;
    }

    try {
      await provider.recordCashTransaction(
        type: _transactionType,
        amount: amount,
        purpose: _purpose,
      );
      _amountController.clear();
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cash transaction recorded successfully")),
        );
      }
    } catch (e) {
      _showErrorDialog("Failed to record cash transaction: $e");
    }
  }



  void _showTransactionSheet(POSProvider provider, String type) {
    setState(() {
      _transactionType = type;
      _amountController.clear();
      _purpose = type == "IN" ? "Day Start" : "Day End";
    });

    final sheetTheme = Theme.of(context);
    final cardColor = sheetTheme.cardColor;
    final textPrimary = sheetTheme.colorScheme.onSurface;
    final textSecondary = sheetTheme.colorScheme.onSurfaceVariant;
    final border = sheetTheme.dividerColor;
    final inputColor = sheetTheme.colorScheme.surfaceContainerHighest;
    final accent = sheetTheme.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type == "IN" ? "Add Cash (Cash In)" : "Remove Cash (Cash Out)",
                          style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text("Amount (Rs.)", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "0.00",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Select Purpose", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ["Day Start", "Day End", "Supplier", "Expense", "Other"].map((p) {
                          final selected = _purpose == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(p),
                              selected: selected,
                              labelStyle: GoogleFonts.plusJakartaSans(
                                color: selected ? Colors.black : textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              selectedColor: accent,
                              backgroundColor: inputColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: border)),
                              onSelected: (bool sel) {
                                if (sel) {
                                  setModalState(() {
                                    _purpose = p;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == "IN" ? const Color(0xFF22C55E) : const Color(0xFFFF4D4D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleSaveTransaction(provider),
                      child: Text(
                        type == "IN" ? "Add Cash" : "Remove Cash",
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    // Kept for gradient/shadow checks that need fundamentally different colors per theme
    final isDark = theme.brightness == Brightness.dark;

    // Themes colors
    final bg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final green = const Color(0xFF10B981);
    final red = theme.colorScheme.error;
    final blue = theme.primaryColor;



    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: !kIsWeb,
        leading: kIsWeb
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          "Cash Drawer Terminal",
          style: GoogleFonts.plusJakartaSans(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Divider(height: 1, color: border),
            // Current Cash Balance Card (Styled like a premium card)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0D2C24), const Color(0xFF0A1C2C)]
                        : [const Color(0xFFD1FAE5), const Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F5C43).withValues(alpha: 0.3) : const Color(0xFFA7F3D0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: theme.primaryColor, size: 36),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CURRENT DRAWER CASH",
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Rs. ${provider.cashBalance.toStringAsFixed(2)}",
                            style: GoogleFonts.plusJakartaSans(
                              color: textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Cash In & Cash Out action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: green.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text("CASH IN", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _showTransactionSheet(provider, "IN"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: red.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        label: Text("CASH OUT", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _showTransactionSheet(provider, "OUT"),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: border),
                        ),
                        child: Icon(Icons.analytics_rounded, size: 48, color: blue),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Cash Ledger & Analytics",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "All cash transaction logs, weekly summaries, and PDF report exports have been moved to Terminal Analytics for unified reporting.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportsScreen(initialTab: "cash"),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(
                          "Open Cash Ledger History",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
