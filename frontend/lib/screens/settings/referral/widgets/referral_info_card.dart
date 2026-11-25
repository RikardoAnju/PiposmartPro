import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

/// Groups the referral code field with the two info accordions
/// ("Cara Dapat Bonus Referral" and "Ketentuan Reward") into a single
/// continuous white card, matching the redesign.
class ReferralInfoCard extends StatefulWidget {
  final String code;
  final List<String> howItWorksItems;
  final List<String> benefitItems;

  const ReferralInfoCard({
    super.key,
    required this.code,
    required this.howItWorksItems,
    required this.benefitItems,
  });

  @override
  State<ReferralInfoCard> createState() => _ReferralInfoCardState();
}

class _ReferralInfoCardState extends State<ReferralInfoCard> {
  bool _howExpanded = false;
  bool _benefitExpanded = false;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REFERRAL CODE',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFAAAAAA),
                    letterSpacing: 0.5,
                    fontWeight: AppFont.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.code,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: AppFont.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.code),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kode referral berhasil disalin'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppPalette.primary,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(11),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 20,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _ExpandRow(
            icon: Icons.emoji_events_rounded,
            title: 'Cara Dapat Bonus Referral',
            items: widget.howItWorksItems,
            isExpanded: _howExpanded,
            onTap: () => setState(() => _howExpanded = !_howExpanded),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _ExpandRow(
            icon: Icons.card_giftcard_rounded,
            title: 'Ketentuan Reward',
            items: widget.benefitItems,
            isExpanded: _benefitExpanded,
            onTap: () => setState(() => _benefitExpanded = !_benefitExpanded),
          ),
        ],
      ),
    );
  }
}

class _ExpandRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExpandRow({
    required this.icon,
    required this.title,
    required this.items,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: AppPalette.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.w700,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final isFirst = entry.key == 0;
                return Column(
                  children: [
                    if (!isFirst)
                      const Divider(height: 1, color: Color(0xFFF5F5F5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: AppPalette.primary,
                              fontWeight: AppFont.w700,
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF555555),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
