import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/payroll_provider.dart';

/// Satu baris rincian pada struk gaji.
class PayrollReceiptLine {
  final String label;
  final String value;
  final bool isDeduction;

  const PayrollReceiptLine(this.label, this.value, {this.isDeduction = false});
}

String _displayComponentLabel(String? raw, {required String fallback}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return fallback;
  return value[0].toUpperCase() + value.substring(1);
}

/// Data yang dibutuhkan untuk merender & membagikan struk gaji sebagai gambar.
class PayrollReceiptData {
  final String outletName;
  final String employeeName;
  final String role;
  final String period;
  final String dueDate;
  final String method;
  final String paidAt;
  final List<PayrollReceiptLine> lines;
  final List<PayrollReceiptLine> attendance;
  final String total;

  const PayrollReceiptData({
    required this.outletName,
    required this.employeeName,
    required this.role,
    required this.period,
    required this.dueDate,
    required this.method,
    required this.paidAt,
    required this.lines,
    this.attendance = const [],
    required this.total,
  });
}

class PayrollReceiptShare {
  /// Render struk gaji jadi PNG lalu buka share sheet. Tidak mengunci nomor —
  /// user memilih sendiri kontak WhatsApp tujuan dari share sheet.
  static Future<void> share({
    required BuildContext context,
    required PayrollReceiptData data,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black38,
        pageBuilder: (_, _, _) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 44),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text(
                      'Tunggu sebentar...',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Menyiapkan slip gaji',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final controller = ScreenshotController();
      final imageBytes = await controller.captureFromWidget(
        PayrollReceiptWidget(data: data),
        pixelRatio: 2.5,
        context: context,
      );

      final dir = await getTemporaryDirectory();
      final safeName = data.employeeName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .toLowerCase();
      final file = File('${dir.path}/slip_gaji_$safeName.png');
      await file.writeAsBytes(imageBytes);

      navigator.pop();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: _caption(data),
        ),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membuat struk gaji: $e')),
      );
    }
  }

  /// Render struk gaji jadi file PNG (tanpa share sheet). Dipakai untuk
  /// melampirkan struk otomatis ke record pengeluaran saat pembayaran.
  /// Mengembalikan null bila gagal (pembayaran tetap boleh lanjut tanpa bukti).
  static Future<File?> generateFile({
    required BuildContext context,
    required PayrollReceiptData data,
  }) async {
    try {
      final controller = ScreenshotController();
      final imageBytes = await controller.captureFromWidget(
        PayrollReceiptWidget(data: data),
        pixelRatio: 2.5,
        context: context,
      );
      final dir = await getTemporaryDirectory();
      final safeName = data.employeeName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .toLowerCase();
      final file = File(
        '${dir.path}/slip_gaji_bukti_${safeName}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);
      return file;
    } catch (_) {
      return null;
    }
  }

  // Caption singkat — rincian sudah tercetak di gambar struk.
  static String _caption(PayrollReceiptData data) {
    final name = data.employeeName.trim();
    final greet = name.isNotEmpty ? ' $name' : '';
    return [
      'Halo$greet 👋',
      'Gaji kamu periode ${data.period} sudah kami bayarkan. '
          'Rincian slip gaji ada pada gambar di atas ya.',
      'Terima kasih 🙏',
    ].join('\n\n');
  }
}

/// Bangun [PayrollReceiptData] dari map item payroll. Dipakai bersama oleh
/// layar sukses (share ke WA) dan alur bayar (lampirkan struk ke pengeluaran).
PayrollReceiptData buildPayrollReceiptData({
  required Map<String, dynamic> item,
  required String outletName,
  required String method,
  required String dueDate,
  required String paidAt,
  required String period,
  num Function(dynamic)? num_,
  String Function(num)? formatCurrency,
}) {
  final toNumber = num_ ?? PayrollProvider.toNum;
  final toCurrency = formatCurrency ?? PayrollProvider.formatCurrency;
  final components =
      (item['components'] as List?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
  final baseAmount = toNumber(item['base_amount']);
  final bonusItems = components.where((c) {
    final type = c['type']?.toString().toLowerCase().trim();
    return type != 'base' && type != 'deduction' && toNumber(c['amount']) > 0;
  });
  final deductionItems = components
      .where((c) => c['type']?.toString().toLowerCase().trim() == 'deduction')
      .where((c) => toNumber(c['amount']) > 0);
  final workDays = toNumber(item['work_days']).toInt();
  final alfaDays = toNumber(item['alfa_days']).toInt();
  final leaveDays = toNumber(item['izin_days'] ?? item['leave_days']).toInt();
  final overtimeMinutes = toNumber(item['overtime_minutes']).toInt();
  final attendance = <PayrollReceiptLine>[
    if (workDays > 0) PayrollReceiptLine('Jumlah hadir', '$workDays hari'),
    if (alfaDays > 0) PayrollReceiptLine('Jumlah alfa', '$alfaDays hari'),
    if (leaveDays > 0) PayrollReceiptLine('Jumlah izin', '$leaveDays hari'),
    if (overtimeMinutes > 0)
      PayrollReceiptLine('Lembur', '$overtimeMinutes menit'),
  ];

  final lines = <PayrollReceiptLine>[
    if (baseAmount > 0)
      PayrollReceiptLine(
        PayrollProvider.baseBreakdownText(item) ?? 'Gaji Pokok',
        toCurrency(baseAmount),
      ),
    ...bonusItems.map(
      (c) => PayrollReceiptLine(
        _displayComponentLabel(c['name']?.toString(), fallback: 'Bonus'),
        toCurrency(toNumber(c['amount'])),
      ),
    ),
    ...deductionItems.map(
      (c) => PayrollReceiptLine(
        _displayComponentLabel(c['name']?.toString(), fallback: 'Potongan'),
        '-${toCurrency(toNumber(c['amount']))}',
        isDeduction: true,
      ),
    ),
    if (toNumber(item['bonus_amount']) > 0)
      PayrollReceiptLine(
        'Total Bonus',
        toCurrency(toNumber(item['bonus_amount'])),
      ),
    if (toNumber(item['deduction_amount']) > 0)
      PayrollReceiptLine(
        'Total Potongan',
        '-${toCurrency(toNumber(item['deduction_amount']))}',
        isDeduction: true,
      ),
  ];

  return PayrollReceiptData(
    outletName: outletName,
    employeeName: item['pegawai_nama']?.toString() ?? '-',
    role: item['role_nama']?.toString() ?? '-',
    period: period,
    dueDate: dueDate,
    method: method,
    paidAt: paidAt,
    lines: lines,
    attendance: attendance,
    total: toCurrency(toNumber(item['net_amount'])),
  );
}

/// Kartu struk gaji yang di-render menjadi gambar.
class PayrollReceiptWidget extends StatelessWidget {
  final PayrollReceiptData data;

  const PayrollReceiptWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        color: const Color(0xFFF1F4F9),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF7A3D), Color(0xFFFF5A1F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outlet - ${data.outletName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'SLIP GAJI KARYAWAN',
                      style: TextStyle(
                        color: Color(0xFFFFE7DD),
                        fontSize: 11,
                        fontWeight: AppFont.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.role} - ${data.employeeName}',
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 19,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _metaRow('Periode', data.period),
                    _metaRow('Jadwal Bayar', data.dueDate),
                    _metaRow('Metode', data.method),
                    _metaRow('Tanggal Bayar', data.paidAt),
                    const SizedBox(height: 14),
                    _dashedDivider(),
                    const SizedBox(height: 14),
                    if (data.attendance.isNotEmpty) const Text(
                      'Kehadiran',
                      style: TextStyle(
                        color: AppPalette.ink,
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    if (data.attendance.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...data.attendance.map((line) => _receiptRow(line)),
                      const SizedBox(height: 6),
                      _dashedDivider(),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'Rincian Penghasilan',
                      style: TextStyle(
                        color: AppPalette.ink,
                        fontSize: 13,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...data.lines.map(
                      (line) => _receiptRow(line),
                    ),
                    const SizedBox(height: 4),
                    _dashedDivider(),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total Gaji Bersih',
                              style: TextStyle(
                                color: AppPalette.ink,
                                fontSize: 13,
                                fontWeight: AppFont.w800,
                              ),
                            ),
                          ),
                          Text(
                            data.total,
                            style: const TextStyle(
                              color: AppPalette.primary,
                              fontSize: 19,
                              fontWeight: AppFont.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppPalette.muted.withValues(alpha: 0.8),
                            fontSize: 10.5,
                            fontWeight: AppFont.w600,
                          ),
                          children: [
                            const TextSpan(text: 'Dibayarkan melalui '),
                            const TextSpan(
                              text: 'AyoCuci',
                              style: TextStyle(color: AppPalette.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 12.5,
                fontWeight: AppFont.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(PayrollReceiptLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(line.label, style: const TextStyle(color: AppPalette.ink, fontSize: 13, fontWeight: AppFont.w600))),
          const SizedBox(width: 12),
          Text(line.value, textAlign: TextAlign.right, style: TextStyle(color: line.isDeduction ? AppPalette.primary : AppPalette.ink, fontSize: 13, fontWeight: AppFont.w800)),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1.4,
              color: const Color(0xFFE3E7EE),
            ),
          ),
        );
      },
    );
  }
}
