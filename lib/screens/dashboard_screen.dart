import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/pos_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/premium_glass_card.dart';
import '../widgets/premium_background.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _clockTimer;
  String _currentTime = "";
  String _currentDate = "";
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateClock();
    });
    _searchController.addListener(() {
      Provider.of<POSProvider>(context, listen: false).setSearchQuery(_searchController.text);
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('h:mm a').format(now);
      _currentDate = DateFormat('EEE, MMM d').format(now);
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      Provider.of<POSProvider>(context, listen: false).stopSync();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bg = theme.scaffoldBackgroundColor;
    final surface = theme.cardColor;
    final surfaceElevated = theme.colorScheme.surfaceContainerHighest;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final accent = theme.primaryColor;
    final danger = theme.colorScheme.error;
    // Cash drawer has a unique tinted background per theme
    final cashBg = isDark ? const Color(0xFF0A2218) : const Color(0xFFE6F9F3);
    final cashText = const Color(0xFF10B981);

    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 768;

    if (!isTablet) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "NexPOS",
                style: GoogleFonts.plusJakartaSans(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              const SyncDotIndicator(),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: danger.withValues(alpha: 0.3)),
              ),
              child: IconButton(
                icon: Icon(Icons.logout_rounded, color: danger, size: 18),
                onPressed: _handleLogout,
                tooltip: "Log Out",
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PremiumBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Large rounded box for Cash Balance
                    StaggeredFadeSlide(
                      index: 0,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(context, '/cash_drawer'),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor.withValues(alpha: 0.15),
                                theme.primaryColor.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "CASH DRAWER BALANCE",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: theme.primaryColor,
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Rs. ${provider.cashBalance.toStringAsFixed(2)}",
                                style: GoogleFonts.plusJakartaSans(
                                  color: textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: border.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, color: textSecondary, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    "$_currentDate • $_currentTime",
                                    style: GoogleFonts.inter(
                                      color: textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    StaggeredFadeSlide(
                      index: 1,
                      child: Text(
                        "QUICK MENU",
                        style: GoogleFonts.plusJakartaSans(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.25,
                      children: [
                        StaggeredFadeSlide(
                          index: 2,
                          child: _buildMenuCard(
                            context,
                            title: "New sale",
                            icon: Icons.add_shopping_cart_rounded,
                            route: '/new_sale',
                            color: const Color(0xFF6366F1), // Premium Indigo
                          ),
                        ),
                        StaggeredFadeSlide(
                          index: 3,
                          child: _buildMenuCard(
                            context,
                            title: "Products",
                            icon: Icons.inventory_2_rounded,
                            route: '/products',
                            color: const Color(0xFF8B5CF6), // Premium Violet
                          ),
                        ),
                        StaggeredFadeSlide(
                          index: 4,
                          child: _buildMenuCard(
                            context,
                            title: "Suppliers",
                            icon: Icons.local_shipping_rounded,
                            route: '/suppliers',
                            color: const Color(0xFFF59E0B), // Premium Amber
                          ),
                        ),
                        StaggeredFadeSlide(
                          index: 5,
                          child: _buildMenuCard(
                            context,
                            title: "Customers",
                            icon: Icons.people_alt_rounded,
                            route: '/customers',
                            color: const Color(0xFF10B981), // Premium Emerald
                          ),
                        ),
                        StaggeredFadeSlide(
                          index: 6,
                          child: _buildMenuCard(
                            context,
                            title: "Reports",
                            icon: Icons.analytics_rounded,
                            route: '/reports',
                            color: const Color(0xFFEC4899), // Premium Rose
                          ),
                        ),
                        StaggeredFadeSlide(
                          index: 7,
                          child: _buildMenuCard(
                            context,
                            title: "Analytics",
                            icon: Icons.insights_rounded,
                            route: '/analytics',
                            color: const Color(0xFF6366F1), // Premium Indigo
                          ),
                        ),
                        StaggeredFadeSlide(
                          index: 8,
                          child: _buildMenuCard(
                            context,
                            title: "Settings",
                            icon: Icons.settings_rounded,
                            route: '/settings',
                            color: const Color(0xFF3B82F6), // Premium Royal Blue
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "NexPOS",
                style: GoogleFonts.plusJakartaSans(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const SyncDotIndicator(),
                  const SizedBox(width: 6),
                  Text(
                    "$_currentDate • $_currentTime",
                    style: GoogleFonts.plusJakartaSans(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: surfaceElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border.withValues(alpha: 0.5)),
            ),
            child: IconButton(
              icon: Icon(Icons.grid_view_rounded, color: textSecondary, size: 18),
              onPressed: () => _showMenuBottomSheet(context, textPrimary, textSecondary, border, danger),
              tooltip: "Open Menu",
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: danger.withValues(alpha: 0.3)),
            ),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: danger, size: 18),
              onPressed: _handleLogout,
              tooltip: "Log Out",
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
                child: isTablet
                    ? Row(
                        children: [
                          // Left - Products Panel
                          Expanded(
                            flex: 5,
                            child: _buildProductsPanel(surface, surfaceElevated, textPrimary, textSecondary, border, accent, danger),
                          ),
                          VerticalDivider(width: 1, color: border.withValues(alpha: 0.5)),
                          // Right - Cart Panel
                          Expanded(
                            flex: 4,
                            child: _buildCartPanel(surface, surfaceElevated, textPrimary, textSecondary, border, accent, danger, cashBg, cashText),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // Cart Mini-Summary / Cash Drawer link at the top for phones
                          _buildCashHeader(cashBg, cashText, textSecondary),
                          Expanded(
                            child: _buildProductsPanel(surface, surfaceElevated, textPrimary, textSecondary, border, accent, danger),
                          ),
                          _buildPhoneCartFooter(surface, textPrimary, textSecondary, border, accent),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashHeader(Color cashBg, Color cashText, Color textSecondary) {
    final provider = Provider.of<POSProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/cash_drawer'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cashBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: cashText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cash Drawer Balance", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 11)),
                    Text(
                      "Rs. ${provider.cashBalance.toStringAsFixed(2)}",
                      style: GoogleFonts.plusJakartaSans(color: cashText, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsPanel(Color surface, Color surfaceElevated, Color textPrimary, Color textSecondary, Color border, Color accent, Color danger) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PremiumGlassCard(
              blur: 10,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.cardColor.withValues(alpha: 0.8),
              borderColor: theme.dividerColor,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                            SnackBar(
                                              content: Text("${product.name} is out of stock!"),
                                              backgroundColor: danger,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        } else {
                                          provider.addToCart(product);
                                        }
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
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  product.code,
                                                  style: GoogleFonts.inter(
                                                    color: textSecondary,
                                                    fontSize: 10,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Rs. ${product.salePrice.toStringAsFixed(0)}",
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: accent,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      provider.pricingMode == 'weight'
                                                          ? "${product.stock.toStringAsFixed(1)} $unit"
                                                          : "${product.stock.toStringAsFixed(0)} $unit",
                                                      style: GoogleFonts.inter(
                                                        color: outOfStock ? danger : textSecondary,
                                                        fontSize: 11,
                                                        fontWeight: outOfStock ? FontWeight.bold : FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (isLowStock) ...[
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: indicatorColor.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          "LOW",
                                                          style: TextStyle(
                                                            color: indicatorColor,
                                                            fontSize: 8,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ]
                                                  ],
                                                ),
                                              ],
                                            )
                                          ],
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
    );
  }

  Widget _buildCartPanel(Color surface, Color surfaceElevated, Color textPrimary, Color textSecondary, Color border, Color accent, Color danger, Color cashBg, Color cashText) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);

    return Container(
      color: theme.brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCashHeader(cashBg, cashText, textSecondary),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Active Cart",
                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
              ),
              if (provider.cart.isNotEmpty)
                TextButton(
                  onPressed: () => provider.clearCart(),
                  style: TextButton.styleFrom(foregroundColor: danger),
                  child: Text("Clear All", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Cart Items
          Expanded(
            child: provider.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          "Your terminal cart is empty",
                          style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: provider.cart.length,
                    itemBuilder: (ctx, idx) {
                      final item = provider.cart[idx];
                      final unit = item.product.unit ?? (provider.pricingMode == 'weight' ? provider.weightSymbol : 'pcs');
                      final formattedQty = provider.pricingMode == 'weight'
                          ? item.quantity.toStringAsFixed(1)
                          : item.quantity.toStringAsFixed(0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Rs. ${item.product.salePrice.toStringAsFixed(0)} × $formattedQty $unit",
                                    style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.remove_circle_outline_rounded, color: danger, size: 22),
                                  onPressed: () => provider.decreaseCartItem(item.product),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    formattedQty,
                                    style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.add_circle_outline_rounded, color: accent, size: 22),
                                  onPressed: () => provider.increaseCartItem(item.product),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.delete_outline_rounded, color: danger.withValues(alpha: 0.8), size: 20),
                                  onPressed: () => provider.removeFromCart(item.product),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Total Section
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Amount", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(
                      "Rs. ${provider.cartTotal.toStringAsFixed(2)}",
                      style: GoogleFonts.plusJakartaSans(
                        color: accent,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: provider.cart.isEmpty
                        ? null
                        : LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.85)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: provider.cart.isEmpty ? textSecondary.withValues(alpha: 0.12) : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: provider.cart.isEmpty
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
                      foregroundColor: provider.cart.isEmpty ? textSecondary : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: provider.cart.isEmpty
                        ? null
                        : () {
                            Navigator.pushNamed(context, '/checkout');
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text("PROCEED TO CHECKOUT", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPhoneCartFooter(Color surface, Color textPrimary, Color textSecondary, Color border, Color accent) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    if (provider.cart.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Total (${provider.cart.length} items)", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 12)),
              Text(
                "Rs. ${provider.cartTotal.toStringAsFixed(2)}",
                style: GoogleFonts.plusJakartaSans(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/checkout');
              },
              child: Text("Checkout", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context, Color textPrimary, Color textSecondary, Color border, Color danger) {
    final menuTheme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: menuTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final items = [
          {'name': 'Products', 'icon': Icons.inventory_2_outlined, 'color': const Color(0xFF10B981), 'route': '/products'},
          {'name': 'Suppliers', 'icon': Icons.business_outlined, 'color': const Color(0xFFF59E0B), 'route': '/suppliers'},
          {'name': 'Customers', 'icon': Icons.people_outline, 'color': const Color(0xFF8B5CF6), 'route': '/customers'},
          {'name': 'Reports', 'icon': Icons.bar_chart_outlined, 'color': const Color(0xFF06B6D4), 'route': '/reports'},
          {'name': 'Analytics', 'icon': Icons.insights_outlined, 'color': const Color(0xFF6366F1), 'route': '/analytics'},
          {'name': 'Settings', 'icon': Icons.settings_outlined, 'color': const Color(0xFFEC4899), 'route': '/settings'},
        ];

        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            color: menuTheme.cardColor,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "NexPOS Menu",
                  style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                ...items.map((item) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
                        ),
                        title: Text(
                          item['name'] as String,
                          style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 18),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, item['route'] as String);
                        },
                      ),
                      Divider(height: 1, color: border),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: menuTheme.colorScheme.surfaceContainerHighest,
                    foregroundColor: textPrimary,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Close", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    required Color color,
  }) {
    final cardTheme = Theme.of(context);
    final cardBg = cardTheme.cardColor;
    final borderCol = cardTheme.dividerColor;
    final textPrimary = cardTheme.colorScheme.onSurface;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaggeredFadeSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;

  const StaggeredFadeSlide({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 100),
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    if (provider.optimizePerformance) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class SyncDotIndicator extends StatelessWidget {
  const SyncDotIndicator({super.key});

  void _showSyncStatusBottomSheet(BuildContext context, POSProvider provider) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cloud Synchronization State",
                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  provider.isDeviceOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: provider.isDeviceOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                title: Text(
                  provider.isDeviceOnline ? "Online Mode" : "Offline Mode",
                  style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  provider.isDeviceOnline 
                      ? "Directly connected to Firebase Cloud servers"
                      : "Transactions are securely saved locally and will auto-sync when connection is restored",
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "Write Sync Queue Status",
                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSyncQueueItem("Product catalog updates", provider.productsPending, theme),
              _buildSyncQueueItem("Customer profiles ledger", provider.customersPending, theme),
              _buildSyncQueueItem("Supplier database records", provider.suppliersPending, theme),
              _buildSyncQueueItem("Cash drawer transaction log", provider.transactionsPending, theme),
              _buildSyncQueueItem("Khata ledger transactions", provider.creditTransactionsPending, theme),
              _buildSyncQueueItem("Terminal settings config", provider.settingsPending, theme),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncQueueItem(String label, bool isPending, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPending ? "PENDING SYNC" : "SYNCED",
              style: GoogleFonts.plusJakartaSans(
                color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final isOnline = provider.isDeviceOnline;
    final hasPending = provider.hasPendingWrites;

    int pendingCount = 0;
    if (provider.productsPending) pendingCount++;
    if (provider.customersPending) pendingCount++;
    if (provider.suppliersPending) pendingCount++;
    if (provider.transactionsPending) pendingCount++;
    if (provider.creditTransactionsPending) pendingCount++;
    if (provider.settingsPending) pendingCount++;

    if (!isOnline) {
      return Tooltip(
        message: "Offline - $pendingCount pending writes",
        child: InkWell(
          onTap: () => _showSyncStatusBottomSheet(context, provider),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 10, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  "Offline ($pendingCount)",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dotColor = hasPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final tooltip = hasPending ? "Syncing changes to Cloud..." : "Connected & Cloud Synced";

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _showSyncStatusBottomSheet(context, provider),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
