import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/web_shell_screen.dart';

import 'services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/settings_service.dart';
import 'providers/pos_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/new_sale_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/cash_drawer_screen.dart';
import 'screens/products_screen.dart';
import 'screens/suppliers_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/analytics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Services
  await FirebaseService.initialize();
  await SettingsService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => POSProvider()),
      ],
      child: const NexPOSApp(),
    ),
  );
}

class NexPOSApp extends StatelessWidget {
  const NexPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<POSProvider>(context);
    final isDark = provider.theme == 'dark';

    // Premium Jet Black Dark Theme configuration
    final darkThemeData = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF6366F1), // Premium Indigo
      scaffoldBackgroundColor: const Color(0xFF000000), // Jet Black
      cardColor: const Color(0xFF0A0A0A), // Jet Black card surface
      dividerColor: const Color(0xFF1E1E1E), // Premium thin borders
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF818CF8),
        surface: Color(0xFF000000),
        onPrimary: Colors.white,
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFF9CA3AF), // Slate gray textSecondary
        outline: Color(0xFF1E1E1E),
        error: Color(0xFFFF3B30),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: Colors.white),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF9CA3AF)), // Slate gray textSecondary
        bodySmall: GoogleFonts.inter(color: const Color(0xFF6B7280)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );

    // Premium Super White Light Theme configuration
    final lightThemeData = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF4F46E5), // Premium Indigo
      scaffoldBackgroundColor: const Color(0xFFFFFFFF), // Super White
      cardColor: const Color(0xFFFFFFFF), // Super White card surface
      dividerColor: const Color(0xFFE2E8F0), // Premium thin borders
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF6366F1),
        surface: Color(0xFFFFFFFF),
        onPrimary: Colors.white,
        onSurface: Color(0xFF0F172A),
        onSurfaceVariant: Color(0xFF64748B), // Slate gray textSecondary
        outline: Color(0xFFE2E8F0),
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF0F172A)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF64748B)), // Slate gray textSecondary
        bodySmall: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
    );

    // Web-Only Dark Theme: Slate Midnight & Neon Mint Green
    final webDarkThemeData = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF10B981), // Neon Mint Green
      scaffoldBackgroundColor: const Color(0xFF050814), // Deep Slate Midnight
      cardColor: const Color(0xFF0F172A), // Dark Glass Slate
      dividerColor: const Color(0xFF1E293B), // Slate border
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF10B981),
        secondary: Color(0xFF34D399),
        surface: Color(0xFF0F172A),
        onPrimary: Colors.black,
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFF94A3B8), // Slate gray textSecondary
        outline: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: Colors.white),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF94A3B8)), // Slate gray textSecondary
        bodySmall: GoogleFonts.inter(color: const Color(0xFF64748B)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF050814),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      ),
    );

    // Web-Only Light Theme: Soft Slate & Deep Slate-Indigo
    final webLightThemeData = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF0F172A), // Deep Slate-Indigo
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Soft Cool Slate
      cardColor: const Color(0xFFFFFFFF), // Pure White
      dividerColor: const Color(0xFFE2E8F0), // Cool gray border
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0F172A),
        secondary: Color(0xFF334155),
        surface: Color(0xFFFFFFFF),
        onPrimary: Colors.white,
        onSurface: Color(0xFF0F172A),
        onSurfaceVariant: Color(0xFF64748B), // Slate gray textSecondary
        outline: Color(0xFFE2E8F0),
        error: Color(0xFFEF4444),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF0F172A)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF64748B)), // Slate gray textSecondary
        bodySmall: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
      ),
    );

    return MaterialApp(
      title: 'NexPOS',
      debugShowCheckedModeBanner: false,
      theme: kIsWeb ? webLightThemeData : lightThemeData,
      darkTheme: kIsWeb ? webDarkThemeData : darkThemeData,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => kIsWeb ? const WebShellScreen(initialTab: 'register') : const DashboardScreen(),
        '/new_sale': (context) => kIsWeb ? const WebShellScreen(initialTab: 'register') : const NewSaleScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/cash_drawer': (context) => kIsWeb ? const WebShellScreen(initialTab: 'cash_drawer') : const CashDrawerScreen(),
        '/products': (context) => kIsWeb ? const WebShellScreen(initialTab: 'products') : const ProductsScreen(),
        '/suppliers': (context) => kIsWeb ? const WebShellScreen(initialTab: 'suppliers') : const SuppliersScreen(),
        '/customers': (context) => kIsWeb ? const WebShellScreen(initialTab: 'customers') : const CustomersScreen(),
        '/reports': (context) => kIsWeb ? const WebShellScreen(initialTab: 'reports') : const ReportsScreen(),
        '/settings': (context) => kIsWeb ? const WebShellScreen(initialTab: 'settings') : const SettingsScreen(),
        '/analytics': (context) => kIsWeb ? const WebShellScreen(initialTab: 'analytics') : const AnalyticsScreen(),
      },
    );
  }
}
