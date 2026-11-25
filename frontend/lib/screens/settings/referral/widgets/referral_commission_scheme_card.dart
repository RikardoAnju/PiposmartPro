import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralCommissionSchemeCard extends StatefulWidget {
  final int firstTopupPercent;
  final int pricePerCoin;

  const ReferralCommissionSchemeCard({
    super.key,
    required this.firstTopupPercent,
    required this.pricePerCoin,
  });

  @override
  State<ReferralCommissionSchemeCard> createState() =>
      _ReferralCommissionSchemeCardState();
}

class _ReferralCommissionSchemeCardState
    extends State<ReferralCommissionSchemeCard> {
  bool _isExpanded = false;

  static const _nominalPresets = [1000000, 500000, 250000, 100000];
  static const _userPresets = [25, 15, 10, 5];
  static const _topupPerUser = 100000;

  final _rupiahFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _decimalFmt = NumberFormat.decimalPattern('id');

  String _rupiah(num v) => _rupiahFmt.format(v);

  // Angka polos tanpa "Rp"/"Koin" — dipakai di sel tabel agar rapi
  // (satuan sudah tertera di header kolom).
  String _num(num v) => _decimalFmt.format(v);

  int _koinFor(num rupiah) {
    if (widget.pricePerCoin <= 0) return 0;
    return (rupiah / widget.pricePerCoin).floor();
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.firstTopupPercent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: AppPalette.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Skema Komisi Top Up',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF999999),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Komisi Nominal Top up'),
                  const SizedBox(height: 8),
                  _CommissionTable(
                    columns: const [
                      _Col('NOMINAL', flex: 28, align: Alignment.centerLeft),
                      _Col('PERSEN', flex: 20, align: Alignment.center),
                      _Col('KOMISI', flex: 26, align: Alignment.centerRight),
                      _Col('KOIN', flex: 26, align: Alignment.centerRight),
                    ],
                    rows: _nominalPresets.map((nominal) {
                      final komisi = (nominal * percent / 100).round();
                      return [
                        _Cell(_num(nominal)),
                        _Cell('$percent%', pill: true),
                        _Cell(_num(komisi)),
                        _Cell(_num(_koinFor(komisi))),
                      ];
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Estimasi Penghasilan Referral'),
                  const SizedBox(height: 4),
                  Text(
                    'Estimasi berdasarkan asumsi setiap user top up ${_rupiah(_topupPerUser)} dengan komisi $percent%. Penghasilan aktual bisa berbeda.',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF888888),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CommissionTable(
                    columns: const [
                      _Col('TOTAL USER', flex: 24, align: Alignment.centerLeft),
                      _Col('TOTAL TOP UP', flex: 28, align: Alignment.centerLeft),
                      _Col('KOMISI', flex: 24, align: Alignment.centerLeft),
                      _Col('KOIN', flex: 24, align: Alignment.centerLeft),
                    ],
                    rows: _userPresets.map((users) {
                      final totalTopup = users * _topupPerUser;
                      final komisi = (totalTopup * percent / 100).round();
                      return [
                        _Cell('$users User'),
                        _Cell(_num(totalTopup)),
                        _Cell(_num(komisi)),
                        _Cell(_num(_koinFor(komisi))),
                      ];
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppPalette.warning,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Semakin banyak referral aktif, semakin besar reward yang bisa kamu nikmati.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppPalette.ink,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: AppFont.w700,
      color: Color(0xFF333333),
    ),
  );
}

class _Col {
  final String label;
  final int flex;
  final Alignment align;
  const _Col(this.label, {required this.flex, required this.align});
}

class _Cell {
  final String text;
  final bool pill;
  const _Cell(this.text, {this.pill = false});
}

class _CommissionTable extends StatelessWidget {
  final List<_Col> columns;
  final List<List<_Cell>> rows;

  const _CommissionTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          // ── Header row: gradient orange ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppPalette.primary, AppPalette.primaryDeep],
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                for (final c in columns)
                  Expanded(
                    flex: c.flex,
                    child: Align(
                      alignment: c.align,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Data rows: alternating warning tint ──
          for (int r = 0; r < rows.length; r++)
            Container(
              color: r.isEven
                  ? AppPalette.warning.withValues(alpha: 0.10)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  for (int i = 0; i < columns.length; i++)
                    Expanded(
                      flex: columns[i].flex,
                      child: Align(
                        alignment: columns[i].align,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: rows[r][i].pill
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    rows[r][i].text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: AppFont.w700,
                                    ),
                                  ),
                                )
                              : Text(
                                  rows[r][i].text,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: AppFont.w600,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
