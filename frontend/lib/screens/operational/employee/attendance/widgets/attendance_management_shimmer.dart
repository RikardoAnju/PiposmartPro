import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

class AttendanceManagementShimmer extends StatelessWidget {
  const AttendanceManagementShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Schedule Hero Skeleton
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFEDEFF3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 140, height: 22, radius: 6),
                        SizedBox(height: 8),
                        AppSkeletonBox(width: 220, height: 13, radius: 4),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            AppSkeletonBox(width: 36, height: 36, radius: 10),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSkeletonBox(width: 90, height: 11, radius: 4),
                                SizedBox(height: 5),
                                AppSkeletonBox(width: 120, height: 14, radius: 4),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const AppSkeletonBox(width: 120, height: 16, radius: 4),
                  const SizedBox(height: 12),
                  // Shift Card Skeletons
                  ...List.generate(
                    2,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEDEFF3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AppSkeletonBox(
                                  width: 44,
                                  height: 44,
                                  radius: 14,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppSkeletonBox(
                                        width: 100,
                                        height: 14,
                                        radius: 4,
                                      ),
                                      SizedBox(height: 6),
                                      AppSkeletonBox(
                                        width: 80,
                                        height: 11,
                                        radius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const AppSkeletonBox(
                                  width: 68,
                                  height: 24,
                                  radius: 20,
                                ),
                                const SizedBox(width: 8),
                                const AppSkeletonBox(
                                  width: 20,
                                  height: 20,
                                  radius: 4,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                AppSkeletonBox(
                                  width: 130,
                                  height: 22,
                                  radius: 8,
                                ),
                                SizedBox(width: 8),
                                AppSkeletonBox(
                                  width: 70,
                                  height: 22,
                                  radius: 8,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Holiday Tile Skeleton
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEDEFF3)),
                    ),
                    child: const Row(
                      children: [
                        AppSkeletonBox(width: 32, height: 32, radius: 8),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSkeletonBox(width: 110, height: 13, radius: 4),
                              SizedBox(height: 5),
                              AppSkeletonBox(width: 160, height: 10, radius: 4),
                            ],
                          ),
                        ),
                        AppSkeletonBox(width: 18, height: 18, radius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Action Button Skeleton
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppSkeletonBox(
                width: double.infinity,
                height: 48,
                radius: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
