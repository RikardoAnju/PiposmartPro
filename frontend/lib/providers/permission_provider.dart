// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/data/models/printer_device_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:ayocucinew/core/utils/logo_thermal.dart';
import 'dart:convert';
import 'dart:async';

class PermissionProvider extends ChangeNotifier {
  static const _keyLastDeviceAddress = 'last_printer_address';
  static const _keyLastDeviceName = 'last_printer_name';

  Map<String, String> permissions = {
    'Bluetooth Connection': 'Tidak Diizinkan',
    'Bluetooth Scan': 'Tidak Diizinkan',
    'Fine Location': 'Tidak Diizinkan',
    'Os Android Version': '13',
    'Actual Level Version': '33',
  };

  List<PrinterDevice> _foundDevices = [];
  bool _isScanning = false;
  String? _connectingDeviceAddress;
  PrinterDevice? _connectedDevice;
  bool _isConnected = false;
  bool _isInitialized = false;

  bool get isScanning => _isScanning;
  bool get isConnecting => _connectingDeviceAddress != null;
  List<PrinterDevice> get foundDevices => _foundDevices;
  bool get isConnected => _isConnected;
  PrinterDevice? get connectedDevice => _connectedDevice;
  bool get supportsBluetoothPrinter => _supportsBluetoothPrinter;
  bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;
  bool get requiresBluetoothPermission =>
      defaultTargetPlatform == TargetPlatform.android;
  bool get canUseSystemPrintFallback => isIos;
  String get platformScannerLabel =>
      isIos ? 'Scan Printer Bluetooth' : 'Scan Perangkat Paired';
  String get platformIntroMessage => isIos
      ? 'iPhone hanya bisa terhubung ke printer Bluetooth yang kompatibel dengan iOS/BLE. Jika printer tidak cocok, nota tetap bisa dicetak lewat dialog Print iPhone.'
      : 'Hubungkan printer thermal Bluetooth untuk test print dan cetak nota langsung dari aplikasi.';
  String get platformEmptyMessage => isIos
      ? 'Hanya printer Bluetooth yang support iPhone/iOS yang akan muncul.'
      : 'Pastikan printer sudah di-pair di pengaturan Bluetooth.';

  bool get _supportsBluetoothPrinter =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool isDeviceConnecting(String address) =>
      _connectingDeviceAddress == address;

  IconData getDeviceIcon(PrinterDevice device) {
    final name = device.name.toLowerCase();
    if (name.contains('print') ||
        name.contains('pos') ||
        name.contains('rpp') ||
        name.contains('thermal') ||
        name.contains('receipt') ||
        name.contains('epson') ||
        name.contains('xprinter') ||
        name.contains('goojprt') ||
        name.contains('sunmi') ||
        name.contains('printer') ||
        name.contains('panda')) {
      return Icons.print;
    }
    if (name.contains('headphone') ||
        name.contains('headset') ||
        name.contains('earphone') ||
        name.contains('buds') ||
        name.contains('airpod') ||
        name.contains('speaker') ||
        name.contains('jbl') ||
        name.contains('sony') ||
        name.contains('bose') ||
        name.contains('audio')) {
      return Icons.headphones;
    }
    if (name.contains('phone') ||
        name.contains('iphone') ||
        name.contains('samsung') ||
        name.contains('xiaomi') ||
        name.contains('oppo') ||
        name.contains('vivo') ||
        name.contains('realme') ||
        name.contains('galaxy') ||
        name.contains('redmi') ||
        name.contains('poco') ||
        name.contains('oneplus')) {
      return Icons.smartphone;
    }
    if (name.contains('laptop') ||
        name.contains('computer') ||
        name.contains('pc') ||
        name.contains('macbook') ||
        name.contains('thinkpad') ||
        name.contains('dell') ||
        name.contains('asus') ||
        name.contains('acer') ||
        name.contains('lenovo') ||
        name.contains('hp ')) {
      return Icons.laptop;
    }
    if (name.contains('tablet') ||
        name.contains('ipad') ||
        name.contains('tab ') ||
        name.contains('galaxy tab')) {
      return Icons.tablet;
    }
    if (name.contains('watch') ||
        name.contains('band') ||
        name.contains('fit') ||
        name.contains('miband') ||
        name.contains('smartwatch')) {
      return Icons.watch;
    }
    if (name.contains('keyboard') ||
        name.contains('mouse') ||
        name.contains('trackpad') ||
        name.contains('logitech')) {
      return Icons.keyboard;
    }
    if (name.contains('car') ||
        name.contains('auto') ||
        name.contains('vehicle') ||
        name.contains('multimedia')) {
      return Icons.directions_car;
    }
    if (name.contains('tv') ||
        name.contains('display') ||
        name.contains('monitor')) {
      return Icons.tv;
    }
    return Icons.bluetooth;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await checkPermissions();
    await getAndroidVersion();
    await autoReconnect();
  }

  Future<void> getAndroidVersion() async {
    if (!_supportsBluetoothPrinter || isIos) {
      permissions['Os Android Version'] = 'N/A';
      permissions['Actual Level Version'] = 'N/A';
      notifyListeners();
      return;
    }
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      permissions['Os Android Version'] = androidInfo.version.release;
      permissions['Actual Level Version'] = androidInfo.version.sdkInt
          .toString();
    } catch (_) {
      permissions['Os Android Version'] = 'Error';
      permissions['Actual Level Version'] = 'Error';
    }
    notifyListeners();
  }

  Future<void> checkPermissions() async {
    if (isIos) {
      permissions['Bluetooth Connection'] = 'Diizinkan';
      permissions['Bluetooth Scan'] = 'Diizinkan';
      permissions['Fine Location'] = 'Tidak Diperlukan';
      notifyListeners();
      return;
    }

    if (!_supportsBluetoothPrinter) {
      permissions['Bluetooth Connection'] = 'Tidak Tersedia';
      permissions['Bluetooth Scan'] = 'Tidak Tersedia';
      permissions['Fine Location'] = 'Tidak Tersedia';
      notifyListeners();
      return;
    }
    final btConnect = await Permission.bluetoothConnect.status;
    final btScan = await Permission.bluetoothScan.status;
    final location = await Permission.locationWhenInUse.status;
    permissions['Bluetooth Connection'] = btConnect.isGranted
        ? 'Diizinkan'
        : 'Tidak Diizinkan';
    permissions['Bluetooth Scan'] = btScan.isGranted
        ? 'Diizinkan'
        : 'Tidak Diizinkan';
    permissions['Fine Location'] = location.isGranted
        ? 'Diizinkan'
        : 'Tidak Diizinkan';
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestBluetoothPermission() async {
    if (isIos) {
      await checkPermissions();
      return {
        'success': true,
        'message':
            'iPhone tidak memerlukan izin terpisah. Lanjutkan ke scan printer Bluetooth.',
        'skip': true,
      };
    }
    if (!_supportsBluetoothPrinter) {
      return {
        'success': false,
        'message': 'Fitur printer Bluetooth belum tersedia di perangkat ini.',
      };
    }
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    await checkPermissions();
    final granted = statuses.values.every((s) => s.isGranted);
    return {
      'success': granted,
      'message': granted
          ? 'Permission Bluetooth berhasil diberikan.'
          : 'Permission Bluetooth belum diberikan.',
    };
  }

  Future<bool> checkBluetoothState() async {
    if (!_supportsBluetoothPrinter) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('Error checking Bluetooth state: $e');
      return false;
    }
  }

  Future<bool> refreshConnectionStatus() async {
    if (!_supportsBluetoothPrinter) {
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }

    try {
      final bool btOn = await checkBluetoothState();
      if (!btOn) {
        _isConnected = false;
        _connectedDevice = null;
        notifyListeners();
        return false;
      }

      final bool connected = await PrintBluetoothThermal.connectionStatus;
      _isConnected = connected;
      if (!connected) {
        _connectedDevice = null;
      }
      notifyListeners();
      return connected;
    } catch (e) {
      debugPrint('refreshConnectionStatus gagal: $e');
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveLastDevice(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDeviceAddress, device.address);
    await prefs.setString(_keyLastDeviceName, device.name);
  }

  Future<PrinterDevice?> _getLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_keyLastDeviceAddress);
    final name = prefs.getString(_keyLastDeviceName);
    if (address == null || address.isEmpty) return null;
    return PrinterDevice(
      name: (name == null || name.isEmpty) ? 'Unknown Device' : name,
      address: address,
    );
  }

  Future<void> autoReconnect() async {
    if (!_supportsBluetoothPrinter) return;
    try {
      final btOn = await checkBluetoothState();
      if (!btOn) return;

      final alreadyConnected = await PrintBluetoothThermal.connectionStatus;
      if (alreadyConnected) {
        _isConnected = true;
        notifyListeners();
        return;
      }

      final lastDevice = await _getLastDevice();
      if (lastDevice == null) return;

      _connectingDeviceAddress = lastDevice.address;
      notifyListeners();

      final connected =
          await PrintBluetoothThermal.connect(
            macPrinterAddress: lastDevice.address,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Auto reconnect timeout'),
          );

      if (connected) {
        _connectedDevice = lastDevice;
        _isConnected = true;
      } else {
        _isConnected = false;
        _connectedDevice = null;
      }
    } catch (e) {
      debugPrint('Auto reconnect gagal: $e');
      _isConnected = false;
      _connectedDevice = null;
    } finally {
      _connectingDeviceAddress = null;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> scanBluetooth({BuildContext? context}) async {
    if (!_supportsBluetoothPrinter) {
      final message =
          'Fitur printer Bluetooth belum tersedia di perangkat ini.';
      if (context != null) {
        CustomToast.show(context, message: message, isError: true);
      }
      return {'success': false, 'message': message};
    }
    if (!isIos) {
      final btScan = await Permission.bluetoothScan.status;
      final btConnect = await Permission.bluetoothConnect.status;
      final pluginPermissionGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if ((!btScan.isGranted || !btConnect.isGranted) &&
          !pluginPermissionGranted) {
        final permissionResult = await requestBluetoothPermission();
        final permissionGranted = permissionResult['success'] == true;
        if (!permissionGranted) {
          final message =
              permissionResult['message']?.toString() ??
              'Permission Bluetooth belum diberikan.';
          if (context != null) {
            CustomToast.show(context, message: message, isError: true);
          }
          return {'success': false, 'message': message};
        }
      }
    }

    if (!await checkBluetoothState()) {
      final message = isIos
          ? 'Bluetooth iPhone sedang tidak aktif atau belum siap. Coba lagi setelah Bluetooth menyala.'
          : 'Bluetooth mati! Nyalakan Bluetooth.';
      if (context != null) {
        CustomToast.show(context, message: message, isError: true);
      }
      return {'success': false, 'message': message};
    }

    _isScanning = true;
    _foundDevices.clear();
    notifyListeners();

    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      _foundDevices = devices
          .where((device) => device.macAdress.trim().isNotEmpty)
          .map(
            (device) => PrinterDevice(
              name: device.name.trim().isEmpty ? 'Unknown Device' : device.name,
              address: device.macAdress,
            ),
          )
          .toList();
      _foundDevices.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      _isScanning = false;
      notifyListeners();
      final message = isIos
          ? 'Ditemukan ${_foundDevices.length} printer/perangkat Bluetooth.'
          : 'Ditemukan ${_foundDevices.length} perangkat paired';
      if (context != null) {
        CustomToast.show(context, message: message);
      }
      return {
        'success': true,
        'message': message,
        'devicesFound': _foundDevices.length,
      };
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      if (context != null) {
        CustomToast.show(context, message: 'Error: $e', isError: true);
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> connectToPrinter(
    PrinterDevice device, {
    BuildContext? context,
  }) async {
    if (!_supportsBluetoothPrinter) {
      final message =
          'Fitur printer Bluetooth belum tersedia di perangkat ini.';
      if (context != null) {
        CustomToast.show(context, message: message, isError: true);
      }
      return {'success': false, 'message': message};
    }
    if (_isConnected) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    _connectingDeviceAddress = device.address;
    notifyListeners();

    try {
      final bool connected =
          await PrintBluetoothThermal.connect(
            macPrinterAddress: device.address,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Koneksi timeout'),
          );

      if (connected) {
        _connectedDevice = device;
        _isConnected = true;
        _connectingDeviceAddress = null;
        await _saveLastDevice(device);
        notifyListeners();
        if (context != null && context.mounted) {
          CustomToast.show(context, message: 'Terhubung ke ${device.name}');
        }
        return {'success': true, 'message': 'Terhubung ke ${device.name}'};
      }

      _connectingDeviceAddress = null;
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      final errorMsg = isIos
          ? 'Printer ini tidak support iPhone/iOS. Coba printer yang support iOS/MFi/AirPrint atau gunakan Android untuk printer ini.'
          : '${device.name} offline. Nyalakan printer.';
      if (context != null && context.mounted) {
        CustomToast.show(context, message: errorMsg, isError: true);
      }
      return {'success': false, 'message': errorMsg};
    } on TimeoutException {
      _connectingDeviceAddress = null;
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      final errorMsg = isIos
          ? 'Printer ini tidak support iPhone/iOS. Coba printer yang support iOS/MFi/AirPrint atau gunakan Android untuk printer ini.'
          : '${device.name} tidak merespons. Coba lagi.';
      if (context != null && context.mounted) {
        CustomToast.show(context, message: errorMsg, isError: true);
      }
      return {'success': false, 'message': errorMsg};
    } catch (e) {
      _connectingDeviceAddress = null;
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      String errorMsg = isIos
          ? 'Printer ini tidak support iPhone/iOS. Coba printer yang support iOS/MFi/AirPrint atau gunakan Android untuk printer ini.'
          : 'Gagal terhubung';
      if (e.toString().contains('socket')) {
        errorMsg = 'Koneksi putus. Coba lagi.';
      } else if (e.toString().contains('permission')) {
        errorMsg = 'Izin Bluetooth ditolak.';
      }
      if (context != null && context.mounted) {
        CustomToast.show(context, message: errorMsg, isError: true);
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  Future<void> disconnect({BuildContext? context}) async {
    if (!_supportsBluetoothPrinter) {
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      return;
    }
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  Future<Map<String, dynamic>> printText(
    String text, {
    BuildContext? context,
  }) async {
    if (!_supportsBluetoothPrinter) {
      final message =
          'Fitur printer Bluetooth belum tersedia di perangkat ini.';
      if (context != null) {
        CustomToast.show(context, message: message, isError: true);
      }
      return {'success': false, 'message': message};
    }
    if (!_isConnected && !isIos) {
      if (context != null) {
        CustomToast.show(
          context,
          message: 'Tidak terhubung ke printer',
          isError: true,
        );
      }
      return {'success': false, 'message': 'Tidak terhubung ke printer'};
    }
    if (!_isConnected && isIos) {
      if (context != null) {
        CustomToast.show(
          context,
          message: 'Tidak terhubung ke printer',
          isError: true,
        );
      }
      return {'success': false, 'message': 'Tidak terhubung ke printer'};
    }
    try {
      final List<int> bytes = [];
      bytes.addAll([0x1B, 0x61, 0x00]);
      bytes.addAll(utf8.encode('$text\n'));
      bytes.addAll([0x1B, 0x64, 0x02]);
      await PrintBluetoothThermal.writeBytes(bytes);
      if (context != null) {
        CustomToast.show(context, message: 'Print berhasil!');
      }
      return {'success': true, 'message': 'Print berhasil!'};
    } catch (e) {
      if (context != null) {
        CustomToast.show(
          context,
          message: 'Print gagal: ${e.toString()}',
          isError: true,
        );
      }
      return {'success': false, 'message': 'Print gagal: ${e.toString()}'};
    }
  }

  List<int> _safeUtf8Encode(String text) {
    final cleaned = text.replaceAll(
      RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F]'),
      '',
    );
    try {
      return utf8.encode(cleaned);
    } catch (e) {
      return cleaned.codeUnits;
    }
  }

  List<int> _convertToEscPos(img.Image grayscale) {
    final w = grayscale.width;
    final h = grayscale.height;
    final bytesPerRow = (w + 7) ~/ 8;

    final List<int> imgBytes = [];
    imgBytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    imgBytes.addAll([bytesPerRow % 256, bytesPerRow ~/ 256]);
    imgBytes.addAll([h % 256, h ~/ 256]);

    for (int y = 0; y < h; y++) {
      for (int xByte = 0; xByte < bytesPerRow; xByte++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x < w) {
            final pixel = grayscale.getPixel(x, y);
            if (img.getLuminance(pixel) < 128) byte |= (0x80 >> bit);
          }
        }
        imgBytes.add(byte);
      }
    }
    return imgBytes;
  }

  Future<List<int>> _buildReceiptImageBytes(
    Uint8List imageBytes, {
    int paperWidth = 58,
  }) async {
    final original = img.decodeImage(imageBytes);
    if (original == null) {
      throw Exception('Gagal membaca gambar nota');
    }

    final targetWidth = paperWidth >= 80 ? 576 : 384;
    final resized = img.copyResize(original, width: targetWidth);
    final grayscale = img.grayscale(resized);
    final contrasted = img.contrast(grayscale, contrast: 135);

    for (int y = 0; y < contrasted.height; y++) {
      for (int x = 0; x < contrasted.width; x++) {
        final pixel = contrasted.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        final bw = luminance > 190 ? 255 : 0;
        contrasted.setPixelRgba(x, y, bw, bw, bw, 255);
      }
    }

    return _convertToEscPos(contrasted);
  }

  Future<List<int>> _buildLogoBytes(
    String logoUrl, {
    int paperWidth = 58,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(logoUrl))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode != 200) return [];

      // Konversi ke monokrom 1-bit (dithering) lalu raster ESC/POS yang sudah
      // di-CENTER (bitmap selebar penuh kertas). Sumber yang sama dipakai untuk
      // preview di layar upload logo.
      final mono = LogoThermal.toMonochrome(
        response.bodyBytes,
        targetWidth: LogoThermal.defaultLogoWidth(paperWidth),
      );
      if (mono == null) return [];

      return LogoThermal.escPosCentered(mono, paperWidth: paperWidth);
    } catch (e) {
      debugPrint('Logo ESC-POS error: $e');
      return [];
    }
  }

  // Memotong byte mentah setiap N byte tanpa peduli isi bisa memutus sebuah
  // baris teks atau command ESC/POS tepat di tengah. Beberapa printer
  // thermal Bluetooth SPP murah akan langsung nge-flush/print apa pun yang
  // sudah diterima begitu ada jeda antar-write, sehingga potongan di tengah
  // baris tercetak sebagai baris pendek/aneh yang terpisah dari baris
  // aslinya. Untuk menghindarinya, cari byte newline (0x0A) TERAKHIR yang
  // masih berada di dalam window chunkSize dan potong tepat di situ, supaya
  // setiap chunk yang dikirim selalu berakhir di batas baris yang utuh.
  Future<void> _sendInChunks(List<int> bytes, {int chunkSize = 4096}) async {
    int i = 0;
    while (i < bytes.length) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;

      if (end < bytes.length) {
        final lastNewline = bytes.lastIndexOf(0x0A, end - 1);
        if (lastNewline > i) {
          end = lastNewline + 1;
        }
      }

      await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
      await Future.delayed(const Duration(milliseconds: 20));
      i = end;
    }
  }

  List<int> _buildPrinterInitBytes({int paperWidth = 58}) {
    final List<int> bytes = [];
    final int widthDots = paperWidth >= 80 ? 576 : 384;
    final int widthL = widthDots % 256;
    final int widthH = widthDots ~/ 256;

    bytes.addAll([0x1B, 0x40]); // initialize
    bytes.addAll([0x1B, 0x4D, 0x00]); // font A
    // Line spacing. Font A tingginya 24 dot, jadi nilai 24 membuat baris
    // saling menempel (tanpa celah) sehingga struk terlihat sesak. 32 dot
    // memberi jarak antar-baris yang nyaman tanpa boros kertas.
    bytes.addAll([0x1B, 0x33, 32]); // line spacing
    bytes.addAll([0x1D, 0x4C, 0x00, 0x00]); // left margin = 0
    bytes.addAll([0x1D, 0x57, widthL, widthH]); // print area width
    bytes.addAll([0x1B, 0x61, 0x00]); // align left

    return bytes;
  }

  Future<Map<String, dynamic>> printReceipt(
    String notaText, {
    String? linkNota,
    String? logoUrl,
    BuildContext? context,
    int paperWidth = 58,
  }) async {
    if (!_supportsBluetoothPrinter) {
      final message =
          'Fitur printer Bluetooth belum tersedia di perangkat ini.';
      if (context != null) {
        CustomToast.show(context, message: message, isError: true);
      }
      return {'success': false, 'message': message};
    }
    if (!_isConnected && !isIos) {
      if (context != null) {
        CustomToast.show(
          context,
          message: 'Tidak terhubung ke printer',
          isError: true,
        );
      }
      return {'success': false, 'message': 'Tidak terhubung ke printer'};
    }
    if (!_isConnected && isIos) {
      if (context != null) {
        CustomToast.show(
          context,
          message: 'Tidak terhubung ke printer',
          isError: true,
        );
      }
      return {'success': false, 'message': 'Tidak terhubung ke printer'};
    }
    try {
      final normalizedText = notaText
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');

      // TEMP DEBUG: dump the exact text + per-line char count being sent to
      // the printer, to diagnose real-device alignment issues that don't
      // reproduce from a photo alone. Remove once the print formatting is
      // confirmed correct on real hardware.
      debugPrint('===== NOTA PRINT DEBUG (paperWidth=$paperWidth) =====');
      for (final line in normalizedText.split('\n')) {
        debugPrint('[${line.length.toString().padLeft(2)}] $line');
      }
      debugPrint('===== END NOTA PRINT DEBUG =====');

      await PrintBluetoothThermal.writeBytes(
        _buildPrinterInitBytes(paperWidth: paperWidth),
      );
      await Future.delayed(const Duration(milliseconds: 200));

      // ── Logo ──
      if (logoUrl != null && logoUrl.isNotEmpty) {
        final logoBytes = await _buildLogoBytes(
          logoUrl,
          paperWidth: paperWidth,
        );
        if (logoBytes.isNotEmpty) {
          // Raster GS v 0 harus dikirim UTUH dalam satu write — memotongnya
          // (apalagi di byte newline) bisa memicu printer nge-flush separuh
          // gambar → logo kepotong. Centering sudah ditangani di dalam raster
          // (bitmap selebar penuh kertas), jadi ESC a tidak diperlukan.
          await PrintBluetoothThermal.writeBytes(logoBytes);
          await PrintBluetoothThermal.writeBytes(_safeUtf8Encode('\n'));
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // ── Body teks nota ──
      final List<int> textBytes = [];
      textBytes.addAll(
        _buildEscPosBytes(normalizedText, paperWidth: paperWidth),
      );

      // ── QR code ──
      if (linkNota != null && linkNota.isNotEmpty) {
        textBytes.addAll([0x0A]);
        textBytes.addAll(_buildQrCodeBytes(linkNota, paperWidth: paperWidth));
      } else {
        textBytes.addAll([0x0A]);
      }

      textBytes.addAll([0x1B, 0x61, 0x01]);
      textBytes.addAll(_safeUtf8Encode('Powered By AyoCuci POS\n'));
      textBytes.addAll([0x1B, 0x61, 0x00]);
      textBytes.addAll([0x1B, 0x64, 0x02]); // Feed 2 baris

      await _sendInChunks(textBytes);

      if (context != null) {
        CustomToast.show(context, message: 'Struk berhasil dicetak!');
      }
      return {'success': true, 'message': 'Struk berhasil dicetak!'};
    } catch (e) {
      debugPrint('Print error: $e');
      String errorMsg = 'Gagal mencetak';
      if (e.toString().contains('socket')) {
        errorMsg = 'Koneksi printer putus.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = 'Print terlalu lama, coba lagi.';
      } else if (e.toString().contains('permission')) {
        errorMsg = 'Izin akses ditolak.';
      }
      if (context != null) {
        CustomToast.show(context, message: errorMsg, isError: true);
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  Future<Map<String, dynamic>> printReceiptImage(
    Uint8List imageBytes, {
    BuildContext? context,
    int paperWidth = 58,
  }) async {
    if (!_supportsBluetoothPrinter) {
      final message =
          'Fitur printer Bluetooth belum tersedia di perangkat ini.';
      if (context != null) {
        CustomToast.show(context, message: message, isError: true);
      }
      return {'success': false, 'message': message};
    }
    if (!_isConnected) {
      if (context != null) {
        CustomToast.show(
          context,
          message: 'Tidak terhubung ke printer',
          isError: true,
        );
      }
      return {'success': false, 'message': 'Tidak terhubung ke printer'};
    }

    try {
      final initBytes = _buildPrinterInitBytes(paperWidth: paperWidth);
      final receiptBytes = await _buildReceiptImageBytes(
        imageBytes,
        paperWidth: paperWidth,
      );

      final stillConnected = await refreshConnectionStatus();
      if (!stillConnected) {
        return {'success': false, 'message': 'Printer tidak lagi terhubung.'};
      }

      await PrintBluetoothThermal.writeBytes(initBytes);
      await Future.delayed(const Duration(milliseconds: 120));

      final payload = <int>[
        0x1B,
        0x61,
        0x01,
        ...receiptBytes,
        0x1B,
        0x61,
        0x00,
        0x1B,
        0x64,
        0x03,
      ];

      await Future.delayed(const Duration(milliseconds: 180));
      await _sendInChunks(payload, chunkSize: 256);

      if (context != null) {
        CustomToast.show(context, message: 'Struk berhasil dicetak!');
      }
      return {'success': true, 'message': 'Struk berhasil dicetak!'};
    } catch (e) {
      debugPrint('Print image error: $e');
      String errorMsg = 'Gagal mencetak';
      if (e.toString().contains('socket')) {
        errorMsg = 'Koneksi printer putus.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = 'Print terlalu lama, coba lagi.';
      }
      if (context != null) {
        CustomToast.show(context, message: errorMsg, isError: true);
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // ── Big line checker ──
  // "~~Kurang" / "~~Rp..." → center + bold + besar (prefix ~~ di-strip sebelum print)
  // "~~CUST~~" → center + bold + lebih besar
  bool _isBigLine(String line) {
    return _isRemainingPaymentLine(line) ||
        line.startsWith('~~CUST~~') ||
        line.startsWith('~~STATUS~~');
  }

  bool _isRemainingPaymentLine(String line) =>
      line.startsWith('~~Kurang') || line.startsWith('~~Rp');
  bool _isCustLine(String line) => line.startsWith('~~CUST~~');
  bool _isStatusLine(String line) => line.startsWith('~~STATUS~~');

  List<int> _buildEscPosBytes(String text, {int paperWidth = 58}) {
    final int lineChars = paperWidth == 88 ? 56 : (paperWidth == 80 ? 48 : 28);
    final int dividerChars = lineChars;

    final List<int> bytes = [];
    bytes.addAll([0x1B, 0x40]);
    bytes.addAll([0x1B, 0x4D, 0x00]);

    final lines = text.split('\n');

    // Header = semua baris sebelum separator === pertama
    final int firstEqSep = lines.indexWhere((l) => l.startsWith('==='));
    final int headerCount = firstEqSep > 0 ? firstEqSep : 1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // ── Separator --- atau === ──
      if (line.startsWith('---') || line.startsWith('===')) {
        // Center-align: lebar karakter yang kita hitung (28/48/56) sering
        // lebih sempit dari kapasitas fisik kertas printer, jadi kalau
        // rata-kiri seluruh blok nempel ke pinggir kiri kertas. Center-align
        // membiarkan printer menaruh blok teks di tengah kertas fisik tanpa
        // mengubah kerapian kolom internalnya (semua baris tetap sama
        // lebar persis).
        bytes.addAll([0x1B, 0x61, 0x01]);
        final sepChar = line.startsWith('===') ? '=' : '-';
        final sepLength = sepChar == '-' ? dividerChars : lineChars;
        bytes.addAll(_safeUtf8Encode('${sepChar * sepLength}\n'));
        continue;
      }

      // ── Header baris (outlet name, alamat, kontak, trxCode) ──
      if (i < headerCount) {
        bytes.addAll([0x1B, 0x61, 0x01]);
        if (i == 0) {
          // Nama outlet → bold + sedikit lebih besar (double height saja) agar
          // menonjol dari alamat/kontak, tapi tetap di bawah ukuran nama
          // pelanggan yang double width+height (0x11 / 0x22 di 88mm).
          final int outletSize = paperWidth == 88 ? 0x11 : 0x01;
          bytes.addAll([0x1D, 0x21, outletSize]);
          bytes.addAll([0x1B, 0x45, 0x01]);
          bytes.addAll(_safeUtf8Encode('$line\n'));
          bytes.addAll([0x1B, 0x45, 0x00]);
          bytes.addAll([0x1D, 0x21, 0x00]); // kembali ke ukuran normal
        } else {
          bytes.addAll(_safeUtf8Encode('$line\n'));
        }
        bytes.addAll([0x1B, 0x61, 0x00]);
        continue;
      }

      // ── Pelanggan & Sisa Bayar → big + bold ──
      if (_isBigLine(line)) {
        final isSisa = _isRemainingPaymentLine(line);
        final isCust = _isCustLine(line);
        final isStatus = _isStatusLine(line);

        // Strip prefix
        String printLine = line;
        if (isSisa) printLine = line.substring(2);
        if (isCust) printLine = line.substring(8);
        if (isStatus) printLine = line.substring(10);

        // Semuanya center
        bytes.addAll([0x1B, 0x61, 0x01]);

        final int sizeToUse = paperWidth == 88 ? 0x22 : 0x11;

        bytes.addAll([
          0x1D,
          0x21,
          sizeToUse,
        ]); // double height (atau double w+h di 88mm)
        bytes.addAll([0x1B, 0x45, 0x01]);
        bytes.addAll(_safeUtf8Encode('$printLine\n'));
        bytes.addAll([0x1B, 0x45, 0x00]); // bold off
        bytes.addAll([0x1D, 0x21, 0x00]); // normal size
        bytes.addAll([0x1B, 0x61, 0x00]); // back to left
        continue;
      }

      // ── Center line (status, LUNAS, dsb) ──
      if (_isCenterLine(line)) {
        bytes.addAll([0x1B, 0x61, 0x01]);
        bytes.addAll(_safeUtf8Encode('$line\n'));
        bytes.addAll([0x1B, 0x61, 0x00]);
        continue;
      }

      // ── Baris biasa ──
      // Center-align (lihat catatan di blok separator di atas) supaya
      // baris info/item/harga sejajar secara blok ke tengah kertas fisik,
      // bukan nempel kiri.
      bytes.addAll([0x1B, 0x61, 0x01]);
      bytes.addAll(_safeUtf8Encode('$line\n'));
    }
    return bytes;
  }

  List<int> _buildQrCodeBytes(String data, {int paperWidth = 58}) {
    final List<int> bytes = [];
    final qrData = _safeUtf8Encode(data);
    final int dataLength = qrData.length + 3;
    final int qrModuleSize = paperWidth >= 80 ? 7 : 4;
    final int pL = dataLength % 256;
    final int pH = dataLength ~/ 256;

    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, qrModuleSize]);
    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    bytes.addAll(qrData);
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    bytes.addAll([0x0A]);
    bytes.addAll([0x1B, 0x61, 0x00]);

    return bytes;
  }

  bool _isCenterLine(String line) {
    const centerKeywords = [
      'DETAIL PESANAN:',
      'LUNAS',
      'BELUM LUNAS',
      'DP / BELUM LUNAS',
      'CUCIAN SUDAH SELESAI',
      'SIAP DIAMBIL',
    ];
    return centerKeywords.any((k) => line.trim().startsWith(k));
  }

  Future<Map<String, dynamic>> printTestReceipt({
    BuildContext? context,
    int paperWidth = 58,
  }) async {
    if (!_supportsBluetoothPrinter) {
      final message =
          'Fitur printer Bluetooth belum tersedia di perangkat ini.';
     if (context != null) {
        CustomToast.show(context, message: message, isError: true);
     }
     return {'success': false, 'message': message};
   }
   if (!_isConnected && !isIos) {
     if (context != null) {
       CustomToast.show(
         context,
         message: 'Tidak terhubung ke printer',
         isError: true,
       );
     }
     return {'success': false, 'message': 'Tidak terhubung ke printer'};
   }
   if (!_isConnected && isIos) {
     if (context != null) {
       CustomToast.show(
         context,
         message: 'Tidak terhubung ke printer',
         isError: true,
       );
     }
     return {'success': false, 'message': 'Tidak terhubung ke printer'};
   }
   try {
     final int lineChars = paperWidth == 88
         ? 56
         : (paperWidth == 80 ? 48 : 28);
     final String separator = '=' * lineChars;

     final previewText =
         '''
AYOCUCI TEST
$separator
~~CUST~~TEST PRINT
$separator
Printer : ${_connectedDevice?.name ?? "Unknown"}
Ukuran  : ${paperWidth}mm
Date    : ${DateTime.now().toString().substring(0, 19)}
$separator
Cuci Reguler
1 kg x Rp6.000           Rp6.000
~~STATUS~~BELUM LUNAS
~~Kurang: Rp7.000
$separator
TERIMA KASIH''';

     final bytes = _buildEscPosBytes(previewText, paperWidth: paperWidth);
     bytes.addAll([0x1B, 0x64, 0x04]);
     bytes.addAll([0x1D, 0x56, 0x41, 0x00]);

     final initBytes = _buildPrinterInitBytes(paperWidth: paperWidth);
     await PrintBluetoothThermal.writeBytes([...initBytes, ...bytes]);
     if (context != null) {
       CustomToast.show(context, message: 'Test print berhasil!');
     }
     return {'success': true, 'message': 'Test print berhasil!'};
   } catch (e) {
     if (context != null) {
       CustomToast.show(
         context,
         message: 'Print gagal: ${e.toString()}',
         isError: true,
       );
     }
     return {'success': false, 'message': 'Print gagal: ${e.toString()}'};
   }
 }

  @override
  void dispose() {
    PrintBluetoothThermal.disconnect;
    super.dispose();
  }
}
