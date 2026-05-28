import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  static late SharedPreferences _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Local caching getters/setters
  static String getTheme() => _prefs.getString('appTheme') ?? 'light';
  static Future<void> setTheme(String value) => _prefs.setString('appTheme', value);

  static double getTaxRate() => _prefs.getDouble('taxRate') ?? 0.0;
  static Future<void> setTaxRate(double value) => _prefs.setDouble('taxRate', value);

  static double getDefaultDiscount() => _prefs.getDouble('defaultDiscount') ?? 0.0;
  static Future<void> setDefaultDiscount(double value) => _prefs.setDouble('defaultDiscount', value);

  static String getWeightSymbol() => _prefs.getString('weightSymbol') ?? 'kg';
  static Future<void> setWeightSymbol(String value) => _prefs.setString('weightSymbol', value);

  static String getPricingMode() => _prefs.getString('pricingMode') ?? 'weight';
  static Future<void> setPricingMode(String value) => _prefs.setString('pricingMode', value);

  static bool getBiometricEnabled() => _prefs.getBool('biometricEnabled') ?? false;
  static Future<void> setBiometricEnabled(bool value) => _prefs.setBool('biometricEnabled', value);

  static double getCashBalance() => _prefs.getDouble('cash_balance') ?? 0.0;
  static Future<void> setCashBalance(double value) => _prefs.setDouble('cash_balance', value);

  static bool getOptimizePerformance() => _prefs.getBool('optimizePerformance') ?? false;
  static Future<void> setOptimizePerformance(bool value) => _prefs.setBool('optimizePerformance', value);

  static String? getBluetoothPrinterAddress() => _prefs.getString('bluetoothPrinterAddress');
  static Future<void> setBluetoothPrinterAddress(String? value) => value == null ? _prefs.remove('bluetoothPrinterAddress') : _prefs.setString('bluetoothPrinterAddress', value);

  static String? getBluetoothPrinterName() => _prefs.getString('bluetoothPrinterName');
  static Future<void> setBluetoothPrinterName(String? value) => value == null ? _prefs.remove('bluetoothPrinterName') : _prefs.setString('bluetoothPrinterName', value);

  static bool getDirectPrintEnabled() => _prefs.getBool('directPrintEnabled') ?? false;
  static Future<void> setDirectPrintEnabled(bool value) => _prefs.setBool('directPrintEnabled', value);

  static String getPrinterType() => _prefs.getString('printerType') ?? 'bluetooth';
  static Future<void> setPrinterType(String value) => _prefs.setString('printerType', value);

  static int getPrinterPort() => _prefs.getInt('printerPort') ?? 9100;
  static Future<void> setPrinterPort(int value) => _prefs.setInt('printerPort', value);

  static String getPaperWidth() => _prefs.getString('paperWidth') ?? '58mm';
  static Future<void> setPaperWidth(String value) => _prefs.setString('paperWidth', value);

  static String getShopName() => _prefs.getString('shopName') ?? 'NexPOS';
  static Future<void> setShopName(String value) => _prefs.setString('shopName', value);

  static String getShopAddress() => _prefs.getString('shopAddress') ?? '';
  static Future<void> setShopAddress(String value) => _prefs.setString('shopAddress', value);

  static String getShopPhone() => _prefs.getString('shopPhone') ?? '';
  static Future<void> setShopPhone(String value) => _prefs.setString('shopPhone', value);

  static String getShopTagline() => _prefs.getString('shopTagline') ?? '';
  static Future<void> setShopTagline(String value) => _prefs.setString('shopTagline', value);

  static String? getShopLogoPath() => _prefs.getString('shopLogoPath');
  static Future<void> setShopLogoPath(String? value) => value == null ? _prefs.remove('shopLogoPath') : _prefs.setString('shopLogoPath', value);

  static String? getLastLoggedInEmail() => _prefs.getString('lastLoggedInEmail');
  static Future<void> setLastLoggedInEmail(String email) => _prefs.setString('lastLoggedInEmail', email);

  /// Synchronize a key-value setting with Firestore
  static Future<void> syncSettingToCloud(String key, dynamic value) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final jsonValue = jsonEncode(value);
      final docId = "${userId}_$key";
      await FirebaseFirestore.instance.collection('settings').doc(docId).set({
        'user_id': userId,
        'key': key,
        'value': jsonValue,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("syncSettingToCloud error: $e");
    }
  }

  /// Pull all settings for current user from Firestore and update local cache
  static Future<void> pullSettingsFromCloud() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('settings')
          .where('user_id', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        final row = doc.data();
        final String key = row['key']?.toString() ?? '';
        var rawValue = row['value'];
        dynamic value = rawValue;

        if (rawValue is String) {
          try {
            value = jsonDecode(rawValue);
          } catch (_) {
            value = rawValue;
          }
        }

        switch (key) {
          case 'appTheme':
            await setTheme(value.toString());
            break;
          case 'taxRate':
            await setTaxRate((num.tryParse(value.toString()) ?? 0.0).toDouble());
            break;
          case 'defaultDiscount':
            await setDefaultDiscount((num.tryParse(value.toString()) ?? 0.0).toDouble());
            break;
          case 'weightSymbol':
            await setWeightSymbol(value.toString());
            break;
          case 'pricingMode':
            await setPricingMode(value.toString());
            break;
          case 'biometricEnabled':
            await setBiometricEnabled(value.toString() == 'true');
            break;
          case 'cash_balance':
            await setCashBalance((num.tryParse(value.toString()) ?? 0.0).toDouble());
            break;
        }
      }
    } catch (e) {
      debugPrint("pullSettingsFromCloud error: $e");
    }
  }

  /// Push all local settings to Firestore
  static Future<void> pushSettingsToCloud() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final keys = ['appTheme', 'taxRate', 'defaultDiscount', 'weightSymbol', 'pricingMode', 'biometricEnabled', 'cash_balance'];
    for (final k in keys) {
      dynamic val;
      if (k == 'appTheme') val = getTheme();
      if (k == 'taxRate') val = getTaxRate();
      if (k == 'defaultDiscount') val = getDefaultDiscount();
      if (k == 'weightSymbol') val = getWeightSymbol();
      if (k == 'pricingMode') val = getPricingMode();
      if (k == 'biometricEnabled') val = getBiometricEnabled();
      if (k == 'cash_balance') val = getCashBalance();

      if (val != null) {
        await syncSettingToCloud(k, val);
      }
    }
  }
}
