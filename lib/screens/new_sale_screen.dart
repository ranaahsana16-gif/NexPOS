import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/pos_provider.dart';
import '../widgets/premium_glass_card.dart';
import '../widgets/premium_background.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      Provider.of<POSProvider>(context, listen: false).setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);


    final bg = theme.scaffoldBackgroundColor;
    final surface = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
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
                  onPressed: () {
                    provider.setSearchQuery('');
                    Navigator.pop(context);
                  },
                ),
              ),
        title: Text(
          "New Sale",
          style: GoogleFonts.plusJakartaSans(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (provider.cart.isNotEmpty)
            TextButton(
              onPressed: () => provider.clearCart(),
              child: Text(
                "Clear Cart",
                style: GoogleFonts.plusJakartaSans(
                  color: danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: PremiumBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PremiumGlassCard(
              blur: 10,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.cardColor.withValues(alpha: 0.8),
              borderColor: border,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Search products by name or code...",
                  hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Product List
          Expanded(
            child: provider.loadingProducts
                ? Center(child: CircularProgressIndicator(color: accent))
                : provider.filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isNotEmpty ? "No products found" : "No products added yet",
                          style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: provider.cart.isNotEmpty ? 100 : 16,
                        ),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 125,
                        ),
                        itemCount: provider.filteredProducts.length,
                        itemBuilder: (ctx, idx) {
                          final product = provider.filteredProducts[idx];
                          final isLowStock = product.stock > 0 && product.stock <= 5;
                          final outOfStock = product.stock <= 0;
                          final unit = product.unit ?? (provider.pricingMode == 'weight' ? provider.weightSymbol : 'pcs');

                          // Stock indicators
                          Color indicatorColor = const Color(0xFF10B981); // Green
                          if (outOfStock) {
                            indicatorColor = danger;
                          } else if (isLowStock) {
                            indicatorColor = const Color(0xFFF59E0B); // Amber
                          }

                          final inCartCount = provider.cart
                              .where((it) => it.product.id == product.id)
                              .fold(0.0, (sum, it) => sum + it.quantity);

                          return Container(
                            decoration: BoxDecoration(
                              color: surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: outOfStock
                                    ? danger.withValues(alpha: 0.3)
                                    : border.withValues(alpha: 0.5),
                                width: outOfStock ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  // Left stock status vertical line
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: 5,
                                    child: Container(color: indicatorColor),
                                  ),
                                  
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (outOfStock) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Product is out of stock!"),
                                              backgroundColor: Colors.red,
                                              duration: Duration(milliseconds: 800),
                                            ),
                                          );
                                          return;
                                        }
                                        provider.addToCart(product);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("${product.name} added to cart!"),
                                            duration: const Duration(milliseconds: 600),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "Code: ${product.code}",
                                                  style: GoogleFonts.inter(
                                                    color: textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Rs. ${product.salePrice.toStringAsFixed(2)}",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: accent,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: indicatorColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    outOfStock
                                                        ? "OUT OF STOCK"
                                                        : "${product.stock.toStringAsFixed(1)} $unit",
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: indicatorColor,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Cart badge counter overlay
                                  if (inCartCount > 0)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          inCartCount.toStringAsFixed(0),
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
              if (provider.cart.isNotEmpty && MediaQuery.of(context).viewInsets.bottom == 0)
                _buildFloatingCartBar(context, provider, surface, textPrimary, textSecondary, border, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar(BuildContext context, POSProvider provider, Color surface, Color textPrimary, Color textSecondary, Color border, Color accent) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: GestureDetector(
        onTap: () => _showCartDetailsPopup(context, provider, surface, textPrimary, textSecondary, border, accent),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_bag_rounded, color: accent, size: 22),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            provider.cart.fold(0.0, (sum, item) => sum + item.quantity).toStringAsFixed(0),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Total Amount",
                        style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Rs. ${provider.cartTotal.toStringAsFixed(2)}",
                        style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.85)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    _showCartDetailsPopup(context, provider, surface, textPrimary, textSecondary, border, accent);
                  },
                  child: Text("Checkout", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCartDetailsPopup(BuildContext context, POSProvider provider, Color surfaceColor, Color textPrimary, Color textSecondary, Color border, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final p = Provider.of<POSProvider>(context);
            if (p.cart.isEmpty) {
              Future.delayed(Duration.zero, () {
                Navigator.of(ctx).pop();
              });
            }

            final modalTheme = Theme.of(ctx);
            final bg = modalTheme.brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF9FAFB);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 25,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Products in Cart",
                          style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${p.cart.length} items",
                            style: GoogleFonts.plusJakartaSans(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: border),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: p.cart.length,
                      itemBuilder: (context, index) {
                        final item = p.cart[index];
                        final formattedQty = p.pricingMode == 'weight'
                            ? item.quantity.toStringAsFixed(1)
                            : item.quantity.toStringAsFixed(0);
                        final unit = item.product.unit ?? (p.pricingMode == 'weight' ? p.weightSymbol : 'pcs');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: modalTheme.cardColor.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Rs. ${item.product.salePrice.toStringAsFixed(2)} / $unit",
                                      style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded),
                                    color: textSecondary,
                                    onPressed: () {
                                      p.decreaseCartItem(item.product);
                                      setModalState(() {});
                                    },
                                  ),
                                  Text(
                                    formattedQty,
                                    style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                    color: accent,
                                    onPressed: () {
                                      p.increaseCartItem(item.product);
                                      setModalState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                    onPressed: () {
                                      p.removeFromCart(item.product);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: modalTheme.cardColor,
                      border: Border(top: BorderSide(color: border)),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total Amount", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text(
                                "Rs. ${p.cartTotal.toStringAsFixed(2)}",
                                style: GoogleFonts.plusJakartaSans(color: accent, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, accent.withValues(alpha: 0.85)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.pushNamed(context, '/checkout');
                              },
                              child: Text(
                                "PROCEED TO CHECKOUT",
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
