import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../providers/pos_provider.dart';
import '../widgets/premium_background.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _taxRateController = TextEditingController();
  final _discountController = TextEditingController();
  final _wifiIpController = TextEditingController();
  final _wifiPortController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopTaglineController = TextEditingController();
  String? _selectedLogoPath;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<POSProvider>(context, listen: false);
    _taxRateController.text = provider.taxRate.toStringAsFixed(0);
    _discountController.text = provider.defaultDiscount.toStringAsFixed(0);
    _wifiIpController.text = (provider.printerType == 'wifi' ? provider.selectedPrinterAddress : '') ?? '';
    _wifiPortController.text = provider.printerPort.toString();
    _shopNameController.text = SettingsService.getShopName();
    _shopAddressController.text = SettingsService.getShopAddress();
    _shopPhoneController.text = SettingsService.getShopPhone();
    _shopTaglineController.text = SettingsService.getShopTagline();
    _selectedLogoPath = SettingsService.getShopLogoPath();
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _discountController.dispose();
    _wifiIpController.dispose();
    _wifiPortController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _shopTaglineController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveTaxRate(POSProvider provider) async {
    final rate = double.tryParse(_taxRateController.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      _showAlertDialog("Invalid Rate", "Tax rate must be between 0 and 100.");
      return;
    }
    await provider.updateTaxRate(rate);
    _showSnackBar("Tax rate updated.");
  }

  Future<void> _handleSaveDiscount(POSProvider provider) async {
    final discount = double.tryParse(_discountController.text.trim());
    if (discount == null || discount < 0 || discount > 100) {
      _showAlertDialog("Invalid Discount", "Default discount must be between 0 and 100.");
      return;
    }
    await provider.updateDefaultDiscount(discount);
    _showSnackBar("Default discount updated.");
  }

  Future<void> _toggleBiometrics(POSProvider provider, bool enable) async {
    if (enable) {
      try {
        final canAuth = await _localAuth.canCheckBiometrics;
        final hasHardware = await _localAuth.isDeviceSupported();

        if (!canAuth || !hasHardware) {
          _showAlertDialog("Not Supported", "Biometric authentication is not supported on this device.");
          return;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to enable biometric login for NexPOS',
          options: const AuthenticationOptions(stickyAuth: true),
        );

        if (authenticated) {
          await provider.updateBiometrics(true);
          _showSnackBar("Biometric login enabled.");
        }
      } catch (e) {
        _showAlertDialog("Error", "Unable to enable biometrics: $e");
      }
    } else {
      await provider.updateBiometrics(false);
      _showSnackBar("Biometric login disabled.");
    }
  }



  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  void _confirmResetSync(POSProvider provider) {
    final dialogTheme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              "Reset Sync Queue?",
              style: GoogleFonts.plusJakartaSans(
                color: dialogTheme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "This will clear the offline write queue. Any unsaved offline sales or product edits that have not synced to the cloud yet will be discarded. Do you want to proceed?",
          style: GoogleFonts.plusJakartaSans(
            color: dialogTheme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.plusJakartaSans(
                color: dialogTheme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.clearFirestoreCache();
                _showSnackBar("Sync queue has been reset and restarted.");
              } catch (e) {
                _showAlertDialog("Reset Failed", "Failed to reset sync queue: $e");
              }
            },
            child: Text(
              "Reset",
              style: GoogleFonts.plusJakartaSans(
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
    final theme = Theme.of(context);


    final bg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final border = theme.dividerColor;
    final inputColor = theme.colorScheme.surfaceContainerHighest;
    final primaryButtonColor = theme.primaryColor;

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
          "Terminal Settings",
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
              // Theme Options
              _buildSettingCard(
                title: "Terminal Appearance",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Select Theme: ${provider.theme.toUpperCase()}", style: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: provider.theme == 'dark' ? primaryButtonColor : inputColor,
                              foregroundColor: provider.theme == 'dark' ? theme.colorScheme.onPrimary : textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            onPressed: () => provider.toggleTheme('dark'),
                            child: Text("Dark Mode", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: provider.theme == 'light' ? primaryButtonColor : inputColor,
                              foregroundColor: provider.theme == 'light' ? Colors.white : textPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            onPressed: () => provider.toggleTheme('light'),
                            child: Text("Light Mode", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tax rate setting
              _buildSettingCard(
                title: "Government Tax Rate (%)",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taxRateController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryButtonColor, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryButtonColor,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _handleSaveTaxRate(provider),
                      child: Text("Save", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Default discount setting
              _buildSettingCard(
                title: "Standard Discount (%)",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _discountController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryButtonColor, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryButtonColor,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _handleSaveDiscount(provider),
                      child: Text("Save", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Weight Unit Options
              _buildSettingCard(
                title: "Weight Unit Measurement",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ["kg", "g", "lbs", "oz", "ltr"].map((unit) {
                    final active = provider.weightSymbol == unit;
                    return ChoiceChip(
                      label: Text(unit.toUpperCase()),
                      selected: active,
                      selectedColor: primaryButtonColor,
                      backgroundColor: inputColor,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: active 
                            ? theme.colorScheme.onPrimary
                            : textPrimary, 
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
                      onSelected: (val) {
                        if (val) provider.updateWeightSymbol(unit);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Pricing Mode options
              _buildSettingCard(
                title: "Terminal Pricing Mode",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("By Weight / Volume")),
                        selected: provider.pricingMode == 'weight',
                        selectedColor: primaryButtonColor,
                        backgroundColor: inputColor,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: provider.pricingMode == 'weight' 
                              ? theme.colorScheme.onPrimary
                              : textPrimary, 
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
                        onSelected: (val) {
                          if (val) provider.updatePricingMode('weight');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("By Fixed Quantity")),
                        selected: provider.pricingMode == 'stock',
                        selectedColor: primaryButtonColor,
                        backgroundColor: inputColor,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: provider.pricingMode == 'stock' 
                              ? theme.colorScheme.onPrimary
                              : textPrimary, 
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
                        onSelected: (val) {
                          if (val) provider.updatePricingMode('stock');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Biometric option
              _buildSettingCard(
                title: "Biometric Protection",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: SwitchListTile(
                  title: Text("Enable Fingerprint / Face ID", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text("Use biometric scan at login screen", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                  value: provider.biometricEnabled,
                  onChanged: (val) => _toggleBiometrics(provider, val),
                  activeThumbColor: primaryButtonColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 14),

              // Performance Option
              _buildSettingCard(
                title: "Performance Settings",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: SwitchListTile(
                  title: Text("Performance Mode (Battery Saver)", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text("Disables background animations and transitions to improve fluidity on low-end devices", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                  value: provider.optimizePerformance,
                  onChanged: (val) => provider.updateOptimizePerformance(val),
                  activeThumbColor: primaryButtonColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 14),

              // Store Customization Card
              _buildSettingCard(
                title: "Store Customization",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _shopNameController,
                      style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Shop Name",
                        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: inputColor,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryButtonColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _shopTaglineController,
                      style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Tagline / Receipt Header",
                        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: inputColor,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryButtonColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _shopAddressController,
                      style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Shop Address",
                        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: inputColor,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryButtonColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _shopPhoneController,
                      style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Shop Phone Number",
                        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: inputColor,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryButtonColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    
                    // Logo Picker Row
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: inputColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          child: _selectedLogoPath != null && File(_selectedLogoPath!).existsSync()
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_selectedLogoPath!),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(Icons.store_rounded, color: textSecondary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Receipt Logo", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("Recommended: 256x256 monochrome PNG", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setState(() {
                                _selectedLogoPath = image.path;
                              });
                            }
                          },
                          icon: Icon(Icons.photo_library_rounded, size: 16, color: primaryButtonColor),
                          label: Text("Browse", style: GoogleFonts.plusJakartaSans(color: primaryButtonColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (_selectedLogoPath != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                            onPressed: () {
                              setState(() {
                                _selectedLogoPath = null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryButtonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await SettingsService.setShopName(_shopNameController.text.trim());
                        await SettingsService.setShopTagline(_shopTaglineController.text.trim());
                        await SettingsService.setShopAddress(_shopAddressController.text.trim());
                        await SettingsService.setShopPhone(_shopPhoneController.text.trim());
                        await SettingsService.setShopLogoPath(_selectedLogoPath);
                        _showSnackBar("Store settings updated successfully.");
                      },
                      child: Text("Save Store Config", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Receipt Printer Settings
              _buildSettingCard(
                title: "Receipt Printer Setup",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      title: Text("Direct POS Printing", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text("Print receipts directly via Bluetooth or WiFi without system print dialogs", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                      value: provider.directPrintEnabled,
                      onChanged: (val) => provider.toggleDirectPrint(val),
                      activeThumbColor: primaryButtonColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (provider.directPrintEnabled) ...[
                      const SizedBox(height: 12),
                      // Paper Width Selector
                      Text("Paper Width", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => provider.updatePaperWidth('58mm'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: provider.paperWidth == '58mm' ? primaryButtonColor.withValues(alpha: 0.15) : inputColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: provider.paperWidth == '58mm' ? primaryButtonColor : border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "58mm (Standard)",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: provider.paperWidth == '58mm' ? primaryButtonColor : textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => provider.updatePaperWidth('80mm'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: provider.paperWidth == '80mm' ? primaryButtonColor.withValues(alpha: 0.15) : inputColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: provider.paperWidth == '80mm' ? primaryButtonColor : border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "80mm (Wide)",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: provider.paperWidth == '80mm' ? primaryButtonColor : textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Connection Type Tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: inputColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => provider.updatePrinterType('bluetooth'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: provider.printerType == 'bluetooth' ? cardColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.bluetooth_rounded, size: 16, color: provider.printerType == 'bluetooth' ? primaryButtonColor : textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Bluetooth",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: provider.printerType == 'bluetooth' ? textPrimary : textSecondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => provider.updatePrinterType('wifi'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: provider.printerType == 'wifi' ? cardColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.wifi_rounded, size: 16, color: provider.printerType == 'wifi' ? primaryButtonColor : textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          "WiFi / Network",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: provider.printerType == 'wifi' ? textPrimary : textSecondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            provider.printerConnected
                                ? "Connected: ${provider.selectedPrinterName ?? provider.selectedPrinterAddress ?? 'Printer'}"
                                : "Status: Disconnected",
                            style: GoogleFonts.plusJakartaSans(
                              color: provider.printerConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: (provider.isScanning || provider.isWifiScanning)
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.sync_rounded, color: primaryButtonColor),
                            onPressed: (provider.isScanning || provider.isWifiScanning) ? null : () => provider.scanPrinters(),
                            tooltip: "Scan Printers",
                          )
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Bluetooth Device List
                      if (provider.printerType == 'bluetooth') ...[
                        if (provider.pairedDevices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "No paired Bluetooth printers found.\nPlease pair your thermal printer in Android Bluetooth Settings first.",
                              style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 140),
                            decoration: BoxDecoration(
                              color: inputColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: provider.pairedDevices.length,
                              itemBuilder: (ctx, idx) {
                                final BluetoothDevice dev = provider.pairedDevices[idx];
                                final isCurrent = provider.selectedPrinterAddress == dev.address;
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    dev.name ?? "Unknown Device",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textPrimary,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(dev.address ?? "", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                                  trailing: isCurrent
                                      ? Icon(Icons.check_circle_rounded, color: primaryButtonColor)
                                      : null,
                                  onTap: () async {
                                    final success = await provider.selectPrinter('bluetooth', dev.name ?? "Bluetooth Printer", dev.address ?? "");
                                    if (success) {
                                      _showSnackBar("Connected and test receipt printed.");
                                    } else {
                                      _showSnackBar("Failed to connect to printer.");
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],

                      // WiFi Setup Panels
                      if (provider.printerType == 'wifi') ...[
                        // Manual input Form
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _wifiIpController,
                                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: "Printer IP Address",
                                  labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                                  isDense: true,
                                  filled: true,
                                  fillColor: inputColor,
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryButtonColor)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                keyboardType: TextInputType.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _wifiPortController,
                                style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: "Port",
                                  labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                                  isDense: true,
                                  filled: true,
                                  fillColor: inputColor,
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryButtonColor)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryButtonColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final ip = _wifiIpController.text.trim();
                            final portStr = _wifiPortController.text.trim();
                            final port = int.tryParse(portStr) ?? 9100;
                            if (ip.isEmpty) {
                              _showSnackBar("Please enter a valid IP address.");
                              return;
                            }
                            final success = await provider.selectPrinter('wifi', "WiFi Printer ($ip)", ip, port: port);
                            if (success) {
                              _showSnackBar("Connected to WiFi printer and printed test page.");
                            } else {
                              _showSnackBar("Could not connect to WiFi printer at $ip:$port");
                            }
                          },
                          child: Text("Connect Printer", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(height: 16),

                        // Discovered Network list
                        Text("Discovered WiFi Printers", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (provider.isWifiScanning)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          )
                        else if (provider.discoveredWifiIPs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "No network printers discovered.\nVerify the printer is turned on, connected to the same WiFi network, and uses port 9100.",
                              style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                            ),
                          )
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            decoration: BoxDecoration(
                              color: inputColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: provider.discoveredWifiIPs.length,
                              itemBuilder: (ctx, idx) {
                                final ip = provider.discoveredWifiIPs[idx];
                                final isCurrent = provider.selectedPrinterAddress == ip && provider.printerType == 'wifi';
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    "WiFi POS Printer ($ip)",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textPrimary,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text("Port: 9100", style: GoogleFonts.inter(color: textSecondary, fontSize: 11)),
                                  trailing: isCurrent
                                      ? Icon(Icons.check_circle_rounded, color: primaryButtonColor)
                                      : null,
                                  onTap: () async {
                                    _wifiIpController.text = ip;
                                    final success = await provider.selectPrinter('wifi', "WiFi Printer ($ip)", ip, port: 9100);
                                    if (success) {
                                      _showSnackBar("Connected and test receipt printed.");
                                    } else {
                                      _showSnackBar("Failed to connect to WiFi printer.");
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],

                      // Test Receipt Action Button
                      if (provider.printerConnected) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: inputColor,
                            foregroundColor: textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final success = await provider.selectPrinter(
                              provider.printerType,
                              provider.selectedPrinterName ?? "Printer",
                              provider.selectedPrinterAddress ?? "",
                              port: provider.printerPort,
                            );
                            if (!success) {
                              _showSnackBar("Test print failed. Please reconnect.");
                            }
                          },
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: Text("Send Test Print", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Cloud Sync Troubleshooting
              _buildSettingCard(
                title: "Cloud Sync Troubleshooting",
                color: cardColor,
                border: border,
                textPrimary: textPrimary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (provider.lastSyncError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0x20EF4444)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFEF4444),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Last Sync Error:\n${provider.lastSyncError.toString()}",
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      "If the cloud sync status is stuck (yellow dot in the header), clearing the sync queue will discard stuck background writes and re-fetch clean data from the cloud.",
                      style: GoogleFonts.plusJakartaSans(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0x15EF4444)
                            : const Color(0xFFFEF2F2),
                        foregroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0x30EF4444)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: provider.syncing ? null : () => _confirmResetSync(provider),
                      icon: provider.syncing 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                              ),
                            )
                          : const Icon(Icons.sync_problem_rounded, size: 18),
                      label: Text(
                        provider.syncing ? "Resetting Queue..." : "Reset Sync Queue",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // About app
              Center(
                child: Column(
                  children: [
                    Text("NexPOS", style: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text("v1.0.0", style: GoogleFonts.inter(color: textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse("https://tillnex.space");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(
                        "powered by tillnex.space",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6366F1),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse("https://wa.me/16677788789");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            "Support: +16677788789",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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

  Widget _buildSettingCard({required String title, required Widget child, required Color color, required Color border, required Color textPrimary}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
