import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:image/image.dart' as img;
import 'settings_service.dart';
import 'esc_pos_builder.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  Socket? _wifiSocket;

  String _connectedType = ''; // 'bluetooth' or 'wifi'
  String _connectedAddress = ''; // MAC address or IP Address
  int _connectedPort = 9100;

  String get connectedType => _connectedType;
  String get connectedAddress => _connectedAddress;
  int get connectedPort => _connectedPort;

  /// Get paired (bonded) Bluetooth devices
  Future<List<BluetoothDevice>> getBluetoothDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint("Error fetching bonded Bluetooth devices: $e");
      return [];
    }
  }

  /// Scan local subnet for WiFi printers on port 9100 concurrently
  Future<List<String>> scanWifiPrinters() async {
    final List<String> discoveredIPs = [];
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP == null) {
        debugPrint("WiFi IP not found. Ensure device is connected to WiFi.");
        return [];
      }

      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      final List<Future<void>> scanTasks = [];

      for (int i = 1; i <= 254; i++) {
        final host = '$subnet.$i';
        scanTasks.add(
          Socket.connect(host, 9100, timeout: const Duration(milliseconds: 350))
              .then((socket) {
            discoveredIPs.add(host);
            socket.destroy();
          }).catchError((_) {
            // Port closed or host unreachable
          }),
        );
      }

      // Wait for all connection attempts to finish
      await Future.wait(scanTasks);
    } catch (e) {
      debugPrint("Error scanning WiFi subnet: $e");
    }
    return discoveredIPs;
  }

  /// Connect to a printer (Bluetooth MAC address or WiFi IP)
  Future<bool> connect({
    required String type,
    required String address,
    int port = 9100,
  }) async {
    try {
      // Disconnect existing printer first
      await disconnect();

      if (type.toLowerCase() == 'bluetooth') {
        final devices = await getBluetoothDevices();
        final targetDevice = devices.firstWhere(
          (d) => d.address == address,
          orElse: () => BluetoothDevice("Printer", address),
        );

        await _bluetooth.connect(targetDevice);
        final success = (await _bluetooth.isConnected) ?? false;
        if (success) {
          _connectedType = 'bluetooth';
          _connectedAddress = address;
        }
        return success;
      } else if (type.toLowerCase() == 'wifi') {
        _wifiSocket = await Socket.connect(
          address,
          port,
          timeout: const Duration(seconds: 4),
        );
        _connectedType = 'wifi';
        _connectedAddress = address;
        _connectedPort = port;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error connecting to printer ($type at $address): $e");
      await disconnect();
      return false;
    }
  }

  /// Disconnect printer
  Future<void> disconnect() async {
    try {
      if (_connectedType == 'bluetooth') {
        final isConnected = await _bluetooth.isConnected;
        if (isConnected == true) {
          await _bluetooth.disconnect();
        }
      } else if (_connectedType == 'wifi') {
        await _wifiSocket?.flush();
        _wifiSocket?.destroy();
        _wifiSocket = null;
      }
    } catch (e) {
      debugPrint("Error disconnecting printer: $e");
    } finally {
      _connectedType = '';
      _connectedAddress = '';
      _connectedPort = 9100;
    }
  }

  /// Check connection status
  Future<bool> isConnected() async {
    try {
      if (_connectedType == 'bluetooth') {
        return (await _bluetooth.isConnected) ?? false;
      } else if (_connectedType == 'wifi') {
        return _wifiSocket != null;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Send raw bytes to connected printer
  Future<bool> sendBytes(List<int> bytes) async {
    try {
      final active = await isConnected();
      if (!active) return false;

      if (_connectedType == 'bluetooth') {
        await _bluetooth.writeBytes(Uint8List.fromList(bytes));
        return true;
      } else if (_connectedType == 'wifi' && _wifiSocket != null) {
        _wifiSocket!.add(bytes);
        await _wifiSocket!.flush();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error sending bytes to printer: $e");
      return false;
    }
  }

  /// Print test page
  Future<bool> printTestPage(String shopName, String paperWidth) async {
    try {
      final builder = ESCPosBuilder(paperWidth: paperWidth);

      builder.setAlign(1);
      builder.setTextSize(3); // Double size
      builder.setBold(true);
      builder.addTextLine(shopName);
      builder.setTextSize(0);
      builder.setBold(false);
      
      builder.addTextLine("NexPOS Printing System");
      builder.addTextLine("Connection: ${_connectedType.toUpperCase()}");
      builder.addTextLine("Address: $_connectedAddress");
      builder.addDivider();

      builder.addLeftRight("Paper Width:", paperWidth);
      builder.addLeftRight("Status:", "OK - Working");
      builder.addDivider();

      builder.feedLines(1);
      builder.addQRCode("https://nexpos.example.com");
      builder.feedLines(2);
      builder.cutPaper();

      return await sendBytes(builder.bytes);
    } catch (e) {
      debugPrint("Error printing test page: $e");
      return false;
    }
  }

  /// Print customer sale receipt
  Future<bool> printReceipt({
    required String shopName,
    required String tagline,
    required String address,
    required String phone,
    required List<dynamic> cartItems,
    required double subtotal,
    required double discountPercentage,
    required double discountAmt,
    required double taxRate,
    required double taxAmt,
    required double total,
    required String paymentMethod,
    required double cashReceived,
    required double changeDue,
    required String pricingMode,
    required String weightSymbol,
    required String paperWidth,
    String? customerName,
  }) async {
    try {
      final builder = ESCPosBuilder(paperWidth: paperWidth);

      // Load customizable shop configuration from settings
      final String finalShopName = SettingsService.getShopName();
      final String finalTagline = SettingsService.getShopTagline();
      final String finalAddress = SettingsService.getShopAddress();
      final String finalPhone = SettingsService.getShopPhone();

      // 1. Logo Printing (if configured)
      final logoPath = SettingsService.getShopLogoPath();
      if (logoPath != null && logoPath.isNotEmpty) {
        final rasterData = convertImageToRaster(logoPath, paperWidth == '80mm' ? 256 : 192);
        if (rasterData != null) {
          builder.addRasterImage(
            width: rasterData['width'] as int,
            height: rasterData['height'] as int,
            pixels: rasterData['pixels'] as List<int>,
          );
        }
      }

      // 2. Text Header
      builder.setAlign(1);
      builder.setTextSize(3); // Double height & width
      builder.setBold(true);
      builder.addTextLine(finalShopName.isNotEmpty ? finalShopName : shopName);
      builder.setTextSize(0);
      builder.setBold(false);

      final displayTagline = finalTagline.isNotEmpty ? finalTagline : tagline;
      final displayAddress = finalAddress.isNotEmpty ? finalAddress : address;
      final displayPhone = finalPhone.isNotEmpty ? finalPhone : phone;

      if (displayTagline.isNotEmpty) builder.addTextLine(displayTagline);
      if (displayAddress.isNotEmpty) builder.addTextLine(displayAddress);
      if (displayPhone.isNotEmpty) builder.addTextLine("Tel: $displayPhone");
      builder.addDivider();

      // Invoice metadata
      builder.setAlign(0); // Left align
      final invoiceId = "${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}${DateTime.now().hour.toString().padLeft(2, '0')}${DateTime.now().minute.toString().padLeft(2, '0')}";
      builder.addTextLine("Invoice ID: #$invoiceId");
      builder.addTextLine("Date: ${DateTime.now().toString().substring(0, 16)}");
      if (customerName != null && customerName.isNotEmpty) {
        builder.addTextLine("Customer: $customerName");
      }
      builder.addDivider();

      // Table Header
      builder.addLeftRight("Item (Qty)", "Total (Rs.)", bold: true);
      builder.addDivider(char: "-");

      // Cart Items
      for (final item in cartItems) {
        final product = item.product;
        final formattedQty = product.pricingMode == 'weight'
            ? item.quantity.toStringAsFixed(1)
            : item.quantity.toStringAsFixed(0);
        final unit = product.unit ?? (product.pricingMode == 'weight' ? weightSymbol : 'pcs');
        final itemLabel = "${product.name} (x$formattedQty $unit)";
        final itemPrice = "Rs. ${item.subtotal.toStringAsFixed(0)}";
        builder.addLeftRight(itemLabel, itemPrice);
      }
      builder.addDivider();

      // Calculation Breakdown
      builder.addLeftRight("Subtotal:", "Rs. ${subtotal.toStringAsFixed(2)}");
      if (discountAmt > 0) {
        builder.addLeftRight("Discount ($discountPercentage%):", "-Rs. ${discountAmt.toStringAsFixed(2)}");
      }
      if (taxAmt > 0) {
        builder.addLeftRight("Tax ($taxRate%):", "+Rs. ${taxAmt.toStringAsFixed(2)}");
      }
      builder.addDivider();
      builder.addLeftRight("TOTAL AMOUNT:", "Rs. ${total.toStringAsFixed(2)}", bold: true);
      builder.addDivider();

      // Payment Details
      builder.addLeftRight("Payment Method:", paymentMethod);
      if (paymentMethod == "Cash") {
        builder.addLeftRight("Cash Received:", "Rs. ${cashReceived.toStringAsFixed(2)}");
        builder.addLeftRight("Change Due:", "Rs. ${changeDue.toStringAsFixed(2)}");
      }
      builder.addDivider();

      // Footer
      builder.setAlign(1);
      builder.feedLines(1);
      builder.addTextLine("THANK YOU FOR YOUR PATRONAGE");
      builder.addTextLine("Powered by tillnex.space");
      builder.addTextLine("Ph: +16677788789");
      builder.feedLines(1);

      // Generate invoice QR code
      builder.addQRCode("INV-$invoiceId-TOT-${total.toStringAsFixed(0)}");
      builder.feedLines(2);

      // Cut paper & Kick drawer
      builder.cutPaper();
      builder.kickDrawer();

      return await sendBytes(builder.bytes);
    } catch (e) {
      debugPrint("Error printing receipt: $e");
      return false;
    }
  }

  /// Convert an image file path to monochrome bytes suitable for ESC/POS raster print
  static Map<String, dynamic>? convertImageToRaster(String filePath, int targetWidth) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final bytes = file.readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Calculate resized height to maintain aspect ratio
      final double aspectRatio = image.height / image.width;
      final int targetHeight = (targetWidth * aspectRatio).toInt();

      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
      );

      final List<int> rasterBytes = [];
      // Pack pixels (8 pixels = 1 byte)
      int xBytes = (targetWidth + 7) ~/ 8;

      for (int y = 0; y < targetHeight; y++) {
        for (int xByte = 0; xByte < xBytes; xByte++) {
          int value = 0;
          for (int bit = 0; bit < 8; bit++) {
            int x = xByte * 8 + bit;
            if (x < targetWidth) {
              final pixel = resizedImage.getPixel(x, y);
              final r = pixel.r;
              final g = pixel.g;
              final b = pixel.b;
              final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
              
              // Threshold (128): dark pixels are 1 (black), light pixels are 0 (white)
              if (luminance < 128) {
                value |= (1 << (7 - bit));
              }
            }
          }
          rasterBytes.add(value);
        }
      }

      return {
        'width': targetWidth,
        'height': targetHeight,
        'pixels': rasterBytes,
      };
    } catch (e) {
      debugPrint("Error converting image to raster: $e");
      return null;
    }
  }
}
