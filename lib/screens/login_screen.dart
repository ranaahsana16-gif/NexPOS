import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/settings_service.dart';
import '../providers/pos_provider.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String _errorMessage = "";
  final LocalAuthentication _localAuth = LocalAuthentication();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final savedEmail = SettingsService.getLastLoggedInEmail();
    if (savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Provide email and password";
      });
      return;
    }

    setState(() {
      _errorMessage = "";
      _loading = true;
    });

    try {
      final online = await FirebaseService.isOnline();
      if (!online) {
        throw Exception("No internet connection. Please check your network.");
      }

      final response = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.toLowerCase(),
        password: password,
      );

      if (response.user != null) {
        await SettingsService.setLastLoggedInEmail(email);
        
        // Load data on successful login (in the background, non-blocking)
        if (mounted) {
          Provider.of<POSProvider>(context, listen: false).startSync();
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        setState(() {
          _errorMessage = "Login failed - no session created";
        });
      }
    } catch (err) {
      setState(() {
        _errorMessage = err.toString().replaceAll("Exception:", "").trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final provider = Provider.of<POSProvider>(context, listen: false);
    if (!provider.biometricEnabled) {
      _showAlertDialog("Biometric disabled", "Please enable it in Settings first.");
      return;
    }

    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final hasHardware = await _localAuth.isDeviceSupported();

      if (!canAuth || !hasHardware) {
        _showAlertDialog("Not supported", "Biometric authentication is not available on this device.");
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to Login to NexPOS',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          provider.startSync();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else {
          _showAlertDialog("No session", "Please log in with email/password once first.");
        }
      }
    } catch (e) {
      _showAlertDialog("Error", "Biometric authentication failed: $e");
    }
  }

  void _showAlertDialog(String title, String message) {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK", style: GoogleFonts.plusJakartaSans(color: dialogTheme.primaryColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Contact Administrator", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("To reset your password or get access, contact support:", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.phone_android, color: dialogTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Text("+92 339-5121676", style: GoogleFonts.plusJakartaSans(color: dialogTheme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dialogTheme.primaryColor,
              foregroundColor: dialogTheme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 768;
    final theme = Theme.of(context);

    final inputFill = theme.cardColor.withValues(alpha: 0.8);
    final textCol = theme.colorScheme.onSurface;
    final hintCol = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Logo Area (Only show on Web/Tablet, hide on Mobile)
                      if (isTablet) ...[
                        Hero(
                          tag: 'logo',
                          child: Image.asset(
                            'assets/icon.png',
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        "NexPOS",
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.colorScheme.onSurface,
                          fontSize: isTablet ? 38 : 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                      Text(
                        "Secure Cloud Terminal",
                        style: GoogleFonts.plusJakartaSans(
                          color: hintCol,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Card
                      PremiumGlassCard(
                        blur: 20.0,
                        borderRadius: 24.0,
                        padding: const EdgeInsets.all(28.0),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "MEMBER SIGN IN",
                                style: GoogleFonts.plusJakartaSans(
                                  color: textCol,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              
                              // Email Field
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.inter(color: textCol, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: "Email Address",
                                  hintStyle: GoogleFonts.inter(color: hintCol),
                                  filled: true,
                                  fillColor: inputFill,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: theme.dividerColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: theme.dividerColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                                  ),
                                  prefixIcon: Icon(Icons.email_outlined, color: hintCol, size: 20),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              TextField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                style: GoogleFonts.inter(color: textCol, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: "Password",
                                  hintStyle: GoogleFonts.inter(color: hintCol),
                                  filled: true,
                                  fillColor: inputFill,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: theme.dividerColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: theme.dividerColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                                  ),
                                  prefixIcon: Icon(Icons.lock_outline_rounded, color: hintCol, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: hintCol,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              // Error Message
                              if (_errorMessage.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFFF4D4D), size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF4D4D), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Login Button
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [theme.primaryColor, theme.colorScheme.secondary],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _handleLogin,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          "SIGN IN TERMINAL",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            fontSize: 14,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Forgot Password
                              Center(
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    foregroundColor: hintCol,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: Text(
                                    "Forgot Password?",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: theme.dividerColor)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      "BIOMETRICS",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: hintCol,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: theme.dividerColor)),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Fingerprint button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _handleBiometricLogin,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.dividerColor,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      color: theme.cardColor.withValues(alpha: 0.4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.fingerprint_rounded,
                                          size: 28,
                                          color: theme.primaryColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Touch / Face ID Login",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: textCol,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Watermark
                      Text(
                        "NexPOS Terminal • Helpline 0339-5121676",
                        style: GoogleFonts.plusJakartaSans(
                          color: hintCol.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
