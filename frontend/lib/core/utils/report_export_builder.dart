import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReportPdfMetric {
  final String title;
  final String value;
  final PdfColor background;
  final PdfColor accent;

  const ReportPdfMetric({
    required this.title,
    required this.value,
    required this.background,
    required this.accent,
  });
}

class ReportPdfTable {
  final String title;
  final String? subtitle;
  final List<String> headers;
  final List<List<String>> rows;

  const ReportPdfTable({
    required this.title,
    this.subtitle,
    required this.headers,
    required this.rows,
  });
}

class ReportPdfDocument {
  final String appName;
  final String title;
  final String subtitle;
  final String periodLabel;
  final String? rangeLabel;
  final String? filterLabel;
  final String? generatedAtLabel;
  final String primaryValue;
  final String primaryCaption;
  final List<ReportPdfMetric> metrics;
  final List<ReportPdfTable> tables;
  final Uint8List? logoBytes;

  const ReportPdfDocument({
    this.appName = 'AyoCuci',
    required this.title,
    required this.subtitle,
    required this.periodLabel,
    this.rangeLabel,
    this.filterLabel,
    this.generatedAtLabel,
    required this.primaryValue,
    required this.primaryCaption,
    required this.metrics,
    required this.tables,
    this.logoBytes,
  });
}

class ReportExportBuilder {
  static String sanitizeText(String raw, {String fallback = '-'}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\uFE00-\uFE0F]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s.,:/@+\-()&]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static String formatTableDate(dynamic raw) {
    if (raw == null) return '-';
    final text = raw.toString().trim();
    if (text.isEmpty || text == '-') return '-';

    try {
      final normalized = text.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy', 'id_ID').format(parsed.toLocal());
      }
    } catch (_) {}

    try {
      final dateOnly = text.contains('T')
          ? text.split('T').first
          : text.contains(' ')
          ? text.split(' ').first
          : text;
      final parts = dateOnly.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateFormat(
            'dd MMM yyyy',
            'id_ID',
          ).format(DateTime(year, month, day));
        }
      }
    } catch (_) {}

    return text;
  }

  static String formatShortTableDate(dynamic raw) {
    if (raw == null) return '-';
    final text = raw.toString().trim();
    if (text.isEmpty || text == '-') return '-';

    DateTime? parsed;
    try {
      parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    } catch (_) {}

    parsed ??= _parseIndonesianDisplayDate(text);
    if (parsed != null) {
      return DateFormat('dd/MM/yy', 'id_ID').format(parsed.toLocal());
    }

    return text;
  }

  static DateTime? _parseIndonesianDisplayDate(String text) {
    final normalized = text.trim();
    final slashMatch = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$',
    ).firstMatch(normalized);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      var year = int.tryParse(slashMatch.group(3)!);
      if (year != null && year < 100) year += 2000;
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final monthNames = <String, int>{
      'jan': 1,
      'januari': 1,
      'feb': 2,
      'februari': 2,
      'mar': 3,
      'maret': 3,
      'apr': 4,
      'april': 4,
      'mei': 5,
      'jun': 6,
      'juni': 6,
      'jul': 7,
      'juli': 7,
      'agu': 8,
      'agustus': 8,
      'sep': 9,
      'september': 9,
      'okt': 10,
      'oktober': 10,
      'nov': 11,
      'november': 11,
      'des': 12,
      'desember': 12,
    };
    final parts = normalized.toLowerCase().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final day = int.tryParse(parts[0]);
      final month = monthNames[parts[1]];
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static Uint8List buildExcel(ReportPdfDocument documentData) {
    final excel = Excel.createExcel();
    const defaultSheetName = 'Sheet1';
    final sheetName = _sanitizeSheetName(documentData.title);
    if (sheetName != defaultSheetName) {
      excel.rename(defaultSheetName, sheetName);
    }
    final sheet = excel[sheetName];

    final maxTableColumns = documentData.tables.fold<int>(
      0,
      (max, table) => table.headers.length > max ? table.headers.length : max,
    );
    final totalColumns = maxTableColumns >= 6 ? maxTableColumns : 6;
    final lastColumnIndex = totalColumns - 1;

    for (var i = 0; i < totalColumns; i++) {
      sheet.setColumnWidth(
        i,
        _columnWidthFor(i, documentData.tables, totalColumns),
      );
    }

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('FFF4593B'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final subtitleStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('FFF4593B'),
      textWrapping: TextWrapping.WrapText,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final sectionStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.fromHexString('FF2A211F'),
      backgroundColorHex: ExcelColor.fromHexString('FFFDEAE5'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final labelStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('FF7A5B53'),
      backgroundColorHex: ExcelColor.fromHexString('FFFDF5F2'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final valueStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('FF2A211F'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final primaryLabelStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('FFF4593B'),
      backgroundColorHex: ExcelColor.fromHexString('FFFFF1EC'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final primaryValueStyle = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: ExcelColor.fromHexString('FFF4593B'),
      backgroundColorHex: ExcelColor.fromHexString('FFFFF7F4'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('FFF4593B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder('FFFFD6CC'),
      rightBorder: _thinBorder('FFFFD6CC'),
      topBorder: _thinBorder('FFFFD6CC'),
      bottomBorder: _thinBorder('FFFFD6CC'),
    );
    final bodyStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('FF2A211F'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: _thinBorder('FFF3E1DA'),
      rightBorder: _thinBorder('FFF3E1DA'),
      topBorder: _thinBorder('FFF3E1DA'),
      bottomBorder: _thinBorder('FFF3E1DA'),
    );

    var row = 0;

    _mergeWrite(
      sheet,
      row,
      0,
      row,
      lastColumnIndex,
      documentData.title,
      titleStyle,
    );
    sheet.setRowHeight(row, 28);
    row++;

    _mergeWrite(
      sheet,
      row,
      0,
      row,
      lastColumnIndex,
      documentData.subtitle,
      subtitleStyle,
    );
    sheet.setRowHeight(row, 32);
    row += 2;

    final periodText = documentData.periodLabel.trim();
    final rangeText = documentData.rangeLabel?.trim() ?? '';
    final hasDistinctRange =
        rangeText.isNotEmpty && !_sameMetadataValue(rangeText, periodText);

    final metadata = <List<String>>[
      ['Aplikasi', documentData.appName],
      ['Periode', documentData.periodLabel],
      if (hasDistinctRange) ['Rentang Tanggal', documentData.rangeLabel!],
      if (documentData.filterLabel != null &&
          documentData.filterLabel!.isNotEmpty)
        ['Filter Aktif', documentData.filterLabel!],
      if (documentData.generatedAtLabel != null &&
          documentData.generatedAtLabel!.isNotEmpty)
        ['Diekspor Pada', documentData.generatedAtLabel!],
    ];

    for (final item in metadata) {
      _writeCell(sheet, row, 0, item[0], labelStyle);
      _mergeWrite(sheet, row, 1, row, lastColumnIndex, item[1], valueStyle);
      row++;
    }

    row++;

    _mergeWrite(
      sheet,
      row,
      0,
      row,
      lastColumnIndex,
      documentData.primaryCaption,
      primaryLabelStyle,
    );
    row++;
    _mergeWrite(
      sheet,
      row,
      0,
      row,
      lastColumnIndex,
      documentData.primaryValue,
      primaryValueStyle,
    );
    sheet.setRowHeight(row, 26);
    row += 2;

    if (documentData.metrics.isNotEmpty) {
      _mergeWrite(
        sheet,
        row,
        0,
        row,
        lastColumnIndex,
        'Ringkasan',
        sectionStyle,
      );
      row++;
      for (var i = 0; i < documentData.metrics.length; i += 3) {
        final chunk = documentData.metrics.skip(i).take(3).toList();
        row = _writeMetricGridRow(
          sheet,
          row,
          chunk,
          totalColumns,
          headerStyle,
          bodyStyle,
        );
        row++;
      }
      row++;
    }

    for (final table in documentData.tables) {
      _mergeWrite(
        sheet,
        row,
        0,
        row,
        lastColumnIndex,
        table.title,
        sectionStyle,
      );
      row++;
      if (table.subtitle != null && table.subtitle!.isNotEmpty) {
        _mergeWrite(
          sheet,
          row,
          0,
          row,
          lastColumnIndex,
          table.subtitle!,
          valueStyle.copyWith(
            fontSizeVal: 10,
            fontColorHexVal: ExcelColor.fromHexString('FF7A5B53'),
          ),
        );
        row++;
      }
      if (_isPairedSummaryTable(table)) {
        row = _writePairedSummaryExcelTable(
          sheet,
          row,
          table,
          headerStyle,
          bodyStyle,
        );
      } else {
        _writeRow(sheet, row, table.headers, headerStyle);
        row++;
        for (final tableRow in table.rows) {
          _writeRow(sheet, row, tableRow, bodyStyle);
          row++;
        }
      }
      row++;
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? const <int>[]);
  }

  static String buildCsv(ReportPdfDocument documentData) {
    final buffer = StringBuffer();

    void writeRow(List<String> values) {
      buffer.writeln(values.map(_escapeCsv).join(','));
    }

    writeRow([documentData.appName]);
    writeRow([documentData.title]);
    writeRow(['Periode', documentData.periodLabel]);
    if (documentData.rangeLabel != null &&
        documentData.rangeLabel!.isNotEmpty) {
      writeRow(['Rentang Tanggal', documentData.rangeLabel!]);
    }
    if (documentData.filterLabel != null &&
        documentData.filterLabel!.isNotEmpty) {
      writeRow(['Filter Aktif', documentData.filterLabel!]);
    }
    if (documentData.generatedAtLabel != null &&
        documentData.generatedAtLabel!.isNotEmpty) {
      writeRow(['Diekspor Pada', documentData.generatedAtLabel!]);
    }
    writeRow([documentData.primaryCaption, documentData.primaryValue]);

    if (documentData.metrics.isNotEmpty) {
      buffer.writeln();
      writeRow(['Ringkasan']);
      writeRow(['Label', 'Nilai']);
      for (final metric in documentData.metrics) {
        writeRow([metric.title, metric.value]);
      }
    }

    for (final table in documentData.tables) {
      buffer.writeln();
      writeRow([table.title]);
      if (table.subtitle != null && table.subtitle!.isNotEmpty) {
        writeRow([table.subtitle!]);
      }
      writeRow(table.headers);
      for (final row in table.rows) {
        writeRow(row);
      }
    }

    return buffer.toString();
  }

  static Future<Uint8List> buildPdf(ReportPdfDocument documentData) async {
    final document = pw.Document();
    final image = documentData.logoBytes != null
        ? pw.MemoryImage(documentData.logoBytes!)
        : null;

    document.addPage(
      pw.MultiPage(
        maxPages: 200,
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(22, 22, 22, 22),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          _buildHeader(documentData, image),
          if (documentData.metrics.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildMetricGrid(documentData.metrics),
          ],
          for (final table in documentData.tables) ...[
            pw.SizedBox(height: 12),
            _buildTableHeader(table),
            _buildTableBody(table),
          ],
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _buildHeader(ReportPdfDocument doc, pw.MemoryImage? logo) {
    final infoCards = <pw.Widget>[];

    final periodText = doc.periodLabel.trim();
    final rangeText = doc.rangeLabel?.trim() ?? '';
    final hasDistinctRange =
        rangeText.isNotEmpty && !_sameMetadataValue(rangeText, periodText);
    if (hasDistinctRange) {
      infoCards.add(_infoCard('Rentang Tanggal', doc.rangeLabel!));
    }
    if (doc.filterLabel != null && doc.filterLabel!.isNotEmpty) {
      infoCards.add(_infoCard('Filter Aktif', doc.filterLabel!));
    }
    if (doc.generatedAtLabel != null && doc.generatedAtLabel!.isNotEmpty) {
      infoCards.add(_infoCard('Diekspor Pada', doc.generatedAtLabel!));
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(AppPalette.primaryHex),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 32,
                        height: 32,
                        margin: const pw.EdgeInsets.only(right: 10),
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            doc.appName,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            doc.title,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: 190,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex(AppPalette.primaryAccentHex),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _metaLabel(
                      hasDistinctRange ? 'Periode' : 'Rentang Tanggal',
                    ),
                    pw.SizedBox(height: 4),
                    _metaValue(
                      hasDistinctRange ? doc.rangeLabel! : doc.periodLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            doc.subtitle,
            style: pw.TextStyle(
              color: PdfColor.fromHex(AppPalette.primaryBorderHex),
              fontSize: 9.5,
              lineSpacing: 1.5,
            ),
          ),
          if (infoCards.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            infoCards.length == 1
                ? pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Container(width: 190, child: infoCards.first),
                  )
                : pw.Row(
                    children: [
                      for (var i = 0; i < infoCards.length; i++) ...[
                        pw.Expanded(child: infoCards[i]),
                        if (i < infoCards.length - 1) pw.SizedBox(width: 8),
                      ],
                    ],
                  ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            doc.primaryValue,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            doc.primaryCaption,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricGrid(List<ReportPdfMetric> metrics) {
    final rows = <pw.Widget>[];
    final columnsPerRow = metrics.length == 4 ? 2 : 3;

    for (var i = 0; i < metrics.length; i += columnsPerRow) {
      final chunk = metrics.skip(i).take(columnsPerRow).toList();
      rows.add(
        pw.Row(
          children: [
            for (var j = 0; j < chunk.length; j++) ...[
              pw.Expanded(child: _metricCard(chunk[j])),
              if (j < chunk.length - 1) pw.SizedBox(width: 10),
            ],
          ],
        ),
      );
      if (i + columnsPerRow < metrics.length) {
        rows.add(pw.SizedBox(height: 8));
      }
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _metricCard(ReportPdfMetric metric) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: metric.background,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            metric.title,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: PdfColor.fromHex('#757575'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            metric.value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: metric.accent,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader(ReportPdfTable table) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#F0D9D2')),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(18),
          topRight: pw.Radius.circular(18),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            table.title,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#2B2B2B'),
            ),
          ),
          if (table.subtitle != null && table.subtitle!.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              table.subtitle!,
              style: pw.TextStyle(
                fontSize: 9.5,
                color: PdfColor.fromHex('#7A7A7A'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildTableBody(ReportPdfTable table) {
    if (_isPairedSummaryTable(table)) {
      return _buildPairedSummaryTable(table);
    }

    final isWideTable = table.headers.length >= 8;
    final tableFontSize = isWideTable ? 7.6 : 9.5;
    final headerFontSize = isWideTable ? 8.0 : 10.0;
    final horizontalPadding = isWideTable ? 5.0 : 10.0;
    final verticalPadding = isWideTable ? 7.0 : 9.0;
    final columnWidths = _columnWidthsForPdfTable(table);

    return pw.TableHelper.fromTextArray(
      headers: table.headers,
      data: table.rows,
      columnWidths: columnWidths,
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: headerFontSize,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex(AppPalette.primaryHex),
      ),
      cellStyle: pw.TextStyle(
        color: PdfColor.fromHex('#2B2B2B'),
        fontSize: tableFontSize,
      ),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromHex('#F5E4DE')),
        ),
      ),
      oddRowDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex(AppPalette.primaryPaleHex),
      ),
      headerPadding: pw.EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding + 1,
      ),
      cellPadding: pw.EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      border: pw.TableBorder(
        left: pw.BorderSide(color: PdfColor.fromHex('#F0D9D2')),
        right: pw.BorderSide(color: PdfColor.fromHex('#F0D9D2')),
        bottom: pw.BorderSide(color: PdfColor.fromHex('#F0D9D2')),
        horizontalInside: pw.BorderSide(color: PdfColor.fromHex('#F5E4DE')),
      ),
    );
  }

  static Map<int, pw.TableColumnWidth>? _columnWidthsForPdfTable(
    ReportPdfTable table,
  ) {
    if (table.headers.length == 10 &&
        table.headers[0] == 'Nota' &&
        table.headers[6] == 'Metode') {
      return <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(1.45),
        1: const pw.FlexColumnWidth(0.88),
        2: const pw.FlexColumnWidth(0.88),
        3: const pw.FlexColumnWidth(1.3),
        4: const pw.FlexColumnWidth(0.82),
        5: const pw.FlexColumnWidth(0.82),
        6: const pw.FlexColumnWidth(0.9),
        7: const pw.FlexColumnWidth(0.95),
        8: const pw.FlexColumnWidth(0.9),
        9: const pw.FlexColumnWidth(0.95),
      };
    }
    if (table.headers.length == 7 &&
        table.headers[0] == 'Tanggal' &&
        table.headers[3] == 'Jam Masuk' &&
        table.headers[6] == 'Status') {
      // Kolom pendek selalu satu baris; hanya nama karyawan yang boleh melebar.
      return <int, pw.TableColumnWidth>{
        0: const pw.IntrinsicColumnWidth(),
        1: const pw.FlexColumnWidth(),
        2: const pw.IntrinsicColumnWidth(),
        3: const pw.IntrinsicColumnWidth(),
        4: const pw.IntrinsicColumnWidth(),
        5: const pw.IntrinsicColumnWidth(),
        6: const pw.IntrinsicColumnWidth(),
      };
    }
    return null;
  }

  static bool _isPairedSummaryTable(ReportPdfTable table) {
    return table.headers.length == 4 &&
        table.headers[0] == 'Daftar' &&
        table.headers[1] == 'Total' &&
        table.headers[2] == 'Daftar' &&
        table.headers[3] == 'Total';
  }

  static pw.Widget _buildPairedSummaryTable(ReportPdfTable table) {
    final borderColor = PdfColor.fromHex('#F0D9D2');
    final innerBorderColor = PdfColor.fromHex('#F5E4DE');
    final middleBorderColor = PdfColor.fromHex('#E6B7AA');
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.55),
      1: const pw.FlexColumnWidth(1.05),
      2: const pw.FlexColumnWidth(1.55),
      3: const pw.FlexColumnWidth(1.05),
    };

    pw.Widget cell(
      String value, {
      required bool isHeader,
      required bool isValue,
      required bool middleLeft,
      bool odd = false,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(
          color: isHeader
              ? PdfColor.fromHex(AppPalette.primaryHex)
              : odd
              ? PdfColor.fromHex(AppPalette.primaryPaleHex)
              : PdfColors.white,
          border: pw.Border(
            right: middleLeft
                ? pw.BorderSide(color: middleBorderColor, width: 1.2)
                : pw.BorderSide(color: innerBorderColor),
          ),
        ),
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(
            color: isHeader ? PdfColors.white : PdfColor.fromHex('#2B2B2B'),
            fontWeight: isHeader
                ? pw.FontWeight.bold
                : isValue
                ? pw.FontWeight.normal
                : pw.FontWeight.normal,
            fontSize: isHeader ? 9 : 8.8,
          ),
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          cell(
            table.headers[0],
            isHeader: true,
            isValue: false,
            middleLeft: false,
          ),
          cell(
            table.headers[1],
            isHeader: true,
            isValue: true,
            middleLeft: true,
          ),
          cell(
            table.headers[2],
            isHeader: true,
            isValue: false,
            middleLeft: false,
          ),
          cell(
            table.headers[3],
            isHeader: true,
            isValue: true,
            middleLeft: false,
          ),
        ],
      ),
      for (var i = 0; i < table.rows.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: innerBorderColor)),
          ),
          children: [
            cell(
              table.rows[i][0],
              isHeader: false,
              isValue: false,
              middleLeft: false,
              odd: i.isOdd,
            ),
            cell(
              table.rows[i][1],
              isHeader: false,
              isValue: true,
              middleLeft: true,
              odd: i.isOdd,
            ),
            cell(
              table.rows[i][2],
              isHeader: false,
              isValue: false,
              middleLeft: false,
              odd: i.isOdd,
            ),
            cell(
              table.rows[i][3],
              isHeader: false,
              isValue: true,
              middleLeft: false,
              odd: i.isOdd,
            ),
          ],
        ),
    ];

    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder(
        left: pw.BorderSide(color: borderColor),
        right: pw.BorderSide(color: borderColor),
        bottom: pw.BorderSide(color: borderColor),
        horizontalInside: pw.BorderSide(color: innerBorderColor),
      ),
      children: rows,
    );
  }

  static pw.Widget _infoCard(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(AppPalette.primaryAccentHex),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _metaLabel(title),
          pw.SizedBox(height: 4),
          _metaValue(value),
        ],
      ),
    );
  }

  static pw.Widget _metaLabel(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 8.5,
      color: PdfColor.fromHex(AppPalette.primaryBorderHex),
    ),
  );

  static pw.Widget _metaValue(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 10.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
  );

  static bool _sameMetadataValue(String a, String b) {
    return _normalizeMetadataValue(a) == _normalizeMetadataValue(b);
  }

  static String _normalizeMetadataValue(String value) {
    return value
        .toLowerCase()
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'\s+s/d\s+'), ' - ')
        .replaceAll(RegExp(r'\b0+(\d)\s+'), r'$1 ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String formatRupiah(num amount) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);

  static String formatGeneratedAt([DateTime? value]) {
    final date = value ?? DateTime.now();
    try {
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('dd MMM yyyy HH:mm').format(date);
    }
  }

  static String formatDateRange(dynamic start, dynamic end) {
    return '${formatTableDate(start)} s/d ${formatTableDate(end)}';
  }

  static String formatFileDate(dynamic raw) {
    if (raw == null) return 'unknown-date';
    if (raw is DateTime) {
      return DateFormat('yyyy-MM-dd').format(raw);
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return 'unknown-date';

    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed != null) {
      return DateFormat('yyyy-MM-dd').format(parsed);
    }

    final dateOnly = text.contains('T')
        ? text.split('T').first
        : text.contains(' ')
        ? text.split(' ').first
        : text;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateOnly)) {
      return dateOnly;
    }

    return text
        .replaceAll(RegExp(r'[^0-9A-Za-z._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static String _sanitizeSheetName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
    if (cleaned.isEmpty) return 'Laporan';
    return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  }

  static double _columnWidthFor(
    int index,
    List<ReportPdfTable> tables,
    int totalColumns,
  ) {
    final hasWideTransactionTable = tables.any(
      (table) =>
          table.headers.length >= 8 ||
          (table.headers.isNotEmpty && table.headers.first == 'Nota'),
    );
    if (hasWideTransactionTable) {
      switch (index) {
        case 0:
          return 22;
        case 1:
        case 2:
          return 12;
        case 3:
          return 18;
        case 4:
        case 5:
          return 13;
        case 6:
          return 14;
        default:
          return 15;
      }
    }

    if (totalColumns <= 6) {
      switch (index) {
        case 0:
          return 24;
        case 1:
          return 20;
        case 2:
          return 22;
        case 3:
          return 20;
        case 4:
          return 18;
        default:
          return 18;
      }
    }

    switch (index) {
      case 0:
        return 22;
      case 1:
        return 22;
      case 2:
        return 18;
      case 3:
        return 20;
      case 4:
        return 18;
      default:
        return 16;
    }
  }

  static Border _thinBorder(String colorHex) {
    return Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString(colorHex),
    );
  }

  static ExcelColor _excelColorFromPdf(PdfColor color) {
    int toChannel(double value) => (value.clamp(0, 1) * 255).round();
    final red = toChannel(color.red).toRadixString(16).padLeft(2, '0');
    final green = toChannel(color.green).toRadixString(16).padLeft(2, '0');
    final blue = toChannel(color.blue).toRadixString(16).padLeft(2, '0');
    return ExcelColor.fromHexString('FF$red$green$blue');
  }

  static void _writeRow(
    Sheet sheet,
    int row,
    List<String> values,
    CellStyle style,
  ) {
    for (var col = 0; col < values.length; col++) {
      _writeCell(sheet, row, col, values[col], style);
    }
  }

  static int _writeMetricGridRow(
    Sheet sheet,
    int startRow,
    List<ReportPdfMetric> metrics,
    int totalColumns,
    CellStyle headerStyle,
    CellStyle bodyStyle,
  ) {
    final columnsPerMetric = totalColumns ~/ 3;
    final remainder = totalColumns % 3;
    var currentColumn = 0;

    for (var i = 0; i < 3; i++) {
      final span = columnsPerMetric + (i < remainder ? 1 : 0);
      final endColumn = currentColumn + span - 1;
      if (i < metrics.length) {
        final metric = metrics[i];
        _mergeWrite(
          sheet,
          startRow,
          currentColumn,
          startRow,
          endColumn,
          metric.title,
          headerStyle.copyWith(
            fontColorHexVal: ExcelColor.fromHexString('FF7A5B53'),
            backgroundColorHexVal: ExcelColor.fromHexString('FFFDF5F2'),
            horizontalAlignVal: HorizontalAlign.Left,
          ),
        );
        _mergeWrite(
          sheet,
          startRow + 1,
          currentColumn,
          startRow + 1,
          endColumn,
          metric.value,
          bodyStyle.copyWith(
            boldVal: true,
            fontSizeVal: 12,
            fontColorHexVal: _excelColorFromPdf(metric.accent),
            backgroundColorHexVal: _excelColorFromPdf(metric.background),
          ),
        );
      } else {
        _mergeWrite(
          sheet,
          startRow,
          currentColumn,
          startRow + 1,
          endColumn,
          '',
          bodyStyle,
        );
      }
      currentColumn = endColumn + 1;
    }

    sheet.setRowHeight(startRow, 22);
    sheet.setRowHeight(startRow + 1, 28);
    return startRow + 2;
  }

  static int _writePairedSummaryExcelTable(
    Sheet sheet,
    int startRow,
    ReportPdfTable table,
    CellStyle headerStyle,
    CellStyle bodyStyle,
  ) {
    final middleBorder = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('FFE6B7AA'),
    );
    final leftHeaderStyle = headerStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Left,
    );
    final valueHeaderStyle = headerStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Left,
    );
    final labelBodyStyle = bodyStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Left,
    );
    final valueBodyStyle = bodyStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Left,
    );

    void writeSummaryRow(
      int row,
      List<String> values,
      bool isHeader,
      bool odd,
    ) {
      final styles = isHeader
          ? [
              leftHeaderStyle,
              valueHeaderStyle.copyWith(rightBorderVal: middleBorder),
              leftHeaderStyle,
              valueHeaderStyle,
            ]
          : [
              labelBodyStyle.copyWith(
                backgroundColorHexVal: odd
                    ? ExcelColor.fromHexString('FFFFF8F5')
                    : null,
              ),
              valueBodyStyle.copyWith(
                rightBorderVal: middleBorder,
                backgroundColorHexVal: odd
                    ? ExcelColor.fromHexString('FFFFF8F5')
                    : null,
              ),
              labelBodyStyle.copyWith(
                backgroundColorHexVal: odd
                    ? ExcelColor.fromHexString('FFFFF8F5')
                    : null,
              ),
              valueBodyStyle.copyWith(
                backgroundColorHexVal: odd
                    ? ExcelColor.fromHexString('FFFFF8F5')
                    : null,
              ),
            ];

      for (var col = 0; col < 4; col++) {
        _writeCell(sheet, row, col, values[col], styles[col]);
      }
    }

    writeSummaryRow(startRow, table.headers, true, false);
    var row = startRow + 1;
    for (var i = 0; i < table.rows.length; i++) {
      writeSummaryRow(row, table.rows[i], false, i.isOdd);
      row++;
    }
    return row;
  }

  static void _writeCell(
    Sheet sheet,
    int row,
    int column,
    String value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  static void _mergeWrite(
    Sheet sheet,
    int startRow,
    int startColumn,
    int endRow,
    int endColumn,
    String value,
    CellStyle style,
  ) {
    final start = CellIndex.indexByColumnRow(
      columnIndex: startColumn,
      rowIndex: startRow,
    );
    final end = CellIndex.indexByColumnRow(
      columnIndex: endColumn,
      rowIndex: endRow,
    );
    sheet.merge(start, end);
    final cell = sheet.cell(start);
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
    if (startRow != endRow || startColumn != endColumn) {
      sheet.setMergedCellStyle(start, style);
    }
  }

  static String _escapeCsv(String value) => '"${value.replaceAll('"', '""')}"';
}
