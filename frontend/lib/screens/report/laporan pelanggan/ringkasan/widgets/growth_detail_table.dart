import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class GrowthTableRow {
  final String tanggal;
  final int perempuan;
  final int lakiLaki;
  final int total;

  const GrowthTableRow({
    required this.tanggal,
    required this.perempuan,
    required this.lakiLaki,
    required this.total,
  });
}

class GrowthDetailTable extends StatelessWidget {
  final List<GrowthTableRow> rows;

  const GrowthDetailTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E5DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Pelanggan Baru',
            style: TextStyle(
              fontSize: 17,
              fontWeight: AppFont.w800,
              color: Color(0xFF2B1E1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rincian pelanggan baru berdasarkan tanggal dan gender.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF8D807A),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF0E3DD)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _TableHeader(),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Belum ada data',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final isEven = index.isEven;
                      return Container(
                        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                row.tanggal,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                row.perempuan.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE91E8C),
                                  fontWeight: AppFont.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                row.lakiLaki.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E88E5),
                                  fontWeight: AppFont.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                row.total.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF333333),
                                  fontWeight: AppFont.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (rows.isNotEmpty) ...[
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFAF7),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 4,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w800,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            rows
                                .fold(0, (sum, r) => sum + r.perempuan)
                                .toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w800,
                              color: Color(0xFFE91E8C),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            rows
                                .fold(0, (sum, r) => sum + r.lakiLaki)
                                .toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w800,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            rows.fold(0, (sum, r) => sum + r.total).toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w800,
                              color: AppPalette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Tanggal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFont.w700,
                color: Color(0xFF7F736E),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Perempuan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFont.w700,
                color: Color(0xFF7F736E),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Laki-laki',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFont.w700,
                color: Color(0xFF7F736E),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Total',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFont.w700,
                color: Color(0xFF7F736E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
