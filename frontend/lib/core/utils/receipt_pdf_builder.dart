import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptPdfBuilder {
  static Future<Uint8List> build({
    required String receiptText,
    String title = 'AyoCuci Receipt',
    int paperWidth = 58,
    String? logoUrl,
    String? qrData,
  }) async {
    final doc = pw.Document();
    final logoWidget = logoUrl != null && logoUrl.isNotEmpty
        ? await _buildLogoWidget(logoUrl, paperWidth: paperWidth)
        : null;
    final pageWidth = paperWidth == 88
        ? 88 * PdfPageFormat.mm
        : paperWidth == 80
        ? 80 * PdfPageFormat.mm
        : 58 * PdfPageFormat.mm;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(
          pageWidth,
          PdfPageFormat.a4.height,
          marginLeft: 2 * PdfPageFormat.mm,
          marginRight: 2 * PdfPageFormat.mm,
          marginTop: 2 * PdfPageFormat.mm,
          marginBottom: 2 * PdfPageFormat.mm,
        ),
        theme: pw.ThemeData.withFont(
          base: pw.Font.courier(),
          bold: pw.Font.courierBold(),
        ),
        build: (context) => [
          if (logoWidget != null) ...[
            logoWidget,
            pw.SizedBox(height: 4),
          ],
          ..._buildLineWidgets(receiptText),
          if (qrData != null && qrData.isNotEmpty) ...[
            pw.SizedBox(height: 7),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: paperWidth == 88
                        ? 22 * PdfPageFormat.mm
                        : paperWidth == 80
                        ? 18 * PdfPageFormat.mm
                        : 13 * PdfPageFormat.mm,
                    height: paperWidth == 88
                        ? 22 * PdfPageFormat.mm
                        : paperWidth == 80
                        ? 18 * PdfPageFormat.mm
                        : 13 * PdfPageFormat.mm,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Powered By AyoCuci POS',
                    style: const pw.TextStyle(fontSize: 7.6),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'Powered By AyoCuci POS',
                style: const pw.TextStyle(fontSize: 7.6),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static List<pw.Widget> _buildLineWidgets(String receiptText) {
    final lines = receiptText.replaceAll('\r\n', '\n').split('\n');
    final widgets = <pw.Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      final normalized = line.trim();

      if (normalized.isEmpty) {
        widgets.add(pw.SizedBox(height: 2));
        continue;
      }

      if (normalized.startsWith('===') || normalized.startsWith('---')) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Divider(thickness: 0.45, color: PdfColors.grey700),
          ),
        );
        continue;
      }

      final isBigLine = normalized.startsWith('Pelanggan') || normalized.startsWith('~~Kurang') || normalized.startsWith('~~STATUS~~') || normalized.startsWith('~~CUST~~');
      final isCustomerLine = normalized.startsWith('~~CUST~~');
      final isStatusOrBalanceLine =
          normalized.startsWith('~~Kurang') ||
          normalized.startsWith('~~STATUS~~');
      final isCenterLine = _isCenterLine(normalized) || normalized == 'MERCHANT' || normalized == 'CUSTOMER' || normalized == 'CUSTOMER COPY';
      final isHeader = i == 0 || normalized == 'AyoCuci Laundry';

      String text = line;
      if (normalized.startsWith('~~Kurang')) text = text.replaceFirst('~~', '');
      if (normalized.startsWith('~~STATUS~~')) text = text.replaceFirst('~~STATUS~~', '');
      if (normalized.startsWith('~~CUST~~')) text = text.replaceFirst('~~CUST~~', '');

      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Align(
            alignment: isCenterLine || isBigLine || isHeader ? pw.Alignment.center : pw.Alignment.centerLeft,
            child: pw.Text(
              text,
              textAlign: isCenterLine || isBigLine || isHeader ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: isCustomerLine
                    ? 11.5
                    : isStatusOrBalanceLine
                    ? 10.8
                    : isHeader
                    ? 10
                    : 8.6,
                fontWeight: isBigLine || isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                height: 1.15,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  static Future<pw.Widget> _buildLogoWidget(
    String logoUrl, {
    required int paperWidth,
  }) async {
    try {
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return pw.SizedBox.shrink();
      }

      final image = pw.MemoryImage(response.bodyBytes);
      final maxWidth = paperWidth == 88
          ? 24 * PdfPageFormat.mm
          : paperWidth == 80
          ? 22 * PdfPageFormat.mm
          : 18 * PdfPageFormat.mm;

      return pw.Center(
        child: pw.Container(
          width: maxWidth,
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      );
    } catch (_) {
      return pw.SizedBox.shrink();
    }
  }

  static bool _isCenterLine(String line) {
    const centerKeywords = [
      'DETAIL PESANAN:',
      'LUNAS',
      'BELUM LUNAS',
      'DP / BELUM LUNAS',
      'CUCIAN SUDAH SELESAI',
      'SIAP DIAMBIL',
      'TEST PRINT',
      'TERIMA KASIH',
      'Powered By AyoCuci POS',
      'Scan untuk lihat nota:',
    ];
    return centerKeywords.any((k) => line.startsWith(k));
  }
}
