import 'dart:convert';

class ESCPosBuilder {
  final String paperWidth; // '58mm' or '80mm'
  final List<int> _bytes = [];

  ESCPosBuilder({this.paperWidth = '58mm'}) {
    reset();
  }

  List<int> get bytes => _bytes;

  /// Clear the builder and initialize printer
  void reset() {
    _bytes.clear();
    // ESC @ (Initialize printer)
    _bytes.addAll([0x1B, 0x40]);
    // Set standard international character set (USA / UTF-8)
    // ESC t 16 (often WPC1252 or CP1252) or ESC t 0 (standard)
    _bytes.addAll([0x1B, 0x74, 0x00]);
  }

  /// Add raw bytes
  void addRawBytes(List<int> raw) {
    _bytes.addAll(raw);
  }

  /// Print a line of text
  void addText(String text) {
    // Convert to bytes using Latin-1 / CP1252 (or fallback to UTF8)
    try {
      _bytes.addAll(latin1.encode(text));
    } catch (_) {
      _bytes.addAll(utf8.encode(text));
    }
  }

  /// Print a line of text followed by a newline
  void addTextLine(String text) {
    addText(text);
    _bytes.add(0x0A); // LF (newline)
  }

  /// Print newlines
  void feedLines(int count) {
    for (int i = 0; i < count; i++) {
      _bytes.add(0x0A);
    }
  }

  /// Set text alignment: 0 = Left, 1 = Center, 2 = Right
  void setAlign(int align) {
    int val = 0;
    if (align == 1) val = 1;
    if (align == 2) val = 2;
    // ESC a n
    _bytes.addAll([0x1B, 0x61, val]);
  }

  /// Set text size: 0 = Normal, 1 = Double Height, 2 = Double Width, 3 = Double size
  void setTextSize(int size) {
    int val = 0x00;
    if (size == 1) val = 0x01; // Double height
    if (size == 2) val = 0x10; // Double width
    if (size == 3) val = 0x11; // Double width + double height
    // GS ! n
    _bytes.addAll([0x1D, 0x21, val]);
  }

  /// Toggle bold mode
  void setBold(bool bold) {
    // ESC E n
    _bytes.addAll([0x1B, 0x45, bold ? 0x01 : 0x00]);
  }

  /// Toggle underline mode
  void setUnderline(bool underline) {
    // ESC - n
    _bytes.addAll([0x1B, 0x2D, underline ? 0x01 : 0x00]);
  }

  /// Print a divider line based on paper size
  void addDivider({String char = "-"}) {
    int columns = paperWidth == '80mm' ? 48 : 32;
    addTextLine(char * columns);
  }

  /// Print two columns, left and right aligned
  void addLeftRight(String left, String right, {bool bold = false}) {
    if (bold) setBold(true);
    int columns = paperWidth == '80mm' ? 48 : 32;
    int leftLen = left.length;
    int rightLen = right.length;

    if (leftLen + rightLen >= columns) {
      // Wrap: print left text first, then print right text right-aligned
      addTextLine(left);
      setAlign(2);
      addTextLine(right);
      setAlign(0);
    } else {
      int spaces = columns - leftLen - rightLen;
      addTextLine(left + (' ' * spaces) + right);
    }
    if (bold) setBold(false);
  }

  /// Kick the Cash Drawer (standard ESC/POS cash drawer command on Pin 2)
  void kickDrawer() {
    // ESC p m t1 t2
    // m = 0, t1 = 25, t2 = 250
    _bytes.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]);
  }

  /// Partial paper cut command (or full paper cut)
  void cutPaper() {
    // GS V 66 0 (Feed and cut)
    _bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
  }

  /// Add barcode (standard Code39 or Code128)
  void addBarcode(String data) {
    // Center alignment for barcode
    setAlign(1);
    
    // Set HRI characters print position (below barcode)
    // GS H 2
    _bytes.addAll([0x1D, 0x48, 0x02]);

    // Set barcode height in dots (default 80 dots)
    // GS h 80
    _bytes.addAll([0x1D, 0x68, 0x50]);

    // Set barcode width (default 2)
    // GS w 2
    _bytes.addAll([0x1D, 0x77, 0x02]);

    // Print barcode using Code 39 (simpler and widely supported)
    // GS k 4 length data *data*
    final barcodeBytes = ascii.encode(data.toUpperCase());
    _bytes.addAll([0x1D, 0x6B, 0x04]);
    _bytes.addAll(barcodeBytes);
    _bytes.add(0x00); // Terminator for format 1

    feedLines(1);
    setAlign(0); // Reset align
  }

  /// Add standard QR Code
  void addQRCode(String data) {
    setAlign(1);

    final dataBytes = utf8.encode(data);
    final len = dataBytes.length + 3;
    final lenL = len & 0xFF;
    final lenH = (len >> 8) & 0xFF;

    // 1. Set QR Model (Model 2)
    // GS ( k 4 0 49 65 50 0
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // 2. Set QR Cell Size (Default 6 dots)
    // GS ( k 3 0 49 67 6
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);

    // 3. Set QR Error Correction Level (Level M)
    // GS ( k 3 0 49 68 49
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x44, 0x31]);

    // 4. Store Data in QR Module
    // GS ( k lenL lenH 49 80 48 data
    _bytes.addAll([0x1D, 0x28, 0x6B, lenL, lenH, 0x31, 0x50, 0x30]);
    _bytes.addAll(dataBytes);

    // 5. Print QR Code
    // GS ( k 3 0 49 81 48
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    feedLines(1);
    setAlign(0); // Reset align
  }

  /// Add a raster image logo to the receipt
  /// [width] must be a multiple of 8, and [pixels] is black-and-white (1 = black, 0 = white) byte packed.
  void addRasterImage({required int width, required int height, required List<int> pixels}) {
    setAlign(1);
    int xBytes = (width + 7) ~/ 8;
    // GS v 0 m xL xH yL yH d1...dk
    _bytes.addAll([
      0x1D, 0x76, 0x30, 0x00,
      xBytes & 0xFF, (xBytes >> 8) & 0xFF,
      height & 0xFF, (height >> 8) & 0xFF
    ]);
    _bytes.addAll(pixels);
    feedLines(1);
    setAlign(0);
  }
}
