import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'report_export_builder.dart';
import '../../shared/widgets/custom_toast.dart';

class ReportExportService {
  static Future<Uint8List?> loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/icons/logo/logo_final.webp');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<void> exportPdf({
    required BuildContext context,
    required ReportPdfDocument document,
    required String fileName,
    required String shareTitle,
  }) async {
    final bytes = await ReportExportBuilder.buildPdf(document);
    final directory = await _resolveExportDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final shareResult = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: shareTitle,
        subject: shareTitle,
      ),
    );

    if (shareResult.status == ShareResultStatus.success) {
      CustomToast.show(
        context,
        message: 'PDF berhasil dibuat dan dibagikan',
      );
    }
  }

  static Future<void> exportCsv({
    required BuildContext context,
    required ReportPdfDocument document,
    required String fileName,
    required String shareTitle,
  }) async {
    final csv = ReportExportBuilder.buildCsv(document);
    final directory = await _resolveExportDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv, flush: true);

    final shareResult = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        text: shareTitle,
        subject: shareTitle,
      ),
    );

    if (shareResult.status == ShareResultStatus.success) {
      CustomToast.show(
        context,
        message: 'CSV berhasil dibuat dan dibagikan',
      );
    }
  }

  static Future<void> exportExcel({
    required BuildContext context,
    required ReportPdfDocument document,
    required String fileName,
    required String shareTitle,
  }) async {
    final bytes = ReportExportBuilder.buildExcel(document);
    final directory = await _resolveExportDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final shareResult = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: shareTitle,
        subject: shareTitle,
      ),
    );

    if (shareResult.status == ShareResultStatus.success) {
      CustomToast.show(
        context,
        message: 'Excel berhasil dibuat dan dibagikan',
      );
    }
  }

  static Future<Directory> _resolveExportDirectory() async {
    final candidates = <Directory>[];

    final appDir = await getApplicationDocumentsDirectory();
    candidates.add(Directory('${appDir.path}/exports'));

    final tempDir = await getTemporaryDirectory();
    candidates.add(Directory('${tempDir.path}/exports'));

    for (final candidate in candidates) {
      try {
        await candidate.create(recursive: true);
        final probe = File('${candidate.path}/.write_test');
        await probe.writeAsString('ok');
        if (await probe.exists()) {
          await probe.delete();
        }
        return candidate;
      } catch (_) {
        continue;
      }
    }

    return await Directory.systemTemp.createTemp('ayocuci_exports_');
  }
}
