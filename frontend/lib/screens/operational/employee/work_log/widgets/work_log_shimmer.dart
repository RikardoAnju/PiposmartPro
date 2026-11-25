import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

class WorkLogEmployeePickerShimmer extends StatelessWidget {
  const WorkLogEmployeePickerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          // Header Hero Card Skeleton
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: const Row(
              children: [
                AppSkeletonBox(width: 46, height: 46, radius: 14),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 120, height: 16, radius: 4),
                      SizedBox(height: 6),
                      AppSkeletonBox(width: 220, height: 12, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const AppSkeletonBox(width: 110, height: 12, radius: 4),
          const SizedBox(height: 12),
          // Employee List Skeletons
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEDEFF3)),
                ),
                child: const Row(
                  children: [
                    AppSkeletonBox(width: 42, height: 42, radius: 21),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonBox(width: 130, height: 13, radius: 4),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              AppSkeletonBox(width: 65, height: 16, radius: 6),
                              SizedBox(width: 6),
                              AppSkeletonBox(width: 80, height: 16, radius: 6),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AppSkeletonBox(width: 18, height: 18, radius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkLogEmployeeViewShimmer extends StatelessWidget {
  const WorkLogEmployeeViewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // Employee Header Skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: const Row(
              children: [
                AppSkeletonBox(width: 48, height: 48, radius: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 140, height: 15, radius: 4),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          AppSkeletonBox(width: 70, height: 16, radius: 6),
                          SizedBox(width: 6),
                          AppSkeletonBox(width: 80, height: 16, radius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Ringkasan Kerja Skeleton
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonBox(width: 110, height: 12, radius: 4),
                          SizedBox(height: 4),
                          AppSkeletonBox(width: 140, height: 10, radius: 4),
                        ],
                      ),
                    ),
                    AppSkeletonBox(width: 100, height: 26, radius: 10),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppSkeletonBox(height: 75, radius: 14),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: AppSkeletonBox(height: 75, radius: 14),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: AppSkeletonBox(height: 75, radius: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppSkeletonBox(width: 120, height: 12, radius: 4),
          const SizedBox(height: 10),
          // Stage Cards Skeleton
          ...List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: AppSkeletonBox(height: 64, radius: 16),
            ),
          ),
          const SizedBox(height: 16),
          const AppSkeletonBox(width: 130, height: 12, radius: 4),
          const SizedBox(height: 10),
          // Activity Cards Skeleton
          ...List.generate(
            2,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: AppSkeletonBox(height: 80, radius: 16),
            ),
          ),
        ],
      ),
    );
  }
}
