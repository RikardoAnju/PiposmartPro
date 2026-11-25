import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReportDownloadSheet extends StatelessWidget {
  final bool isExporting;
  final String description;
  final VoidCallback onExportPdf;
  final VoidCallback? onExportExcel;
  final Widget? filter;

  const ReportDownloadSheet({
    super.key,
    required this.isExporting,
    required this.description,
    required this.onExportPdf,
    this.onExportExcel,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Download Laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: AppFont.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (filter != null) ...[
              const SizedBox(height: 10),
              Material(
                color: Colors.transparent,
                child: filter!,
              ),
            ],
            const SizedBox(height: 18),
            InkWell(
              onTap: isExporting ? null : onExportPdf,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  color: const Color(0xFFFDFDFD),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: AppPalette.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF (.pdf)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFont.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Template branded AyoCuci dengan ringkasan dan tabel detail.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: AppFont.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black.withValues(alpha: 0.26),
                    ),
                  ],
                ),
              ),
            ),
            if (onExportExcel != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: isExporting ? null : onExportExcel,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                    color: const Color(0xFFFDFDFD),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.grid_on_rounded,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Excel (.xlsx)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFont.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Spreadsheet rapi dengan layout, header, dan tabel yang siap dibuka di Excel atau Google Sheets.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                fontWeight: AppFont.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black.withValues(alpha: 0.26),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
