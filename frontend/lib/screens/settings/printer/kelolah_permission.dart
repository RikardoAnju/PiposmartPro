import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/data/models/printer_device_model.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/permission_provider.dart';

class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PermissionPageContent();
  }
}

class _PermissionPageContent extends StatefulWidget {
  const _PermissionPageContent();

  @override
  State<_PermissionPageContent> createState() => _PermissionPageContentState();
}

class _PermissionPageContentState extends State<_PermissionPageContent> {
  bool _hasShownPlatformInfo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PermissionProvider>();
      provider.initialize();
      _showPlatformInfoOnce(provider);
    });
  }

  void _showPlatformInfoOnce(PermissionProvider provider) {
    if (_hasShownPlatformInfo || !mounted) return;
    _hasShownPlatformInfo = true;
    CustomToast.show(context, message: provider.platformIntroMessage);
  }

  Future<void> _handleRequestPermission() async {
    final provider = context.read<PermissionProvider>();
    if (!provider.supportsBluetoothPrinter) {
      CustomToast.show(
        context,
        message: 'Printer Bluetooth belum didukung di iOS.',
        isError: true,
      );
      return;
    }
    CustomToast.show(context, message: 'Meminta izin Bluetooth...');
    final result = await provider.requestBluetoothPermission();
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['success']!
          ? 'Semua permission berhasil diberikan!'
          : 'Beberapa permission ditolak',
      isError: !result['success']!,
    );
  }

  Future<void> _handleScanBluetooth() async {
    final provider = context.read<PermissionProvider>();
    if (!provider.supportsBluetoothPrinter) {
      CustomToast.show(
        context,
        message: 'Printer Bluetooth belum didukung di iOS.',
        isError: true,
      );
      return;
    }
    CustomToast.show(context, message: 'Memulai scan Bluetooth...');
    final result = await provider.scanBluetooth();
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message'],
      isError: !result['success'],
    );
  }

  Future<void> _handleConnect(PrinterDevice device) async {
    final provider = context.read<PermissionProvider>();
    if (!provider.supportsBluetoothPrinter) {
      CustomToast.show(
        context,
        message: 'Printer Bluetooth belum didukung di iOS.',
        isError: true,
      );
      return;
    }
    CustomToast.show(context, message: 'Menghubungkan ke ${device.name}...');
    final result = await provider.connectToPrinter(device);
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message'],
      isError: !result['success'],
    );
  }

  Future<void> _handleDisconnect() async {
    await context.read<PermissionProvider>().disconnect();
    if (!mounted) return;
    CustomToast.show(context, message: 'Terputus dari printer', isError: true);
  }

  Future<void> _handleTestPrint() async {
    final provider = context.read<PermissionProvider>();
    if (!provider.supportsBluetoothPrinter) {
      CustomToast.show(
        context,
        message: 'Printer Bluetooth belum didukung di iOS.',
        isError: true,
      );
      return;
    }
    CustomToast.show(context, message: 'Mencetak test receipt...');
    final result = await provider.printTestReceipt();
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message'],
      isError: !result['success'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bluetooth Printer',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
        ),
      ),
      body: Consumer<PermissionProvider>(
        builder: (context, provider, child) {
          final isIos = provider.isIos;
          final isUnavailable = !provider.supportsBluetoothPrinter;
          final permissionSummary = isIos
              ? 'Tidak perlu izin tambahan'
              : [
                  provider.permissions['Bluetooth Connection'],
                  provider.permissions['Bluetooth Scan'],
                  provider.permissions['Fine Location'],
                ].every((item) => item == 'Diizinkan')
              ? 'Siap digunakan'
              : 'Belum lengkap';

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (isUnavailable)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Fitur printer belum tersedia di perangkat ini.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Permission Status Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildPermissionItem(
                        'Permission',
                        permissionSummary,
                        isRed: !isIos && permissionSummary != 'Siap digunakan',
                      ),
                      _buildDivider(),
                      _buildPermissionItem(
                        'Status Koneksi',
                        provider.isConnected
                            ? 'Terhubung: ${provider.connectedDevice?.name ?? "Unknown"}'
                            : isIos
                            ? 'AirPrint / PDF siap dipakai'
                            : 'Tidak Terhubung',
                        isRed: !provider.isConnected && !isIos,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Button Minta Izin
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUnavailable || !provider.requiresBluetoothPermission
                        ? null
                        : _handleRequestPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85C40),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Minta Izin Bluetooth',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Button Scan
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.isScanning || isUnavailable
                        ? null
                        : _handleScanBluetooth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85C40),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: provider.isScanning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: AppCircularLoader(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            provider.platformScannerLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Test Print & Disconnect
                if (!isUnavailable)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleTestPrint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E9E63),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Test Print',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: provider.isConnected ? _handleDisconnect : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            disabledBackgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Putuskan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Device List
                Expanded(
                  child: isUnavailable
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_disabled,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Printer belum tersedia',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Coba lagi di perangkat yang mendukung fitur ini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : provider.foundDevices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_searching,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada perangkat',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.platformEmptyMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: provider.foundDevices.length,
                          itemBuilder: (context, index) {
                            final PrinterDevice device =
                                provider.foundDevices[index];
                            final bool isConnected =
                                provider.isConnected &&
                                provider.connectedDevice?.address == device.address;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isConnected
                                    ? Border.all(color: Colors.green, width: 2)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Icon(
                                  provider.getDeviceIcon(device),
                                  color: isConnected
                                      ? Colors.green
                                      : const Color(0xFFE85C40),
                                  size: 32,
                                ),
                                title: Text(
                                  device.name.isNotEmpty
                                      ? device.name
                                      : 'Unknown Device',
                                  style: TextStyle(
                                    color: isConnected
                                        ? Colors.green
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      device.address,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (isConnected)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Connected',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing:
                                    provider.isDeviceConnecting(
                                      device.address,
                                    )
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: AppCircularLoader(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: isConnected
                                            ? null
                                            : () => _handleConnect(device),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isConnected
                                              ? Colors.grey
                                              : const Color(0xFFE85C40),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Text(
                                          isConnected ? 'Connected' : 'Connect',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionItem(
    String title,
    String value, {
    bool isRed = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, isLast ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isRed ? Colors.red[300] : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: isRed ? Colors.red[300] : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }
}
