import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/pos_provider.dart';
import '../widgets/premium_background.dart';

// Import all screens to embed them
import 'new_sale_screen.dart';
import 'products_screen.dart';
import 'suppliers_screen.dart';
import 'customers_screen.dart';
import 'cash_drawer_screen.dart';
import 'reports_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class WebShellScreen extends StatefulWidget {
  final String initialTab;

  const WebShellScreen({
    super.key,
    required this.initialTab,
  });

  @override
  State<WebShellScreen> createState() => _WebShellScreenState();
}

class _WebShellScreenState extends State<WebShellScreen> {
  late String _activeTab;
  bool _isSidebarCollapsed = false;
  late Timer _clockTimer;
  String _currentTime = "";
  String _currentDate = "";

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateClock();
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('h:mm a').format(now);
      _currentDate = DateFormat('EEE, MMM d, yyyy').format(now);
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    try {
      final provider = Provider.of<POSProvider>(context, listen: false);
      provider.stopSync();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = theme.scaffoldBackgroundColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final accent = theme.primaryColor;

    return Scaffold(
      backgroundColor: bg,
      body: PremiumBackground(
        child: SafeArea(
          child: Row(
            children: [
              // 1. Sidebar Panel
              _buildSidebar(theme, isDark, textPrimary, textSecondary, border, accent, provider),

              // 2. Divider
              VerticalDivider(width: 1, color: border.withValues(alpha: 0.5)),

              // 3. Central Content Pane
              Expanded(
                child: Column(
                  children: [
                    // Top App Header bar
                    _buildTopBar(theme, textPrimary, textSecondary, border, accent, provider),
                    Divider(height: 1, color: border.withValues(alpha: 0.3)),

                    // Content panel body containing IndexedStack of screens
                    Expanded(
                      child: _buildActivePane(),
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

  // Top Bar Layout
  Widget _buildTopBar(ThemeData theme, Color textPrimary, Color textSecondary, Color border, Color accent, POSProvider provider) {
    final syncCount = (provider.productsPending ? 1 : 0) +
        (provider.customersPending ? 1 : 0) +
        (provider.suppliersPending ? 1 : 0) +
        (provider.transactionsPending ? 1 : 0) +
        (provider.creditTransactionsPending ? 1 : 0) +
        (provider.settingsPending ? 1 : 0);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Current Page Label
          Row(
            children: [
              Text(
                _activeTab.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 16),
              if (syncCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        "$syncCount Pending writes",
                        style: GoogleFonts.inter(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Right: Real-time clock & User profile
          Row(
            children: [
              // Clock
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_currentTime, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(_currentDate, style: GoogleFonts.inter(color: textSecondary, fontSize: 10)),
                ],
              ),
              const SizedBox(width: 24),
              // Theme Toggle
              IconButton(
                icon: Icon(provider.theme == 'dark' ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                onPressed: () {
                  provider.toggleTheme(provider.theme == 'dark' ? 'light' : 'dark');
                },
              ),
              const SizedBox(width: 12),
              // Profile circle
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.15),
                radius: 18,
                child: Text(
                  (provider.userId ?? 'U').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(color: accent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sidebar Layout
  Widget _buildSidebar(ThemeData theme, bool isDark, Color textPrimary, Color textSecondary, Color border, Color accent, POSProvider provider) {
    final double width = _isSidebarCollapsed ? 80 : 260;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      height: double.infinity,
      color: Colors.transparent,
      child: Column(
        children: [
          // Logo Header
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.store_rounded, color: accent, size: 24),
                ),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "NexPOS",
                          style: GoogleFonts.plusJakartaSans(
                            color: textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: -1,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final url = Uri.parse("https://tillnex.space");
                            if (await launchUrl(url)) {
                              // success
                            }
                          },
                          child: Text(
                            "powered by tillnex.space",
                            style: GoogleFonts.inter(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSidebarItem(Icons.shopping_basket_rounded, "POS Register", 'register', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.inventory_2_rounded, "Products Catalog", 'products', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.local_shipping_rounded, "Suppliers Ledger", 'suppliers', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.people_rounded, "Customer Database", 'customers', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.account_balance_wallet_rounded, "Cash Drawer", 'cash_drawer', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.receipt_long_rounded, "Reports Ledger", 'reports', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.analytics_rounded, "Analytics", 'analytics', textPrimary, textSecondary, accent),
                _buildSidebarItem(Icons.settings_rounded, "Store Settings", 'settings', textPrimary, textSecondary, accent),
              ],
            ),
          ),

          // Drawer Balance indicator (if expanded)
          if (!_isSidebarCollapsed)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xBB0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Drawer Cash", style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rs. ${provider.cashBalance.toStringAsFixed(2)}",
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),

          // Collapse & Logout buttons
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                IconButton(
                  icon: Icon(_isSidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                ),
                const SizedBox(height: 4),
                _buildLogoutItem(textPrimary, textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, String tabId, Color textPrimary, Color textSecondary, Color accent) {
    final isSelected = _activeTab == tabId;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tabId;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? accent.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? accent : textSecondary, size: 20),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? textPrimary : textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(Color textPrimary, Color textSecondary) {
    return InkWell(
      onTap: _handleLogout,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 16),
              Text(
                "Logout",
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivePane() {
    int index = 0;
    switch (_activeTab) {
      case 'register':
        index = 0;
        break;
      case 'products':
        index = 1;
        break;
      case 'suppliers':
        index = 2;
        break;
      case 'customers':
        index = 3;
        break;
      case 'cash_drawer':
        index = 4;
        break;
      case 'reports':
        index = 5;
        break;
      case 'analytics':
        index = 6;
        break;
      case 'settings':
        index = 7;
        break;
    }

    return IndexedStack(
      index: index,
      children: const [
        NewSaleScreen(),
        ProductsScreen(),
        SuppliersScreen(),
        CustomersScreen(),
        CashDrawerScreen(),
        ReportsScreen(),
        AnalyticsScreen(),
        SettingsScreen(),
      ],
    );
  }
}
