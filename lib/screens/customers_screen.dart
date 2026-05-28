import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/pos_provider.dart';
import '../models/models.dart';
import '../widgets/premium_background.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _customerAddressController.clear();
  }

  void _showCustomerDialog(POSProvider provider, {Customer? customer}) {
    _clearForm();
    if (customer != null) {
      _customerNameController.text = customer.name;
      _customerPhoneController.text = customer.phone;
      _customerAddressController.text = customer.address ?? "";
    }

    final dialogTheme = Theme.of(context);
    final cardColor = dialogTheme.cardColor;
    final textPrimary = dialogTheme.colorScheme.onSurface;
    final textSecondary = dialogTheme.colorScheme.onSurfaceVariant;
    final inputColor = dialogTheme.colorScheme.surfaceContainerHighest;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(customer != null ? "Edit Customer" : "Add Customer", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _customerNameController,
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Customer Name",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerPhoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Phone Number",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customerAddressController,
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Address (Optional)",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submitting
                      ? null
                      : () async {
                           final name = _customerNameController.text.trim();
                           final phone = _customerPhoneController.text.trim();
                           final address = _customerAddressController.text.trim();

                           if (name.isEmpty || phone.isEmpty) {
                             _showErrorDialog("Please enter customer name and phone number.");
                             return;
                           }

                           setDialogState(() {
                             _submitting = true;
                           });

                           try {
                             await provider.saveCustomer(
                               id: customer?.id,
                               name: name,
                               phone: phone,
                               address: address.isNotEmpty ? address : null,
                               totalOrders: customer?.totalOrders ?? 0,
                               totalSpent: customer?.totalSpent ?? 0.0,
                               creditBalance: customer?.creditBalance ?? 0.0,
                               creditLimit: customer?.creditLimit ?? 50000.0,
                             );
                             _clearForm();
                             if (mounted) {
                               Navigator.pop(ctx); // Close dialog
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text("Customer saved successfully")),
                               );
                             }
                           } catch (e) {
                             _showErrorDialog("Failed to save customer: $e");
                           } finally {
                             setDialogState(() {
                               _submitting = false;
                             });
                           }
                         },
                  child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLedgerBottomSheet(POSProvider provider, Customer customer) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final purple = const Color(0xFF8B5CF6);
    final positive = const Color(0xFF10B981);
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String selectedMethod = 'Cash';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final txs = provider.creditTransactions.where((t) => t.customerId == customer.id).toList();
            final currentCust = provider.customers.firstWhere((c) => c.id == customer.id, orElse: () => customer);

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${currentCust.name}'s Ledger",
                        style: GoogleFonts.plusJakartaSans(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Outstanding Balance", style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          "Rs. ${currentCust.creditBalance.toStringAsFixed(2)}",
                          style: GoogleFonts.plusJakartaSans(
                            color: currentCust.creditBalance > 0 ? theme.colorScheme.error : positive,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Ledger History", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: txs.isEmpty
                        ? Center(child: Text("No credit transactions recorded.", style: GoogleFonts.inter(color: textSecondary, fontSize: 12)))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: txs.length,
                            itemBuilder: (context, index) {
                              final tx = txs[index];
                              final isPurchase = tx.type == 'PURCHASE';
                              final amountText = isPurchase ? "+Rs. ${tx.amount.toStringAsFixed(0)}" : "-Rs. ${tx.amount.toStringAsFixed(0)}";
                              final titleText = isPurchase 
                                  ? "Purchase (Sale #${tx.saleId ?? ''})" 
                                  : "Payment Collected (${tx.paymentMethod ?? 'Cash'})";
                              final fontSignColor = isPurchase ? theme.colorScheme.error : positive;
                              final dateText = tx.date.length > 16 ? tx.date.substring(0, 16).replaceAll('T', ' ') : tx.date;
                              
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isPurchase ? Icons.shopping_bag_outlined : Icons.monetization_on_outlined,
                                  color: fontSignColor,
                                ),
                                title: Text(titleText, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dateText, style: GoogleFonts.inter(color: textSecondary, fontSize: 10)),
                                    if (isPurchase && tx.details != null && tx.details!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        tx.details!, 
                                        style: GoogleFonts.inter(color: textPrimary.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Text(amountText, style: GoogleFonts.inter(color: fontSignColor, fontWeight: FontWeight.bold, fontSize: 14)),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text("Receive Payment (Collect Outstanding)", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Cash', 'Card', 'Transfer'].map((method) {
                      final isSelected = selectedMethod == method;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedMethod = method;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.primaryColor.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(color: isSelected ? theme.primaryColor : border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                method,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected ? theme.primaryColor : textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Enter amount to collect",
                            hintStyle: GoogleFonts.inter(color: textSecondary),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: positive,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text.trim());
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid positive amount.")));
                            return;
                          }
                          try {
                            await provider.recordCreditPayment(customer.id, amt, paymentMethod: selectedMethod);
                            amountController.clear();
                            setModalState(() {}); // Refresh local modal lists
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Collected Rs. ${amt.toStringAsFixed(0)} payment ($selectedMethod) successfully.")));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                          }
                        },
                        child: Text("Collect", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
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

  Future<void> _handleDeleteCustomer(POSProvider provider, Customer customer) async {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Customer", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete ${customer.name}?", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await provider.deleteCustomer(customer.id);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Customer deleted successfully")),
                  );
                }
              } catch (e) {
                _showErrorDialog("Failed to delete customer: $e");
              }
            },
            child: Text("Delete", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
    final danger = theme.colorScheme.error;

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
          "Customer Database",
          style: GoogleFonts.plusJakartaSans(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
              label: Text("Add Customer", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _showCustomerDialog(provider),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: provider.customers.isEmpty
                    ? Center(
                        child: Text("No customers found in database", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14)),
                      )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.customers.length,
                itemBuilder: (ctx, idx) {
                  final cust = provider.customers[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 3)),
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
                            child: Container(color: purple),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            title: Text(cust.name, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Phone: ${cust.phone}", style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                                  if (cust.address != null && cust.address!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text("Address: ${cust.address!}", style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    "Orders: ${cust.totalOrders} • Total spent: Rs. ${cust.totalSpent.toStringAsFixed(0)}",
                                    style: GoogleFonts.inter(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.credit_card, size: 12, color: cust.creditBalance > 0 ? danger : purple),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Khata Balance: Rs. ${cust.creditBalance.toStringAsFixed(0)}",
                                        style: GoogleFonts.inter(
                                          color: cust.creditBalance > 0 ? danger : textSecondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.receipt_long_rounded, size: 14),
                                        label: const Text("Ledger"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: purple,
                                          side: BorderSide(color: purple.withValues(alpha: 0.5)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showLedgerBottomSheet(provider, cust),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit_note_rounded, size: 14),
                                        label: const Text("Edit"),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: textPrimary,
                                          side: BorderSide(color: border),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _showCustomerDialog(provider, customer: cust),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: danger, size: 20),
                              onPressed: () => _handleDeleteCustomer(provider, cust),
                              tooltip: "Delete",
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
