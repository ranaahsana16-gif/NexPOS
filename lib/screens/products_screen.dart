import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/pos_provider.dart';
import '../models/models.dart';
import '../widgets/premium_background.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockController = TextEditingController();

  Product? _editingProduct;
  bool _submitting = false;
  String _selectedPricingMode = 'pcs';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autofillCode();
    });
  }

  void _autofillCode() {
    final provider = Provider.of<POSProvider>(context, listen: false);
    if (_editingProduct == null) {
      _codeController.text = provider.generateProductCode();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _editingProduct = null;
      _codeController.clear();
      _nameController.clear();
      _costPriceController.clear();
      _salePriceController.clear();
      _stockController.clear();
      _selectedPricingMode = 'pcs';
    });
    _autofillCode();
  }

  void _editProduct(Product product) {
    setState(() {
      _editingProduct = product;
      _codeController.text = product.code;
      _nameController.text = product.name;
      _salePriceController.text = product.salePrice.toString();
      _costPriceController.text = product.costPrice.toString();
      _stockController.text = product.stock.toString();
      _selectedPricingMode = product.pricingMode;
    });
  }

  Future<void> _handleSaveProduct(POSProvider provider) async {
    final name = _nameController.text.trim();
    final salePriceText = _salePriceController.text.trim();
    final costPriceText = _costPriceController.text.trim();
    final stockText = _stockController.text.trim();

    if (name.isEmpty || salePriceText.isEmpty || stockText.isEmpty) {
      _showErrorDialog("Product Name, Sale Price, and Stock are required.");
      return;
    }

    final salePrice = double.tryParse(salePriceText);
    final costPrice = costPriceText.isNotEmpty ? (double.tryParse(costPriceText) ?? 0.0) : 0.0;
    final stock = double.tryParse(stockText);

    if (salePrice == null || salePrice < 0 || stock == null || stock < 0) {
      _showErrorDialog("Please enter valid prices and stock quantities.");
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final code = _codeController.text.trim().isNotEmpty 
          ? _codeController.text.trim() 
          : provider.generateProductCode();

      await provider.saveProduct(
        id: _editingProduct?.id,
        code: code,
        name: name,
        salePrice: salePrice,
        costPrice: costPrice,
        stock: stock,
        pricingMode: _selectedPricingMode,
      );

      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product saved successfully")),
        );
      }
    } catch (e) {
      _showErrorDialog("Failed to save product: $e");
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _handleDeleteProduct(POSProvider provider, Product product) async {
    showDialog(
      context: context,
      builder: (ctx) {
        final dTheme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: dTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Delete Product", style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete ${product.name}?", style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.onSurface)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await provider.deleteProduct(product.id);
                  if (_editingProduct?.id == product.id) {
                    _clearForm();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Product deleted successfully")),
                    );
                  }
                } catch (e) {
                  _showErrorDialog("Failed to delete product: $e");
                }
              },
              child: Text("Delete", style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.error, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dTheme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: dTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Error", style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
          content: Text(msg, style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("OK", style: GoogleFonts.plusJakartaSans(color: dTheme.colorScheme.error, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    // Theme mapping
    final bg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final inputColor = theme.colorScheme.surfaceContainerHighest;
    final accent = theme.primaryColor;
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
          "Product Catalog",
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
              // Product Edit / Add form Card
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
                    Text(
                      _editingProduct == null ? "Add New Product" : "Edit Product Profile",
                      style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Product UPC/Code",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                        prefixIcon: Icon(Icons.qr_code_rounded, color: textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Product Name",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                        prefixIcon: Icon(Icons.shopping_bag_outlined, color: textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _costPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Cost Price (Optional)",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                        prefixIcon: Icon(Icons.download_rounded, color: textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _salePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Retail Sale Price (Required)",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                        prefixIcon: Icon(Icons.upload_rounded, color: textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _stockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: provider.pricingMode == 'weight' ? "Total Weight (${provider.weightSymbol})" : "Stock Inventory Quantity",
                        hintStyle: GoogleFonts.inter(color: textSecondary),
                        filled: true,
                        fillColor: inputColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 1.5)),
                        prefixIcon: Icon(Icons.warehouse_outlined, color: textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Pricing Mode",
                      style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedPricingMode = 'pcs'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedPricingMode == 'pcs' ? accent.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(color: _selectedPricingMode == 'pcs' ? accent : border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "By Pieces (Pcs)",
                                style: GoogleFonts.plusJakartaSans(
                                  color: _selectedPricingMode == 'pcs' ? accent : textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedPricingMode = 'weight'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedPricingMode == 'weight' ? accent.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(color: _selectedPricingMode == 'weight' ? accent : border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "By Quantity (Weight)",
                                style: GoogleFonts.plusJakartaSans(
                                  color: _selectedPricingMode == 'weight' ? accent : textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              // Gradient uses primary color shades
                              gradient: _submitting
                                  ? null
                                  : LinearGradient(
                                      colors: [accent, accent.withValues(alpha: 0.85)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                              color: _submitting ? Colors.grey : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _submitting ? null : () => _handleSaveProduct(provider),
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      _editingProduct == null ? "SAVE PRODUCT" : "UPDATE PRODUCT",
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                    ),
                            ),
                          ),
                        ),
                        if (_editingProduct != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: textPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _clearForm,
                              child: Text("CANCEL", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                            ),
                          )
                        ]
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Product List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Product Directory", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${provider.products.length} items",
                      style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              provider.products.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text("No products found in the catalog", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.products.length,
                      itemBuilder: (ctx, idx) {
                        final product = provider.products[idx];
                        final unit = product.unit ?? (product.pricingMode == 'weight' ? provider.weightSymbol : 'pcs');
                        final formattedStock = product.pricingMode == 'weight'
                            ? product.stock.toStringAsFixed(1)
                            : product.stock.toStringAsFixed(0);
                        final outOfStock = product.stock <= 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                                  child: Container(color: outOfStock ? danger : const Color(0xFF10B981)),
                                ),
                                ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                                  title: Text(product.name, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Code: ${product.code} • Cost: Rs. ${product.costPrice.toStringAsFixed(0)}", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              "Stock: $formattedStock $unit", 
                                              style: GoogleFonts.inter(
                                                color: outOfStock ? danger : textSecondary, 
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (outOfStock) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: danger.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text("OUT", style: TextStyle(color: danger, fontSize: 8, fontWeight: FontWeight.bold)),
                                              )
                                            ]
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_note_rounded, color: accent, size: 24),
                                        onPressed: () => _editProduct(product),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, color: danger, size: 20),
                                        onPressed: () => _handleDeleteProduct(provider, product),
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
}
