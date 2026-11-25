import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/notaprint_provider.dart';
import 'package:ayocucinew/providers/permission_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/screens/settings/printer/kelolah_permission.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/send_nota_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';

class DetailBottomNavWidget extends StatelessWidget {
  final VoidCallback? onEdit;
  final String? orderStatus;
  final VoidCallback? onExternalNavigation;

  const DetailBottomNavWidget({super.key, this.onEdit, this.orderStatus, this.onExternalNavigation});

  bool get _canEdit {
    final status = orderStatus?.toLowerCase() ?? '';
    return status == 'antrian' || status == 'proses';
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    final trx = context.read<TransactionProvider>().currentDetail;
    if (trx == null) {
      CustomToast.show(context, message: 'Data transaksi tidak tersedia', isError: true);
      return;
    }

    final isBusiness = await showDialog<bool>(context: context, builder: (ctx) => const _WhatsAppChooserDialog());

    if (isBusiness == null || !context.mounted) return;

    final nota = context.read<NotaPrintProvider>().getNota(context);

    onExternalNavigation?.call();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SendNotaBottomSheet(
        hostContext: context,
        snapshot: trx.toJson(),
        customer: trx.customer,
        nota: nota,
        isBusiness: isBusiness,
      ),
    );

    if (!context.mounted) return;
    final error = context.read<NotaPrintProvider>().lastError;
    if (error != null) {
      CustomToast.show(context, message: error, isError: true);
      context.read<NotaPrintProvider>().clearError();
    }
  }

  Future<void> _navigateToPrintPage(BuildContext context) async {
    final permProvider = context.read<PermissionProvider>();
    final isConnected = await permProvider.refreshConnectionStatus();
    if (!context.mounted) return;
    if (!isConnected) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionPage()));
    }
    final isConnectedAfterPage = await permProvider.refreshConnectionStatus();
    if (context.mounted && isConnectedAfterPage) {
      _showPrintOptions(context);
    }
  }

  void _showPrintOptions(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _PrintOptionsSheet());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            _NavButton(
              iconWidget: Icon(Icons.edit_outlined, size: 20, color: _canEdit ? AppColors.green : Colors.grey.shade400),
              label: 'Edit Pesanan',
              bgColor: _canEdit ? AppColors.greenLight : Colors.grey.shade100,
              iconColor: _canEdit ? AppColors.green : Colors.grey.shade400,
              onTap: _canEdit ? onEdit : null,
            ),
            const SizedBox(width: 8),
            _NavButton(
              iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, size: 20, color: AppColors.green),
              label: 'Kirim Struk',
              bgColor: AppColors.greenLight,
              iconColor: AppColors.green,
              onTap: () => _sendWhatsApp(context),
            ),
            const SizedBox(width: 8),
            _NavButton(
              iconWidget: const Icon(Icons.print_outlined, size: 20, color: AppColors.primary),
              label: 'Print Nota',
              bgColor: AppColors.primaryLight,
              iconColor: AppColors.primary,
              onTap: () => _navigateToPrintPage(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _NavButton({
    required this.iconWidget,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: AppFont.w600, color: iconColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsAppChooserDialog extends StatefulWidget {
  const _WhatsAppChooserDialog();

  @override
  State<_WhatsAppChooserDialog> createState() => _WhatsAppChooserDialogState();
}

class _WhatsAppChooserDialogState extends State<_WhatsAppChooserDialog> {
  String? _warningMessage;
  bool _isChecking = false;

  Future<void> _handleOptionTap(bool isBusiness) async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _warningMessage = null;
    });

    final provider = context.read<NotaPrintProvider>();
    final isInstalled = await provider.isWhatsAppInstalled(isBusiness: isBusiness);

    if (!mounted) return;

    if (isInstalled) {
      Navigator.pop(context, isBusiness);
      return;
    }

    setState(() {
      _isChecking = false;
      _warningMessage = provider.getWhatsAppUnavailableMessage(isBusiness: isBusiness);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.whatsapp, size: 32, color: AppColors.green),
              const SizedBox(height: 12),
              const Text('Kirim via WhatsApp', style: TextStyle(fontSize: 16, fontWeight: AppFont.w700)),
              const SizedBox(height: 6),
              const Text(
                'Pilih aplikasi WhatsApp yang ingin digunakan',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_warningMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFC107)),
                  ),
                  child: Text(
                    _warningMessage!,
                    style: const TextStyle(fontSize: 12, fontWeight: AppFont.w500, color: Color(0xFF8A5A00)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _WhatsAppOption(
                      label: 'WhatsApp',
                      sublabel: 'Personal',
                      color: AppColors.green,
                      bgColor: AppColors.greenLight,
                      onTap: () => _handleOptionTap(false),
                      isLoading: _isChecking,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WhatsAppOption(
                      label: 'WA Business',
                      sublabel: 'Bisnis',
                      color: AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      onTap: () => _handleOptionTap(true),
                      isLoading: _isChecking,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsAppOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isLoading;

  const _WhatsAppOption({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 28,
                height: 28,
                child: AppCircularLoader(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(color)),
              )
            else
              FaIcon(FontAwesomeIcons.whatsapp, size: 28, color: color),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: AppFont.w700, color: color),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(sublabel, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintOptionsSheetState extends State<_PrintOptionsSheet> {
  Future<void> _print() async {
    final notaProvider = context.read<NotaPrintProvider>();
    final permProvider = context.read<PermissionProvider>();
    final trx = context.read<TransactionProvider>().currentDetail;

    if (trx == null) {
      CustomToast.show(context, message: 'Data transaksi tidak tersedia', isError: true);
      return;
    }

    final isConnected = await permProvider.refreshConnectionStatus();
    if (!mounted) return;
    if (!isConnected) {
      Navigator.pop(context);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PermissionPage()),
      );
      return;
    }

    await notaProvider.printNota(
      context: context,
      snapshot: trx.toJson(),
      customer: trx.customer,
    );

    if (!mounted) return;

    final error = notaProvider.lastError;
    if (error != null) {
      CustomToast.show(context, message: error, isError: true);
      notaProvider.clearError();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<PermissionProvider>().connectedDevice;
    final isPrinting = context.watch<NotaPrintProvider>().isPrinting;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Print Nota', style: TextStyle(fontSize: 16, fontWeight: AppFont.w700)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.print, color: AppColors.green, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        device?.name ?? 'Printer Terhubung',
                        style: const TextStyle(fontWeight: AppFont.w600, color: AppColors.green),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPrinting ? null : _print,
                  icon: isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: AppCircularLoader(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Cetak Nota'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintOptionsSheet extends StatefulWidget {
  const _PrintOptionsSheet();

  @override
  State<_PrintOptionsSheet> createState() => _PrintOptionsSheetState();
}
