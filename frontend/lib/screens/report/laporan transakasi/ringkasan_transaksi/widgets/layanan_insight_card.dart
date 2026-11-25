import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';

class LayananInsightCard extends StatelessWidget {
  final String insightText;

  const LayananInsightCard({super.key, required this.insightText});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF5DED5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F6E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_rounded, color: Color(0xFF2DBE7F), size: 19),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insight Strategis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.w900,
                        color: Color(0xFF1E1715),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sorotan cepat dari performa layanan periode ini.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w600,
                        color: Color(0xFF8E817B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            insightText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: AppFont.w600,
              color: Color(0xFF4E403B),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
