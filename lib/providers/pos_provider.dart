import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/settings_service.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/printer_service.dart';

class POSProvider extends ChangeNotifier {
  String _theme = 'light';
  String get theme => _theme;

  // Settings properties
  double _taxRate = 0.0;
  double get taxRate => _taxRate;

  double _defaultDiscount = 0.0;
  double get defaultDiscount => _defaultDiscount;

  String _weightSymbol = 'kg';
  String get weightSymbol => _weightSymbol;

  String _pricingMode = 'weight'; // weight or stock
  String get pricingMode => _pricingMode;

  // Bluetooth and WiFi printer properties
  bool _directPrintEnabled = false;
  bool get directPrintEnabled => _directPrintEnabled;

  String? _selectedPrinterAddress;
  String? get selectedPrinterAddress => _selectedPrinterAddress;

  String? _selectedPrinterName;
  String? get selectedPrinterName => _selectedPrinterName;

  bool _printerConnected = false;
  bool get printerConnected => _printerConnected;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDevice> get pairedDevices => _pairedDevices;

  String _printerType = 'bluetooth'; // 'bluetooth' or 'wifi'
  String get printerType => _printerType;

  int _printerPort = 9100;
  int get printerPort => _printerPort;

  String _paperWidth = '58mm'; // '58mm' or '80mm'
  String get paperWidth => _paperWidth;

  List<String> _discoveredWifiIPs = [];
  List<String> get discoveredWifiIPs => _discoveredWifiIPs;

  bool _isWifiScanning = false;
  bool get isWifiScanning => _isWifiScanning;

  final PrinterService _printerService = PrinterService();

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  double _cashBalance = 0.0;
  double get cashBalance => _cashBalance;

  bool _optimizePerformance = false;
  bool get optimizePerformance => _optimizePerformance;

  // POS State properties
  List<Product> _products = [];
  List<Product> get products => _products;

  List<Product> _filteredProducts = [];
  List<Product> get filteredProducts => _filteredProducts;

  final List<CartItem> _cart = [];
  List<CartItem> get cart => _cart;

  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  List<Supplier> _suppliers = [];
  List<Supplier> get suppliers => _suppliers;

  List<CashTransaction> _cashTransactions = [];
  List<CashTransaction> get cashTransactions => _cashTransactions;

  List<CreditTransaction> _creditTransactions = [];
  List<CreditTransaction> get creditTransactions => _creditTransactions;

  bool _loadingProducts = false;
  bool get loadingProducts => _loadingProducts;

  bool _syncing = false;
  bool get syncing => _syncing;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  // Stream Subscriptions for Cloud + Local real-time sync
  StreamSubscription? _productsSub;
  StreamSubscription? _customersSub;
  StreamSubscription? _suppliersSub;
  StreamSubscription? _transactionsSub;
  StreamSubscription? _creditTransactionsSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _syncErrorSub;

  bool _isDeviceOnline = true;
  bool get isDeviceOnline => _isDeviceOnline;

  bool _hasPendingWrites = false;
  bool get hasPendingWrites => _hasPendingWrites;

  SyncError? _lastSyncError;
  SyncError? get lastSyncError => _lastSyncError;

  POSProvider() {
    loadSettings();
  }

  // Load Settings from Local & Cloud
  Future<void> loadSettings() async {
    _theme = SettingsService.getTheme();
    _taxRate = SettingsService.getTaxRate();
    _defaultDiscount = SettingsService.getDefaultDiscount();
    _weightSymbol = SettingsService.getWeightSymbol();
    _pricingMode = SettingsService.getPricingMode();
    _biometricEnabled = SettingsService.getBiometricEnabled();
    _cashBalance = SettingsService.getCashBalance();
    _optimizePerformance = SettingsService.getOptimizePerformance();
    
    // Printer Settings
    _directPrintEnabled = SettingsService.getDirectPrintEnabled();
    _selectedPrinterAddress = SettingsService.getBluetoothPrinterAddress();
    _selectedPrinterName = SettingsService.getBluetoothPrinterName();
    _printerType = SettingsService.getPrinterType();
    _printerPort = SettingsService.getPrinterPort();
    _paperWidth = SettingsService.getPaperWidth();
    notifyListeners();

    if (_directPrintEnabled) {
      unawaited(connectToSavedPrinter());
    }

    if (userId != null) {
      await loadCachedData();
      unawaited(startSync());
    }
  }

  // Load local caches from SharedPreferences for instant responsiveness
  Future<void> loadCachedData() async {
    final uid = userId;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cachedProds = prefs.getString('cachedProducts_$uid');
      if (cachedProds != null) {
        final List<dynamic> parsed = jsonDecode(cachedProds);
        _products = parsed.map((p) => Product.fromJson(p)).toList();
        _filterProducts();
      }

      final cachedCusts = prefs.getString('cachedCustomers_$uid');
      if (cachedCusts != null) {
        final List<dynamic> parsed = jsonDecode(cachedCusts);
        _customers = parsed.map((c) => Customer.fromJson(c)).toList();
      }

      final cachedSups = prefs.getString('cachedSuppliers_$uid');
      if (cachedSups != null) {
        final List<dynamic> parsed = jsonDecode(cachedSups);
        _suppliers = parsed.map((s) => Supplier.fromJson(s)).toList();
      }

      final cachedTxs = prefs.getString('cachedTransactions_$uid');
      if (cachedTxs != null) {
        final List<dynamic> parsed = jsonDecode(cachedTxs);
        _cashTransactions = parsed.map((t) => CashTransaction.fromJson(t)).toList();
      }

      final cachedCreditTxs = prefs.getString('cachedCreditTransactions_$uid');
      if (cachedCreditTxs != null) {
        final List<dynamic> parsed = jsonDecode(cachedCreditTxs);
        _creditTransactions = parsed.map((t) => CreditTransaction.fromJson(t)).toList();
      }
      
      notifyListeners();
    } catch (e) {
      print("Error loading local caches: $e");
    }
  }

  bool _productsPending = false;
  bool get productsPending => _productsPending;
  bool _customersPending = false;
  bool get customersPending => _customersPending;
  bool _suppliersPending = false;
  bool get suppliersPending => _suppliersPending;
  bool _transactionsPending = false;
  bool get transactionsPending => _transactionsPending;
  bool _creditTransactionsPending = false;
  bool get creditTransactionsPending => _creditTransactionsPending;
  bool _settingsPending = false;
  bool get settingsPending => _settingsPending;

  void _updatePendingWritesState() {
    final pending = _productsPending || _customersPending || _suppliersPending || _transactionsPending || _creditTransactionsPending || _settingsPending;
    if (_hasPendingWrites != pending) {
      _hasPendingWrites = pending;
      notifyListeners();
    }
  }

  // Start Real-time Cloud + Local Sync listeners
  Future<void> startSync() async {
    final uid = userId;
    if (uid == null) return;

    if (_directPrintEnabled) {
      unawaited(connectToSavedPrinter());
    }

    _syncing = true;
    _lastSyncError = null;
    notifyListeners();

    // 1. Monitor device connection state
    if (kIsWeb) {
      _isDeviceOnline = true;
      unawaited(FirebaseFirestore.instance.enableNetwork());
    } else {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        _isDeviceOnline = connectivityResult != ConnectivityResult.none;
        if (_isDeviceOnline) {
          unawaited(FirebaseFirestore.instance.enableNetwork());
        } else {
          unawaited(FirebaseFirestore.instance.disableNetwork());
        }
      } catch (_) {
        _isDeviceOnline = false;
      }
    }
    notifyListeners();

    _connectivitySub?.cancel();
    if (!kIsWeb) {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
        final online = result != ConnectivityResult.none;
        if (online != _isDeviceOnline) {
          _isDeviceOnline = online;
          if (online) {
            FirebaseFirestore.instance.enableNetwork().catchError((e) {
              print("Error enabling firestore network: $e");
            });
          } else {
            FirebaseFirestore.instance.disableNetwork().catchError((e) {
              print("Error disabling firestore network: $e");
            });
          }
          notifyListeners();
        }
      });
    }

    _syncErrorSub?.cancel();
    _syncErrorSub = FirebaseService.errorStream.listen((syncError) {
      _lastSyncError = syncError;
      notifyListeners();
    });

    // 2. Stop any existing listeners first
    await stopSync(clearLists: false);

    // 3. Start real-time Firestore listeners (instant offline reads, sync on change)
    
    // settings listener
    _settingsSub = FirebaseFirestore.instance
        .collection('settings')
        .where('user_id', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      _settingsPending = snapshot.metadata.hasPendingWrites;
      _updatePendingWritesState();

      for (final doc in snapshot.docs) {
        final row = doc.data();
        final String key = row['key']?.toString() ?? '';
        var rawValue = row['value'];
        dynamic value = rawValue;
        if (rawValue is String) {
          try {
            value = jsonDecode(rawValue);
          } catch (_) {}
        }
        
        switch (key) {
          case 'appTheme':
            _theme = value.toString();
            SettingsService.setTheme(_theme);
            break;
          case 'taxRate':
            _taxRate = (num.tryParse(value.toString()) ?? 0.0).toDouble();
            SettingsService.setTaxRate(_taxRate);
            break;
          case 'defaultDiscount':
            _defaultDiscount = (num.tryParse(value.toString()) ?? 0.0).toDouble();
            SettingsService.setDefaultDiscount(_defaultDiscount);
            break;
          case 'weightSymbol':
            _weightSymbol = value.toString();
            SettingsService.setWeightSymbol(_weightSymbol);
            break;
          case 'pricingMode':
            _pricingMode = value.toString();
            SettingsService.setPricingMode(_pricingMode);
            break;
          case 'biometricEnabled':
            _biometricEnabled = value.toString() == 'true';
            SettingsService.setBiometricEnabled(_biometricEnabled);
            break;
          case 'cash_balance':
            _cashBalance = (num.tryParse(value.toString()) ?? 0.0).toDouble();
            SettingsService.setCashBalance(_cashBalance);
            break;
        }
      }
      notifyListeners();
    }, onError: (e) => print("Settings sync error: $e"));

    // products listener
    _loadingProducts = true;
    notifyListeners();
    _productsSub = FirebaseFirestore.instance
        .collection('products')
        .where('user_id', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      _productsPending = snapshot.metadata.hasPendingWrites;
      _updatePendingWritesState();

      _loadingProducts = false;
      final List<Map<String, dynamic>> rows = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return data;
      }).toList();

      _products = rows.map((p) => Product.fromJson(p)).toList();
      _filterProducts();
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedProducts_$uid', jsonEncode(rows));
      });
    }, onError: (e) {
      _loadingProducts = false;
      notifyListeners();
      print("Products sync error: $e");
    });

    // customers listener
    _customersSub = FirebaseFirestore.instance
        .collection('customers')
        .where('user_id', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      _customersPending = snapshot.metadata.hasPendingWrites;
      _updatePendingWritesState();

      final List<Map<String, dynamic>> rows = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return data;
      }).toList();

      _customers = rows.map((c) => Customer.fromJson(c)).toList();
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedCustomers_$uid', jsonEncode(rows));
      });
    }, onError: (e) => print("Customers sync error: $e"));

    // suppliers listener
    _suppliersSub = FirebaseFirestore.instance
        .collection('suppliers')
        .where('user_id', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      _suppliersPending = snapshot.metadata.hasPendingWrites;
      _updatePendingWritesState();

      final List<Map<String, dynamic>> rows = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return data;
      }).toList();

      _suppliers = rows.map((s) => Supplier.fromJson(s)).toList();
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedSuppliers_$uid', jsonEncode(rows));
      });
    }, onError: (e) => print("Suppliers sync error: $e"));

    // cash transactions listener
    _transactionsSub = FirebaseFirestore.instance
        .collection('cash_transactions')
        .where('user_id', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      _transactionsPending = snapshot.metadata.hasPendingWrites;
      _updatePendingWritesState();

      final List<Map<String, dynamic>> rows = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return data;
      }).toList();

      rows.sort((a, b) {
        final dateA = a['date'] != null ? DateTime.tryParse(a['date'].toString()) ?? DateTime.now() : DateTime.now();
        final dateB = b['date'] != null ? DateTime.tryParse(b['date'].toString()) ?? DateTime.now() : DateTime.now();
        return dateB.compareTo(dateA);
      });

      final limitedRows = rows.take(100).toList();
      _cashTransactions = limitedRows.map((t) => CashTransaction.fromJson(t)).toList();
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedTransactions_$uid', jsonEncode(limitedRows));
        prefs.setDouble('cash_balance_$uid', _cashBalance);
      });
    }, onError: (e) => print("Transactions sync error: $e"));

    // credit transactions listener
    _creditTransactionsSub = FirebaseFirestore.instance
        .collection('credit_transactions')
        .where('user_id', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      _creditTransactionsPending = snapshot.metadata.hasPendingWrites;
      _updatePendingWritesState();

      final List<Map<String, dynamic>> rows = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        return data;
      }).toList();

      rows.sort((a, b) {
        final dateA = a['date'] != null ? DateTime.tryParse(a['date'].toString()) ?? DateTime.now() : DateTime.now();
        final dateB = b['date'] != null ? DateTime.tryParse(b['date'].toString()) ?? DateTime.now() : DateTime.now();
        return dateB.compareTo(dateA);
      });

      _creditTransactions = rows.map((t) => CreditTransaction.fromJson(t)).toList();
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedCreditTransactions_$uid', jsonEncode(rows));
      });
    }, onError: (e) => print("Credit transactions sync error: $e"));

    _syncing = false;
    notifyListeners();
  }

  // Stop real-time streams
  Future<void> stopSync({bool clearLists = true}) async {
    await _productsSub?.cancel();
    await _customersSub?.cancel();
    await _suppliersSub?.cancel();
    await _transactionsSub?.cancel();
    await _creditTransactionsSub?.cancel();
    await _settingsSub?.cancel();
    await _syncErrorSub?.cancel();
    
    _productsSub = null;
    _customersSub = null;
    _suppliersSub = null;
    _transactionsSub = null;
    _creditTransactionsSub = null;
    _settingsSub = null;
    _syncErrorSub = null;
    _lastSyncError = null;

    _productsPending = false;
    _customersPending = false;
    _suppliersPending = false;
    _transactionsPending = false;
    _creditTransactionsPending = false;
    _settingsPending = false;

    if (clearLists) {
      _products = [];
      _filteredProducts = [];
      _customers = [];
      _suppliers = [];
      _cashTransactions = [];
      _creditTransactions = [];
      _cart.clear();
      _hasPendingWrites = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _customersSub?.cancel();
    _suppliersSub?.cancel();
    _transactionsSub?.cancel();
    _creditTransactionsSub?.cancel();
    _settingsSub?.cancel();
    _connectivitySub?.cancel();
    _syncErrorSub?.cancel();
    super.dispose();
  }

  // Theme Toggles
  Future<void> toggleTheme(String newTheme) async {
    _theme = newTheme;
    notifyListeners();
    await SettingsService.setTheme(newTheme);
    unawaited(SettingsService.syncSettingToCloud('appTheme', newTheme));
  }

  // Settings Setters
  Future<void> updateTaxRate(double rate) async {
    _taxRate = rate;
    notifyListeners();
    await SettingsService.setTaxRate(rate);
    unawaited(SettingsService.syncSettingToCloud('taxRate', rate));
  }

  Future<void> updateDefaultDiscount(double discount) async {
    _defaultDiscount = discount;
    notifyListeners();
    await SettingsService.setDefaultDiscount(discount);
    unawaited(SettingsService.syncSettingToCloud('defaultDiscount', discount));
  }

  Future<void> updateWeightSymbol(String symbol) async {
    _weightSymbol = symbol;
    notifyListeners();
    await SettingsService.setWeightSymbol(symbol);
    unawaited(SettingsService.syncSettingToCloud('weightSymbol', symbol));
  }

  Future<void> updatePricingMode(String mode) async {
    _pricingMode = mode;
    notifyListeners();
    await SettingsService.setPricingMode(mode);
    unawaited(SettingsService.syncSettingToCloud('pricingMode', mode));
  }

  Future<void> updateBiometrics(bool enabled) async {
    _biometricEnabled = enabled;
    notifyListeners();
    await SettingsService.setBiometricEnabled(enabled);
    unawaited(SettingsService.syncSettingToCloud('biometricEnabled', enabled));
  }

  Future<void> updateOptimizePerformance(bool value) async {
    _optimizePerformance = value;
    notifyListeners();
    await SettingsService.setOptimizePerformance(value);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filterProducts();
  }

  void _filterProducts() {
    if (_searchQuery.trim().isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      final q = _searchQuery.toLowerCase().trim();
      _filteredProducts = _products.where((p) {
        return p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  // Cart Management
  double get cartTotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);

  void addToCart(Product product) {
    final stock = product.stock;
    final step = product.pricingMode == 'weight' ? 0.1 : 1.0;

    if (stock <= 0) {
      return;
    }

    final existingIdx = _cart.indexWhere((it) => it.product.id == product.id);
    if (existingIdx != -1) {
      final existingItem = _cart[existingIdx];
      final newQty = double.parse((existingItem.quantity + step).toStringAsFixed(1));
      if (newQty > stock) {
        existingItem.quantity = stock;
      } else {
        existingItem.quantity = newQty;
      }
    } else {
      final initialQty = step > stock ? stock : step;
      _cart.add(CartItem(product: product, quantity: initialQty));
    }
    notifyListeners();
  }

  void decreaseCartItem(Product product) {
    final step = product.pricingMode == 'weight' ? 0.1 : 1.0;
    final existingIdx = _cart.indexWhere((it) => it.product.id == product.id);
    if (existingIdx != -1) {
      final item = _cart[existingIdx];
      final newQty = double.parse((item.quantity - step).toStringAsFixed(1));
      if (newQty < step) {
        _cart.removeAt(existingIdx);
      } else {
        item.quantity = newQty;
      }
    }
    notifyListeners();
  }

  void increaseCartItem(Product product) {
    final stock = product.stock;
    final step = product.pricingMode == 'weight' ? 0.1 : 1.0;
    final existingIdx = _cart.indexWhere((it) => it.product.id == product.id);
    if (existingIdx != -1) {
      final item = _cart[existingIdx];
      final newQty = double.parse((item.quantity + step).toStringAsFixed(1));
      if (newQty > stock) {
        item.quantity = stock;
      } else {
        item.quantity = newQty;
      }
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.removeWhere((it) => it.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // Product CRUD (Optimistic In-Memory Updates + Background Firebase Sync)
  Future<void> saveProduct({
    String? id,
    required String code,
    required String name,
    required double salePrice,
    required double costPrice,
    required double stock,
    String pricingMode = 'pcs',
  }) async {
    if (userId == null) return;

    final generatedId = id ?? FirebaseFirestore.instance.collection('products').doc().id;
    final productData = {
      'id': generatedId,
      'user_id': userId,
      'code': code,
      'name': name,
      'price': salePrice,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'stock': stock,
      'pricing_mode': pricingMode,
      'added_at': DateTime.now().toIso8601String(),
    };

    // 1. Optimistic Update: Update in-memory state instantly
    final newProduct = Product.fromJson(productData);
    if (id != null) {
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = newProduct;
      }
    } else {
      _products.add(newProduct);
    }
    _filterProducts();
    notifyListeners();

    // 2. Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedProducts_$userId', jsonEncode(_products.map((p) => p.toJson()).toList()));
    });

    // 3. Write to Firestore in background (unawaited)
    if (id != null) {
      unawaited(FirebaseService.upsertRow('products', productData));
    } else {
      unawaited(FirebaseService.insertRow('products', productData));
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (userId == null) return;

    // 1. Optimistic Update: Update in-memory state instantly
    _products.removeWhere((p) => p.id == productId);
    _filterProducts();
    notifyListeners();

    // 2. Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedProducts_$userId', jsonEncode(_products.map((p) => p.toJson()).toList()));
    });

    // 3. Write to Firestore in background (unawaited)
    unawaited(FirebaseService.deleteRow('products', 'id', productId));
  }

  String generateProductCode() {
    int maxVal = 0;
    final codeRegex = RegExp(r'^P(\d+)$');
    for (final p in _products) {
      final match = codeRegex.firstMatch(p.code.toUpperCase());
      if (match != null) {
        final n = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (n > maxVal) maxVal = n;
      }
    }
    return 'P${maxVal + 1}';
  }



  Future<void> recordCashTransaction({
    required String type, // IN or OUT
    required double amount,
    required String purpose,
  }) async {
    final uid = userId;
    if (uid == null) return;

    final newBalance = type == 'IN' ? _cashBalance + amount : _cashBalance - amount;
    if (newBalance < 0) throw Exception("Insufficient drawer balance.");

    final txId = FirebaseFirestore.instance.collection('cash_transactions').doc().id;
    final tx = CashTransaction(
      id: txId,
      type: type,
      amount: amount,
      purpose: purpose,
      date: DateTime.now(),
      balanceAfter: newBalance,
      userId: uid,
    );

    // 1. Optimistic Update: Update local properties instantly
    _cashTransactions.insert(0, tx);
    if (_cashTransactions.length > 100) {
      _cashTransactions = _cashTransactions.take(100).toList();
    }
    _cashBalance = newBalance;
    notifyListeners();

    // 2. Cache locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedTransactions_$uid', jsonEncode(_cashTransactions.map((t) => t.toJson()).toList()));
      prefs.setDouble('cash_balance_$uid', _cashBalance);
    });

    // 3. Update local SettingsService cache
    await SettingsService.setCashBalance(newBalance);

    // 4. Save to Firestore in background (unawaited)
    unawaited(FirebaseService.insertRow('cash_transactions', tx.toJson()));
    unawaited(SettingsService.syncSettingToCloud('cash_balance', newBalance));
  }

  Future<void> resetCashDrawer() async {
    final uid = userId;
    if (uid == null) return;

    // 1. Optimistic Update: Update in-memory state instantly
    _cashTransactions.clear();
    _cashBalance = 0.0;
    notifyListeners();

    // 2. Cache locally in SharedPreferences in background
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cachedTransactions_$uid');
    await prefs.setDouble('cash_balance_$uid', 0.0);

    // 3. Update local SettingsService cache
    await SettingsService.setCashBalance(0.0);

    // 4. Write to Firestore in background (unawaited)
    unawaited(FirebaseService.deleteRow('cash_transactions', 'user_id', uid));
    unawaited(SettingsService.syncSettingToCloud('cash_balance', 0.0));
  }



  Future<void> saveCustomer({
    String? id,
    required String name,
    required String phone,
    String? address,
    int totalOrders = 0,
    double totalSpent = 0,
    double creditBalance = 0.0,
    double creditLimit = 50000.0,
  }) async {
    if (userId == null) return;

    final generatedId = id ?? FirebaseFirestore.instance.collection('customers').doc().id;
    final row = {
      'id': generatedId,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'address': address,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'credit_balance': creditBalance,
      'credit_limit': creditLimit,
    };

    // 1. Optimistic Update: Update in-memory state instantly
    final newCustomer = Customer.fromJson(row);
    if (id != null) {
      final index = _customers.indexWhere((c) => c.id == id);
      if (index != -1) {
        _customers[index] = newCustomer;
      }
    } else {
      _customers.add(newCustomer);
    }
    notifyListeners();

    // 2. Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedCustomers_$userId', jsonEncode(_customers.map((c) => c.toJson()).toList()));
    });

    // 3. Write to Firestore in background (unawaited)
    if (id != null) {
      unawaited(FirebaseService.upsertRow('customers', row));
    } else {
      unawaited(FirebaseService.insertRow('customers', row));
    }
  }

  Future<void> deleteCustomer(String id) async {
    if (userId == null) return;

    // 1. Optimistic Update: Update in-memory state instantly
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();

    // 2. Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedCustomers_$userId', jsonEncode(_customers.map((c) => c.toJson()).toList()));
    });

    // 3. Write to Firestore in background (unawaited)
    unawaited(FirebaseService.deleteRow('customers', 'id', id));
  }



  Future<void> saveSupplier({
    String? id,
    required String name,
    required String phone,
    String? email,
    String? address,
    int totalOrders = 0,
    double totalSpent = 0,
  }) async {
    if (userId == null) return;

    final generatedId = id ?? FirebaseFirestore.instance.collection('suppliers').doc().id;
    final row = {
      'id': generatedId,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
    };

    // 1. Optimistic Update: Update in-memory state instantly
    final newSupplier = Supplier.fromJson(row);
    if (id != null) {
      final index = _suppliers.indexWhere((s) => s.id == id);
      if (index != -1) {
        _suppliers[index] = newSupplier;
      }
    } else {
      _suppliers.add(newSupplier);
    }
    notifyListeners();

    // 2. Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedSuppliers_$userId', jsonEncode(_suppliers.map((s) => s.toJson()).toList()));
    });

    // 3. Write to Firestore in background (unawaited)
    if (id != null) {
      unawaited(FirebaseService.upsertRow('suppliers', row));
    } else {
      unawaited(FirebaseService.insertRow('suppliers', row));
    }
  }

  Future<void> deleteSupplier(String id) async {
    if (userId == null) return;

    // 1. Optimistic Update: Update in-memory state instantly
    _suppliers.removeWhere((s) => s.id == id);
    notifyListeners();

    // 2. Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedSuppliers_$userId', jsonEncode(_suppliers.map((s) => s.toJson()).toList()));
    });

    // 3. Write to Firestore in background (unawaited)
    unawaited(FirebaseService.deleteRow('suppliers', 'id', id));
  }

  // Checkout Execution (Optimistic In-Memory Updates + Background Firebase Sync via Batch)
  Future<void> completeSale({
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    Customer? selectedCustomer,
    required double discountPercentage,
    required double discountAmt,
    required double taxRateVal,
    required double taxAmt,
    required double totalAmt,
    required String paymentMethod,
    required double cashReceived,
    required double changeDueAmount,
  }) async {
    final uid = userId;
    if (uid == null) return;

    if (paymentMethod == 'Credit') {
      if (customerName == 'Walk-in Customer' || selectedCustomer == null) {
        throw Exception("A registered customer must be selected for Credit (Khata) transactions.");
      }
    }

    final invoiceId = "${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}${DateTime.now().second.toString().padLeft(2, '0')}";

    // Calculate sale cost
    double totalCost = 0.0;
    for (final item in _cart) {
      totalCost += item.product.costPrice * item.quantity;
    }
    final profit = totalAmt - totalCost;

    final saleRecord = {
      'id': invoiceId,
      'date': "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}",
      'time': "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}",
      'customer': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'items': _cart.map((c) => c.toJson()).toList(),
      'subtotal': cartTotal,
      'discount': discountPercentage,
      'discount_amount': discountAmt,
      'tax_rate': taxRateVal,
      'tax': taxAmt,
      'total': totalAmt,
      'payment_method': paymentMethod,
      'amount_received': (paymentMethod == 'Cash' || paymentMethod == 'Credit') ? cashReceived : totalAmt,
      'change_due': paymentMethod == 'Cash' ? changeDueAmount : 0.0,
      'cost': totalCost,
      'profit': profit,
      'user_id': uid,
    };

    // 1. Optimistic Update: Deduct stock in-memory for all products in cart
    for (final item in _cart) {
      final index = _products.indexWhere((p) => p.id == item.product.id);
      if (index != -1) {
        final currentStock = _products[index].stock;
        final updatedStock = currentStock - item.quantity;
        final updatedProd = _products[index].copyWith(stock: updatedStock);
        _products[index] = updatedProd;
      }
    }
    _filterProducts();

    // Cache updated products locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedProducts_$uid', jsonEncode(_products.map((p) => p.toJson()).toList()));
    });

    // 2. Optimistic Update: Update customer order stats in-memory
    if (customerName != 'Walk-in Customer' && selectedCustomer != null) {
      final cIdx = _customers.indexWhere((c) => c.id == selectedCustomer.id);
      if (cIdx != -1) {
        final double creditBalanceChange = paymentMethod == 'Credit' ? totalAmt : 0.0;
        final updatedCustomer = Customer(
          id: selectedCustomer.id,
          name: selectedCustomer.name,
          phone: selectedCustomer.phone,
          address: selectedCustomer.address,
          totalOrders: selectedCustomer.totalOrders + 1,
          totalSpent: selectedCustomer.totalSpent + totalAmt,
          creditBalance: selectedCustomer.creditBalance + creditBalanceChange,
          creditLimit: selectedCustomer.creditLimit,
          userId: uid,
        );
        _customers[cIdx] = updatedCustomer;
      }

      if (paymentMethod == 'Credit') {
        final creditTxId = FirebaseFirestore.instance.collection('credit_transactions').doc().id;
        final detailsStr = _cart.map((item) {
          final formattedQty = item.product.pricingMode == 'weight'
              ? item.quantity.toStringAsFixed(1)
              : item.quantity.toStringAsFixed(0);
          final unitVal = item.product.unit ?? (item.product.pricingMode == 'weight' ? 'kg' : 'pcs');
          return "${item.product.name} (x$formattedQty $unitVal)";
        }).join(', ');

        final creditTx = CreditTransaction(
          id: creditTxId,
          customerId: selectedCustomer.id,
          type: 'PURCHASE',
          amount: totalAmt,
          date: DateTime.now().toIso8601String(),
          saleId: invoiceId,
          userId: uid,
          details: detailsStr,
        );
        _creditTransactions.insert(0, creditTx);
      }

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedCustomers_$uid', jsonEncode(_customers.map((c) => c.toJson()).toList()));
        prefs.setString('cachedCreditTransactions_$uid', jsonEncode(_creditTransactions.map((t) => t.toJson()).toList()));
      });
    }

    // 3. Optimistic Update: Update cash drawer in-memory (if cash sale)
    if (paymentMethod == 'Cash') {
      final newBalance = _cashBalance + cashReceived - changeDueAmount;
      final txInId = FirebaseFirestore.instance.collection('cash_transactions').doc().id;
      final txIn = CashTransaction(
        id: txInId,
        type: 'IN',
        amount: cashReceived,
        purpose: 'Sale #$invoiceId',
        date: DateTime.now(),
        balanceAfter: _cashBalance + cashReceived,
        userId: uid,
      );
      _cashTransactions.insert(0, txIn);

      if (changeDueAmount > 0) {
        final txOutId = FirebaseFirestore.instance.collection('cash_transactions').doc().id;
        final txOut = CashTransaction(
          id: txOutId,
          type: 'OUT',
          amount: changeDueAmount,
          purpose: 'Change #$invoiceId',
          date: DateTime.now(),
          balanceAfter: newBalance,
          userId: uid,
        );
        _cashTransactions.insert(0, txOut);
      }

      if (_cashTransactions.length > 100) {
        _cashTransactions = _cashTransactions.take(100).toList();
      }
      _cashBalance = newBalance;

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedTransactions_$uid', jsonEncode(_cashTransactions.map((t) => t.toJson()).toList()));
        prefs.setDouble('cash_balance_$uid', _cashBalance);
      });
      await SettingsService.setCashBalance(newBalance);
    }

    clearCart();
    notifyListeners();

    // 4. Trigger database writes atomically in the background using WriteBatch
    unawaited(() async {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // Save sale record
        final saleRef = FirebaseFirestore.instance.collection('sales').doc(invoiceId);
        batch.set(saleRef, saleRecord);

        // Save cash transactions and update settings cash balance
        if (paymentMethod == 'Cash') {
          final txInId = FirebaseFirestore.instance.collection('cash_transactions').doc().id;
          final txInJson = {
            'id': txInId,
            'user_id': uid,
            'type': 'IN',
            'amount': cashReceived,
            'purpose': 'Sale #$invoiceId',
            'date': DateTime.now().toIso8601String(),
            'balance_after': _cashBalance,
          };
          final txInRef = FirebaseFirestore.instance.collection('cash_transactions').doc(txInId);
          batch.set(txInRef, txInJson);

          if (changeDueAmount > 0) {
            final txOutId = FirebaseFirestore.instance.collection('cash_transactions').doc().id;
            final txOutJson = {
              'id': txOutId,
              'user_id': uid,
              'type': 'OUT',
              'amount': changeDueAmount,
              'purpose': 'Change #$invoiceId',
              'date': DateTime.now().toIso8601String(),
              'balance_after': _cashBalance,
            };
            final txOutRef = FirebaseFirestore.instance.collection('cash_transactions').doc(txOutId);
            batch.set(txOutRef, txOutJson);
          }

          // Update settings for cash balance
          final settingsRef = FirebaseFirestore.instance.collection('settings').doc("${uid}_cash_balance");
          batch.set(settingsRef, {
            'user_id': uid,
            'key': 'cash_balance',
            'value': jsonEncode(_cashBalance),
          }, SetOptions(merge: true));
        }

        // Save customer stats
        if (customerName != 'Walk-in Customer' && selectedCustomer != null) {
          final reportId = FirebaseFirestore.instance.collection('customer_reports').doc().id;
          final reportRef = FirebaseFirestore.instance.collection('customer_reports').doc(reportId);
          batch.set(reportRef, {
            'id': reportId,
            'customer': customerName,
            'phone': customerPhone,
            'date': saleRecord['date'],
            'total': totalAmt,
            'items_count': saleRecord['items'] is List ? (saleRecord['items'] as List).length : 0,
            'user_id': uid,
          });

          final custRef = FirebaseFirestore.instance.collection('customers').doc(selectedCustomer.id);
          batch.set(custRef, {
            'id': selectedCustomer.id,
            'user_id': uid,
            'name': selectedCustomer.name,
            'phone': selectedCustomer.phone,
            'address': selectedCustomer.address,
            'total_orders': selectedCustomer.totalOrders + 1,
            'total_spent': selectedCustomer.totalSpent + totalAmt,
            'credit_balance': selectedCustomer.creditBalance + (paymentMethod == 'Credit' ? totalAmt : 0.0),
            'credit_limit': selectedCustomer.creditLimit,
          }, SetOptions(merge: true));

          if (paymentMethod == 'Credit') {
            final creditTxId = FirebaseFirestore.instance.collection('credit_transactions').doc().id;
            final creditTxJson = {
              'id': creditTxId,
              'customer_id': selectedCustomer.id,
              'type': 'PURCHASE',
              'amount': totalAmt,
              'date': DateTime.now().toIso8601String(),
              'sale_id': invoiceId,
              'user_id': uid,
            };
            final creditTxRef = FirebaseFirestore.instance.collection('credit_transactions').doc(creditTxId);
            batch.set(creditTxRef, creditTxJson);
          }
        }

        // Deduct stock in Firestore
        for (final item in saleRecord['items'] as List) {
          final prodId = item['id'].toString();
          final pIndex = _products.indexWhere((p) => p.id == prodId);
          if (pIndex != -1) {
            final prodRef = FirebaseFirestore.instance.collection('products').doc(prodId);
            batch.update(prodRef, {'stock': _products[pIndex].stock});
          }
        }

        await batch.commit();
        print("Background sale completion sync batch committed.");
      } catch (e) {
        print("Background sale completion sync batch error: $e");
        FirebaseService.reportError('sales_batch', 'commit', e);
      }
    }());
  }

  Future<void> recordCreditPayment(String customerId, double amount, {String paymentMethod = 'Cash'}) async {
    final uid = userId;
    if (uid == null) return;

    final customerIndex = _customers.indexWhere((c) => c.id == customerId);
    if (customerIndex == -1) throw Exception("Customer not found.");

    final customer = _customers[customerIndex];
    if (amount <= 0) throw Exception("Invalid payment amount.");

    final double newBalance = customer.creditBalance - amount;

    // Create unique IDs
    final creditTxId = FirebaseFirestore.instance.collection('credit_transactions').doc().id;
    final cashTxId = FirebaseFirestore.instance.collection('cash_transactions').doc().id;

    final creditTx = CreditTransaction(
      id: creditTxId,
      customerId: customerId,
      type: 'PAYMENT',
      amount: amount,
      date: DateTime.now().toIso8601String(),
      userId: uid,
      paymentMethod: paymentMethod,
    );

    // 1. Optimistic Update: Update Customer & Credit Transaction in-memory
    _customers[customerIndex] = customer.copyWith(creditBalance: newBalance);
    _creditTransactions.insert(0, creditTx);

    CashTransaction? cashTx;
    double updatedCashBalance = _cashBalance;

    if (paymentMethod == 'Cash') {
      updatedCashBalance = _cashBalance + amount;
      cashTx = CashTransaction(
        id: cashTxId,
        type: 'IN',
        amount: amount,
        purpose: "Credit payment collection: ${customer.name}",
        date: DateTime.now(),
        balanceAfter: updatedCashBalance,
        userId: uid,
      );

      _cashBalance = updatedCashBalance;
      _cashTransactions.insert(0, cashTx);
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cachedTransactions_$uid', jsonEncode(_cashTransactions.map((t) => t.toJson()).toList()));
        prefs.setDouble('cash_balance_$uid', _cashBalance);
      });

      await SettingsService.setCashBalance(updatedCashBalance);
    } else {
      notifyListeners();
    }

    // Cache updated list locally in SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cachedCustomers_$uid', jsonEncode(_customers.map((c) => c.toJson()).toList()));
      prefs.setString('cachedCreditTransactions_$uid', jsonEncode(_creditTransactions.map((t) => t.toJson()).toList()));
    });

    // 3. Write to Firestore in background using WriteBatch
    unawaited(() async {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // Update customer credit balance
        final custRef = FirebaseFirestore.instance.collection('customers').doc(customerId);
        batch.update(custRef, {'credit_balance': newBalance});

        // Save credit transaction
        final creditTxRef = FirebaseFirestore.instance.collection('credit_transactions').doc(creditTxId);
        batch.set(creditTxRef, creditTx.toJson());

        // Save cash transaction only if Cash
        if (paymentMethod == 'Cash' && cashTx != null) {
          final cashTxRef = FirebaseFirestore.instance.collection('cash_transactions').doc(cashTxId);
          batch.set(cashTxRef, cashTx.toJson());

          // Update settings for cash balance
          final settingsRef = FirebaseFirestore.instance.collection('settings').doc("${uid}_cash_balance");
          batch.set(settingsRef, {
            'user_id': uid,
            'key': 'cash_balance',
            'value': jsonEncode(updatedCashBalance),
          }, SetOptions(merge: true));
        }

        await batch.commit();
        print("Credit payment collection sync batch committed.");
      } catch (e) {
        print("Credit payment collection sync batch error: $e");
        FirebaseService.reportError('credit_payment_batch', 'commit', e);
      }
    }());
  }

  Future<void> clearFirestoreCache() async {
    final uid = userId;
    if (uid == null) return;

    _syncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      // 1. Stop listeners first
      await stopSync(clearLists: false);

      // 2. Disable network to prevent operations on bad state
      await FirebaseFirestore.instance.disableNetwork();

      // 3. Clear local cache persistence (clears the offline queue)
      await FirebaseFirestore.instance.clearPersistence();

      // 4. Enable network
      await FirebaseFirestore.instance.enableNetwork();

      // 5. Reload cached local data (if any remains, else fetches from server)
      await loadCachedData();

      // 6. Restart sync
      await startSync();
    } catch (e) {
      print("Error clearing Firestore persistence: $e");
      FirebaseService.reportError('persistence', 'clear', e);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> toggleDirectPrint(bool value) async {
    _directPrintEnabled = value;
    await SettingsService.setDirectPrintEnabled(value);
    if (value) {
      unawaited(scanPrinters());
      unawaited(connectToSavedPrinter());
    } else {
      await disconnectPrinter();
    }
    notifyListeners();
  }

  Future<void> updatePrinterType(String type) async {
    _printerType = type;
    await SettingsService.setPrinterType(type);
    notifyListeners();
    if (_directPrintEnabled) {
      await connectToSavedPrinter();
    }
  }

  Future<void> updatePrinterPort(int port) async {
    _printerPort = port;
    await SettingsService.setPrinterPort(port);
    notifyListeners();
  }

  Future<void> updatePaperWidth(String width) async {
    _paperWidth = width;
    await SettingsService.setPaperWidth(width);
    notifyListeners();
  }

  Future<void> scanPrinters() async {
    _isScanning = true;
    _isWifiScanning = true;
    _pairedDevices = [];
    _discoveredWifiIPs = [];
    notifyListeners();
    
    // 1. Scan Bluetooth
    try {
      final statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothConnect]?.isGranted == true || 
          await Permission.bluetooth.isGranted) {
        _pairedDevices = await _printerService.getBluetoothDevices();
      }
    } catch (e) {
      print("Error scanning Bluetooth: $e");
    } finally {
      _isScanning = false;
      notifyListeners();
    }

    // 2. Scan WiFi
    try {
      _discoveredWifiIPs = await _printerService.scanWifiPrinters();
    } catch (e) {
      print("Error scanning WiFi: $e");
    } finally {
      _isWifiScanning = false;
      notifyListeners();
    }
  }

  Future<void> connectToSavedPrinter() async {
    if (!_directPrintEnabled) return;
    final address = _selectedPrinterAddress;
    if (address == null) return;

    try {
      final success = await _printerService.connect(
        type: _printerType,
        address: address,
        port: _printerPort,
      );
      _printerConnected = success;
      notifyListeners();
    } catch (e) {
      print("Auto connect error: $e");
      _printerConnected = false;
      notifyListeners();
    }
  }

  Future<bool> selectPrinter(String type, String name, String address, {int port = 9100}) async {
    _isScanning = true;
    notifyListeners();
    try {
      final success = await _printerService.connect(
        type: type,
        address: address,
        port: port,
      );
      _printerConnected = success;
      if (success) {
        _printerType = type;
        _printerPort = port;
        _selectedPrinterAddress = address;
        _selectedPrinterName = name;
        await SettingsService.setPrinterType(type);
        await SettingsService.setPrinterPort(port);
        await SettingsService.setBluetoothPrinterAddress(address);
        await SettingsService.setBluetoothPrinterName(name);
        
        // Print test page on successful connection
        await _printerService.printTestPage("NexPOS", _paperWidth);
      }
      return success;
    } catch (e) {
      print("Error selecting printer: $e");
      return false;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> disconnectPrinter() async {
    await _printerService.disconnect();
    _printerConnected = false;
    notifyListeners();
  }
}
