import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/constants/api_endpoints.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'dart:convert';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PengeluaranKategoriTile extends StatefulWidget {
  final String token;
  final String startDate;
  final String endDate;
  final String kategoriId;
  final String kategori;
  final double total;
  final bool showDivider;

  const PengeluaranKategoriTile({
    super.key,
    required this.token,
    required this.startDate,
    required this.endDate,
    required this.kategoriId,
    required this.kategori,
    required this.total,
    this.showDivider = true,
  });

  @override
  State<PengeluaranKategoriTile> createState() =>
      _PengeluaranKategoriTileState();
}

class _PengeluaranKategoriTileState extends State<PengeluaranKategoriTile> {
  bool _isExpanded = false;
  bool _isLoading = false;
  List<dynamic> _details = [];
  bool _hasFetched = false;

  final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> _fetchDetails() async {
    if (_hasFetched || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(ApiEndpoints.reportProfitLossDetailExpense)
          .replace(
            queryParameters: {
              'start_date': widget.startDate,
              'end_date': widget.endDate,
              'kategori_id': widget.kategoriId,
            },
          )
          .toString();

      final response = await ApiClient.get(url, token: widget.token);
      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['data'] != null) {
        final data = body['data'];
        final details = _extractExpenseDetails(data);
        setState(() {
          _details = details;
          _hasFetched = true;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _extractExpenseDetails(dynamic data) {
    if (data is! Map) return const [];

    final rawDetails = data['detail_pengeluaran'];
    if (rawDetails is List) return rawDetails;

    if (rawDetails is Map) {
      final nestedData = rawDetails['data'];
      if (nestedData is List) return nestedData;
    }

    return const [];
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded && !_hasFetched) {
      _fetchDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: _toggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppPalette.danger,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.kategori,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  '- ${_formatter.format(widget.total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w900,
                    color: AppPalette.danger,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _isExpanded ? AppPalette.danger : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _isExpanded
              ? _buildDetailsList()
              : const SizedBox(width: double.infinity),
        ),
        if (widget.showDivider && !_isExpanded)
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.04)),
      ],
    );
  }

  Widget _buildDetailsList() {
    if (_isLoading) {
      return const ReportInlineDetailSkeleton();
    }

    if (_details.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Tidak ada detail pengeluaran',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black38,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFF5F5F5)),
        ..._details.map((item) {
          final nama = item['keterangan'] ?? item['nama'] ?? '-';
          final jumlah = (item['total'] ?? item['jumlah'] ?? 0).toDouble();

          return Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nama.toString().isNotEmpty ? nama.toString() : '-',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatter.format(jumlah),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}
