import 'dart:io';
import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:pdf/pdf.dart';

void main() async {
  final logo = await File('assets/icons/logo/logo_final.webp').readAsBytes();
  final bytes = await ReportExportBuilder.buildPdf(
    ReportPdfDocument(
      title: 'Test Laporan',
      subtitle: 'Verifikasi template PDF AyoCuci.',
      periodLabel: 'Mei 2026',
      rangeLabel: '2026-05-01 s/d 2026-05-31',
      filterLabel: 'Semua Data',
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(
        DateTime(2026, 5, 18, 15, 10),
      ),
      primaryValue: ReportExportBuilder.formatRupiah(35000),
      primaryCaption: 'Nilai utama periode ini',
      metrics: const [
        ReportPdfMetric(
          title: 'A',
          value: '1',
          background: PdfColors.white,
          accent: PdfColors.black,
        ),
        ReportPdfMetric(
          title: 'B',
          value: '2',
          background: PdfColors.white,
          accent: PdfColors.black,
        ),
      ],
      tables: const [
        ReportPdfTable(
          title: 'Tabel Uji',
          subtitle: 'Memastikan renderer tabel tetap valid.',
          headers: ['Kolom 1', 'Kolom 2'],
          rows: [
            ['Baris 1', 'Nilai 1'],
            ['Baris 2', 'Nilai 2'],
          ],
        ),
      ],
      logoBytes: logo,
    ),
  );
  final file = File('/tmp/ayocuci_generic_report_test.pdf');
  await file.writeAsBytes(bytes, flush: true);
  print(file.path);
}
