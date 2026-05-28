import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/pos_provider.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_background.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();

  final _supplyProductNameController = TextEditingController();
  final _supplyQuantityController = TextEditingController();
  final _supplyCostPriceController = TextEditingController();
  final _supplySalePriceController = TextEditingController();

  Supplier? _selectedSupplier;
  Product? _selectedProduct;
  String _supplyMode = "update"; // update or create
  bool _showProductDropdown = false;
  bool _submitting = false;
  String _supplyPricingMode = 'pcs';

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _supplyProductNameController.dispose();
    _supplyQuantityController.dispose();
    _supplyCostPriceController.dispose();
    _supplySalePriceController.dispose();
    super.dispose();
  }

  void _clearSupplierForm() {
    _supplierNameController.clear();
    _supplierPhoneController.clear();
  }

  void _clearSupplyForm(POSProvider provider) {
    setState(() {
      _selectedProduct = null;
      _supplyProductNameController.clear();
      _supplyQuantityController.clear();
      _supplyCostPriceController.clear();
      _supplySalePriceController.clear();
      _showProductDropdown = false;
      _supplyMode = provider.products.isNotEmpty ? "update" : "create";
      _supplyPricingMode = 'pcs';
    });
  }

  Future<void> _handleSaveSupplier(POSProvider provider) async {
    final name = _supplierNameController.text.trim();
    final phone = _supplierPhoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showErrorDialog("Please fill all fields.");
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await provider.saveSupplier(name: name, phone: phone);
      _clearSupplierForm();
      if (mounted) {
        Navigator.pop(context); // Close add supplier dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Supplier saved successfully")),
        );
      }
    } catch (e) {
      _showErrorDialog("Failed to save supplier: $e");
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _handleDeleteSupplier(POSProvider provider, Supplier supplier) async {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Supplier", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete ${supplier.name}?", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.deleteSupplier(supplier.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Supplier deleted successfully")),
                  );
                }
              } catch (e) {
                _showErrorDialog("Failed to delete supplier: $e");
              }
            },
            child: Text("Delete", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRecordSupply(POSProvider provider) async {
    final productName = _supplyProductNameController.text.trim();
    final costPriceText = _supplyCostPriceController.text.trim();
    final qtyText = _supplyQuantityController.text.trim();
    final salePriceText = _supplySalePriceController.text.trim();

    if (productName.isEmpty || costPriceText.isEmpty || qtyText.isEmpty) {
      _showErrorDialog("Product name, Cost price, and Quantity are required.");
      return;
    }

    if (_supplyMode == "update" && _selectedProduct == null) {
      _showErrorDialog("Please select an existing product or switch to Create New.");
      return;
    }

    final cost = double.tryParse(costPriceText) ?? 0.0;
    final qty = double.tryParse(qtyText) ?? 0.0;
    final sale = salePriceText.isNotEmpty ? (double.tryParse(salePriceText) ?? cost) : cost;
    final totalCost = cost * qty;

    if (cost <= 0 || qty <= 0) {
      _showErrorDialog("Please enter valid positive numbers for price and quantity.");
      return;
    }

    if (provider.cashBalance < totalCost) {
      _showErrorDialog("Insufficient cash drawer balance! Total cost: Rs. ${totalCost.toStringAsFixed(2)}, Balance: Rs. ${provider.cashBalance.toStringAsFixed(2)}");
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final userId = provider.userId;
      if (userId == null) throw Exception("Not logged in.");

      // 1. Record Cash Transaction OUT
      await provider.recordCashTransaction(
        type: "OUT",
        amount: totalCost,
        purpose: "Supply: $productName from ${_selectedSupplier?.name ?? 'Supplier'}",
      );

      // 2. Update / Create Product
      if (_supplyMode == "update" && _selectedProduct != null) {
        final updatedStock = _selectedProduct!.stock + qty;
        await FirebaseService.updateRow(
          'products',
          {
            'stock': updatedStock,
            'cost_price': cost,
            'sale_price': sale,
            'price': sale,
          },
          filters: {'id': _selectedProduct!.id},
        );
      } else {
        final newProduct = {
          'user_id': userId,
          'code': provider.generateProductCode(),
          'name': productName,
          'price': sale,
          'cost_price': cost,
          'sale_price': sale,
          'stock': qty,
          'pricing_mode': _supplyPricingMode,
          'unit': _supplyPricingMode == 'weight' ? provider.weightSymbol : 'pcs',
          'category': 'Supplied',
          'added_at': DateTime.now().toIso8601String(),
        };
        await FirebaseService.insertRow('products', newProduct);
      }

      // 3. Save Supplier Report Record
      await FirebaseService.insertRow('supplier_reports', {
        'user_id': userId,
        'product': productName,
        'quantity': qty,
        'unit': _supplyPricingMode == 'weight' ? provider.weightSymbol : 'pcs',
        'cost_per_unit': cost,
        'sale_per_unit': sale,
        'total_cost': totalCost,
        'date': "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}",
        'supplier': _selectedSupplier?.name ?? 'Supplier',
      });

      _clearSupplyForm(provider);
      if (mounted) {
        Navigator.pop(context); // Close sheet
        final successTheme = Theme.of(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: successTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text("Success", style: GoogleFonts.plusJakartaSans(color: successTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: Text("Supply recorded successfully!\nDrawer updated.", style: GoogleFonts.plusJakartaSans(color: successTheme.colorScheme.onSurfaceVariant)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("OK", style: GoogleFonts.plusJakartaSans(color: successTheme.primaryColor, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorDialog("Failed to record supply: $e");
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showAddSupplierDialog(POSProvider provider) {
    _clearSupplierForm();
    final dialogTheme = Theme.of(context);
    final cardColor = dialogTheme.cardColor;
    final textPrimary = dialogTheme.colorScheme.onSurface;
    final textSecondary = dialogTheme.colorScheme.onSurfaceVariant;
    final inputColor = dialogTheme.colorScheme.surfaceContainerHighest;
    final accent = dialogTheme.primaryColor;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Add Supplier", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _supplierNameController,
                    style: GoogleFonts.inter(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: "Supplier Name",
                      hintStyle: GoogleFonts.inter(color: textSecondary),
                      filled: true,
                      fillColor: inputColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supplierPhoneController,
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
                ],
              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submitting ? null : () => _handleSaveSupplier(provider),
                  child: _submitting ? const CircularProgressIndicator(color: Colors.black) : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordSupplySheet(POSProvider provider, Supplier supplier) {
    setState(() {
      _selectedSupplier = supplier;
    });
    _clearSupplyForm(provider);

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
          builder: (context, setSheetState) {
            double estimatedCost = 0.0;
            final costVal = double.tryParse(_supplyCostPriceController.text) ?? 0.0;
            final qtyVal = double.tryParse(_supplyQuantityController.text) ?? 0.0;
            estimatedCost = costVal * qtyVal;

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
                        Text("Record Supply from ${supplier.name}", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: Icon(Icons.close, color: textSecondary), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Supply Mode Toggle
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _supplyMode == "update" ? accent : inputColor,
                              foregroundColor: _supplyMode == "update" ? Colors.black : textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                _supplyMode = "update";
                                _selectedProduct = null;
                                _supplyProductNameController.clear();
                                _supplyCostPriceController.clear();
                                _supplySalePriceController.clear();
                              });
                            },
                            child: const Text("Update Existing"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _supplyMode == "create" ? accent : inputColor,
                              foregroundColor: _supplyMode == "create" ? Colors.black : textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                _supplyMode = "create";
                                _selectedProduct = null;
                                _supplyProductNameController.clear();
                                _supplyCostPriceController.clear();
                                _supplySalePriceController.clear();
                              });
                            },
                            child: const Text("Create New"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Product Dropdown Selection if update mode
                    if (_supplyMode == "update") ...[
                      InkWell(
                        onTap: () {
                          setSheetState(() {
                            _showProductDropdown = !_showProductDropdown;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: inputColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedProduct != null
                                      ? "${_selectedProduct!.name} (${_selectedProduct!.stock.toStringAsFixed(1)} ${_selectedProduct!.unit ?? 'pcs'})"
                                      : "Select product to update",
                                  style: GoogleFonts.inter(color: _selectedProduct != null ? textPrimary : textSecondary),
                                ),
                              ),
                              Icon(_showProductDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: textSecondary),
                            ],
                          ),
                        ),
                      ),
                      if (_showProductDropdown) ...[
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: inputColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.products.length,
                            itemBuilder: (ctx, pIdx) {
                              final prod = provider.products[pIdx];
                              return ListTile(
                                title: Text(prod.name, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14)),
                                subtitle: Text("Cost: Rs. ${prod.costPrice} • Stock: ${prod.stock}", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                                onTap: () {
                                  setSheetState(() {
                                    _selectedProduct = prod;
                                    _supplyProductNameController.text = prod.name;
                                    _supplyCostPriceController.text = prod.costPrice.toString();
                                    _supplySalePriceController.text = prod.salePrice.toString();
                                    _showProductDropdown = false;
                                    _supplyPricingMode = prod.pricingMode;
                                  });
                                },
                              );
                            },
                          ),
                        )
                      ],
                      const SizedBox(height: 8),
                    ],

                    // Inputs
                    TextField(
                      controller: _supplyProductNameController,
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Product Name",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_supplyMode == "create") ...[
                      const SizedBox(height: 8),
                      Text(
                        "Pricing Mode",
                        style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => _supplyPricingMode = 'pcs'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _supplyPricingMode == 'pcs' ? accent.withValues(alpha: 0.15) : Colors.transparent,
                                  border: Border.all(color: _supplyPricingMode == 'pcs' ? accent : border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "By Pieces (Pcs)",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _supplyPricingMode == 'pcs' ? accent : textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => _supplyPricingMode = 'weight'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _supplyPricingMode == 'weight' ? accent.withValues(alpha: 0.15) : Colors.transparent,
                                  border: Border.all(color: _supplyPricingMode == 'weight' ? accent : border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "By Quantity (Weight)",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _supplyPricingMode == 'weight' ? accent : textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _supplyQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: provider.pricingMode == 'weight' ? "Weight (${provider.weightSymbol})" : "Stock quantity",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _supplyCostPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Cost price per unit",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _supplySalePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: "Sale price per unit (Optional)",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Estimation Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Estimated cost:", style: GoogleFonts.plusJakartaSans(color: textSecondary)),
                          Text("Rs. ${estimatedCost.toStringAsFixed(2)}", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF00FF08), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitting ? null : () => _handleRecordSupply(provider),
                      child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Record Supply"),
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

    final bg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final green = const Color(0xFF10B981);
    final danger = theme.colorScheme.error;
    final blue = theme.primaryColor;

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
          "Supplier Ledger",
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
              icon: const Icon(Icons.add_business_rounded, size: 16, color: Colors.white),
              label: Text("Add Supplier", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _showAddSupplierDialog(provider),
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
                child: provider.suppliers.isEmpty
                    ? Center(
                  child: Text("No suppliers added to ledger yet", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14)),
                )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.suppliers.length,
                itemBuilder: (ctx, idx) {
                  final sup = provider.suppliers[idx];
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
                            child: Container(color: blue),
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                            title: Text(sup.name, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text("Phone Contact: ${sup.phone}", style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.playlist_add_rounded, color: green, size: 24),
                                  onPressed: () => _showRecordSupplySheet(provider, sup),
                                  tooltip: "Record Supply",
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: danger, size: 20),
                                  onPressed: () => _handleDeleteSupplier(provider, sup),
                                  tooltip: "Delete",
                                ),
                              ],
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
