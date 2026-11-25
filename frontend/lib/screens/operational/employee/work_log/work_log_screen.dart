import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/providers/work_log_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_employee_picker.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_employee_view.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_stage_detail.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_shimmer.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';

class WorkLogScreen extends StatefulWidget {
  const WorkLogScreen({super.key});

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID');
    context.read<WorkLogProvider>().resetView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final isEmployee = _isEmployeeAccount(auth);
      final hasAddon = context.read<AddonProvider>().isFeatureActive(
        'KARYAWAN_PERFORMANCE',
      );
      if (!hasAddonAccess(context: context, hasAddon: hasAddon)) return;
      context.read<WorkLogProvider>().load(
        employeeProvider: context.read<PegawaiProvider>(),
        transactionProvider: context.read<TransactionProvider>(),
        employeeId: !isEmployee ? null : context.read<AuthProvider>().actorId,
        selfEmployee: isEmployee
            ? Pegawai(
                id: auth.actorId ?? 'self',
                outletId: '',
                roleId: '',
                nama: auth.userName ?? 'Karyawan',
                email: '',
                nohp: '',
                status: 1,
                type: 'base',
                createdAt: DateTime.now(),
              )
            : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'KARYAWAN_PERFORMANCE',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );

    if (!canAccessAddonFeature) {
      return AppScaffold(
        backgroundColor: AppPalette.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppPalette.ink,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Performa Karyawan',
            style: TextStyle(
              color: AppPalette.ink,
              fontWeight: AppFont.w800,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
        ),
        body: AddonLockedPlaceholder(
          title: 'Add-on Karyawan Performance',
          message:
              'Aktifkan add-on Karyawan Performance untuk memantau performa, produktivitas, dan analisis pekerjaan karyawan secara mendalam.',
          features: const [
            'Pemantauan aktivitas dan log kerja karyawan',
            'Analisis produktivitas per tahap pengerjaan',
            'Laporan performa dan penanganan transaksi',
          ],
          onActionTap: () => Navigator.pushNamed(context, '/aktivasi-akun'),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    final workLog = context.watch<WorkLogProvider>();
    final isEmployee = _isEmployeeAccount(auth);
    if (isEmployee &&
        workLog.selectedEmployee == null &&
        workLog.employees.isNotEmpty) {
      final ownId = auth.actorId?.trim();
      final ownName = auth.userName?.trim().toLowerCase();
      final ownEmployee = workLog.employees.where((employee) {
        // ID adalah identitas utama. Nama hanya fallback untuk token lama.
        if (ownId != null && ownId.isNotEmpty && employee.id == ownId) {
          return true;
        }
        return (ownId == null || ownId.isEmpty) &&
            employee.nama.trim().toLowerCase() == ownName;
      });
      if (ownEmployee.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && workLog.selectedEmployee == null) {
            workLog.selectEmployee(ownEmployee.first);
          }
        });
      }
    }

    return PopScope(
      canPop:
          isEmployee ||
          (workLog.selectedStage == null && !workLog.hasSelectedEmployee),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isEmployee) {
          Navigator.pop(context);
          return;
        }
        if (workLog.selectedStage != null) {
          workLog.clearSelectedStage();
        } else if (workLog.hasSelectedEmployee) {
          workLog.clearSelectedEmployee();
        }
      },
      child: AppScaffold(
        backgroundColor: AppPalette.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppPalette.ink,
              size: 20,
            ),
            onPressed: () {
              if (isEmployee) {
                Navigator.pop(context);
                return;
              }
              if (workLog.selectedStage != null) {
                workLog.clearSelectedStage();
              } else if (workLog.hasSelectedEmployee) {
                workLog.clearSelectedEmployee();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            workLog.selectedEmployee == null
                ? 'Performa Karyawan'
                : workLog.selectedEmployee!.nama,
            style: const TextStyle(
              color: AppPalette.ink,
              fontWeight: AppFont.w800,
              fontSize: 17,
            ),
          ),
          actions: [
            if (workLog.hasSelectedEmployee && !isEmployee)
              IconButton(
                tooltip: 'Download laporan',
                icon: const Icon(
                  Icons.description_outlined,
                  color: AppPalette.primary,
                ),
                onPressed: _showExportSheet,
              ),
          ],
        ),
        body: isEmployee && workLog.isLoading
            ? const WorkLogEmployeeViewShimmer()
            : isEmployee && !workLog.hasSelectedEmployee
            ? _EmployeePerformanceLoadState(
                message:
                    workLog.errorMessage ??
                    (workLog.employees.isEmpty
                        ? 'Data karyawan belum tersedia.'
                        : 'Data karyawan Anda belum ditemukan.'),
                onRetry: () => workLog.refresh(),
              )
            : !workLog.hasSelectedEmployee
            ? WorkLogEmployeePicker(workLog: workLog)
            : workLog.selectedStage != null
            ? WorkLogStageDetail(workLog: workLog)
            : WorkLogEmployeeView(workLog: workLog),
      ),
    );
  }

  Future<void> _showExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan performa karyawan.',
        onExportPdf: () {
          Navigator.pop(sheetContext);
          _exportPerformance('pdf');
        },
        onExportExcel: () {
          Navigator.pop(sheetContext);
          _exportPerformance('excel');
        },
      ),
    );
  }

  Future<void> _exportPerformance(String format) async {
    if (_isExporting) return;
    final workLog = context.read<WorkLogProvider>();
    final employee = workLog.selectedEmployee;
    if (employee == null) return;
    setState(() => _isExporting = true);
    try {
      final range = workLog.selectedRange;
      final rangeLabel =
          '${DateFormat('d MMM yyyy', 'id_ID').format(range.start)} - '
          '${DateFormat('d MMM yyyy', 'id_ID').format(range.end)}';
      final reportRows = workLog.performanceReportRows.where((row) {
        final status = (row['status'] ?? '').toLowerCase();
        // Status pembayaran bukan aktivitas kerja baru. Jangan membuat
        // pelanggan muncul dua kali hanya karena transaksi dilunasi.
        final isPaymentStatus =
            status.contains('lunas') ||
            status.contains('pelunasan') ||
            status == 'dibayar' ||
            status == 'bayar';
        return !isPaymentStatus;
      }).toList();
      final rows = reportRows
          .map(
            (row) => [
              row['invoice'] ?? '-',
              row['customer'] ?? '-',
              row['status'] ?? '-',
              row['date'] ?? '-',
            ],
          )
          .toList();
      final quantities = workLog.totalQuantities;
      String quantityValue(String unit) {
        final value = quantities[unit] ?? 0;
        return value % 1 == 0
            ? value.toInt().toString()
            : value.toStringAsFixed(1);
      }

      final logo = format == 'pdf'
          ? await ReportExportService.loadLogoBytes()
          : null;
      final document = ReportPdfDocument(
        title: 'Laporan Performa Karyawan',
        subtitle: 'Rekap aktivitas karyawan berdasarkan periode terpilih.',
        periodLabel: rangeLabel,
        rangeLabel: rangeLabel,
        generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
        primaryValue: '${reportRows.length} aktivitas',
        primaryCaption: 'Karyawan: ${employee.nama}',
        metrics: [
          ReportPdfMetric(
            title: 'Pelanggan',
            value: '${workLog.customerCount}',
            background: PdfColor.fromHex('#FFF0EC'),
            accent: PdfColor.fromHex(AppPalette.primaryHex),
          ),
          ReportPdfMetric(
            title: 'Layanan',
            value: '${workLog.serviceCount}',
            background: PdfColor.fromHex('#E9F8F1'),
            accent: PdfColor.fromHex('#18B979'),
          ),
          ReportPdfMetric(
            title: 'Selesai',
            value: '${workLog.completedCount}',
            background: PdfColor.fromHex('#EAF5FF'),
            accent: PdfColor.fromHex('#2999E8'),
          ),
          ReportPdfMetric(
            title: 'Kilogram',
            value: quantityValue('kg'),
            background: PdfColor.fromHex('#F1ECFF'),
            accent: PdfColor.fromHex('#8B5CF6'),
          ),
          ReportPdfMetric(
            title: 'Pcs',
            value: quantityValue('pcs'),
            background: PdfColor.fromHex('#EAFBFD'),
            accent: PdfColor.fromHex('#06B6D4'),
          ),
          ReportPdfMetric(
            title: 'Meter',
            value: quantityValue('meter'),
            background: PdfColor.fromHex('#FFF8E8'),
            accent: PdfColor.fromHex('#F59E0B'),
          ),
        ],
        tables: [
          ReportPdfTable(
            title: 'Aktivitas Transaksi',
            headers: const ['Invoice', 'Pelanggan', 'Status', 'Tanggal'],
            rows: rows,
          ),
        ],
        logoBytes: logo,
      );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      if (format == 'pdf') {
        await ReportExportService.exportPdf(
          context: context,
          document: document,
          fileName: 'laporan_performa_${employee.nama}_$stamp.pdf',
          shareTitle: 'Laporan Performa Karyawan',
        );
      } else {
        await ReportExportService.exportExcel(
          context: context,
          document: document,
          fileName: 'laporan_performa_${employee.nama}_$stamp.xlsx',
          shareTitle: 'Laporan Performa Karyawan',
        );
      }
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Gagal export laporan: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  bool _isEmployeeAccount(AuthProvider auth) {
    final actorType = auth.actorType?.trim().toLowerCase();
    final role = auth.userRole?.trim().toLowerCase();
    return actorType == 'pegawai' ||
        actorType == 'karyawan' ||
        role == 'pegawai' ||
        role == 'karyawan';
  }
}

class _EmployeePerformanceLoadState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EmployeePerformanceLoadState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 42, color: AppPalette.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.ink,
                fontWeight: AppFont.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
