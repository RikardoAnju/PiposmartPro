import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/currency_formatter.dart';

class SummaryCard extends StatefulWidget {
  const SummaryCard({super.key});

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  bool _hidden = true;
  static const _hiddenPreferenceKey = 'home_summary_nominal_hidden';

  @override
  void initState() {
    super.initState();
    _loadHiddenPreference();
  }

  Future<void> _loadHiddenPreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hidden = preferences.getBool(_hiddenPreferenceKey) ?? true;
    });
  }

  Future<void> _toggleHidden() async {
    final nextValue = !_hidden;
    setState(() => _hidden = nextValue);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hiddenPreferenceKey, nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final summary = prov.summaryData;
    final canReadHomeSummary = auth.canReadHomeSummary;

    final sales = summary?['penjualan'] ?? 0;
    final expenses = summary?['pengeluaran'] ?? 0;
    final income = summary?['pendapatan_hari_ini'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppPalette.primaryDeep, AppPalette.primary],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .22), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x3D7A2E00), blurRadius: 26, offset: Offset(0, 14)),
            BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Pendapatan Hari Ini',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 15,
                    fontWeight: AppFont.w600,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: _toggleHidden,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: .85),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _heroCurrencyText(income, canReadHomeSummary),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _buildAmountCard('Penjualan', sales, true, canReadHomeSummary)),
                const SizedBox(width: 12),
                Expanded(child: _buildAmountCard('Pengeluaran', expenses, false, canReadHomeSummary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(String label, dynamic value, bool positive, bool canRead) {
    final color = positive ? const Color(0xFF2F9E58) : const Color(0xFFDB5A5A);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .5), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F7A2E00),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 13,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _currencyText(value, canRead, color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyText(dynamic value, bool canRead, Color textColor) {
    if (!canRead) {
      return Text('Rp ...', style: TextStyle(color: textColor, fontSize: 17, fontWeight: AppFont.w600));
    }
    if (_hidden) {
      return SizedBox(
        width: 145,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Rp', style: TextStyle(color: textColor, fontSize: 17, fontWeight: AppFont.w700)),
              const WidgetSpan(child: SizedBox(width: 8)),
              TextSpan(text: '••••', style: TextStyle(color: textColor, fontSize: 17, fontWeight: AppFont.w600)),
            ],
          ),
        ),
      );
    }
    final formatted = CurrencyFormatter.formatToRupiah(value);
    final amount = formatted.replaceFirst('Rp', '').trim();
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: 'Rp', style: TextStyle(color: textColor, fontSize: 14, fontWeight: AppFont.w700)),
          const WidgetSpan(child: SizedBox(width: 6)),
          TextSpan(text: amount, style: TextStyle(color: textColor, fontSize: 16, fontWeight: AppFont.w700)),
        ],
      ),
    );
  }

  Widget _heroCurrencyText(dynamic value, bool canRead) {
    if (!canRead) {
      return const SizedBox(
        height: 44,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Rp', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: AppFont.w800)),
              WidgetSpan(child: SizedBox(width: 10)),
              TextSpan(text: '...', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: AppFont.w800)),
            ],
          ),
        ),
      );
    }
    if (_hidden) {
      return const SizedBox(
        height: 44,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Rp', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: AppFont.w800)),
              WidgetSpan(child: SizedBox(width: 10)),
              TextSpan(text: '••••', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: AppFont.w800)),
            ],
          ),
        ),
      );
    }
    final amount = CurrencyFormatter.formatToRupiah(value).replaceFirst('Rp', '').trim();
    return RichText(
      text: TextSpan(
        children: [
          const TextSpan(text: 'Rp', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: AppFont.w800)),
          const WidgetSpan(child: SizedBox(width: 10)),
          TextSpan(text: amount, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: AppFont.w900)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: AppFont.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value.isEmpty ? '0' : value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: AppFont.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
