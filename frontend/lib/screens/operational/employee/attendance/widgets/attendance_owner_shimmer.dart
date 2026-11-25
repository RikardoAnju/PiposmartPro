import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

/// Shimmer loader for Kelola Absen (AttendanceDashboardScreen)
class AttendanceDashboardShimmer extends StatelessWidget {
  const AttendanceDashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SafeArea(
        top: false,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            // Dashboard Header Skeleton
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDEFF3)),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 42, height: 42, radius: 12),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 140, height: 16, radius: 4),
                      SizedBox(height: 6),
                      AppSkeletonBox(width: 190, height: 11, radius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dashboard Stats Skeleton Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEDEFF3)),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppSkeletonBox(width: 60, height: 40, radius: 10),
                      AppSkeletonBox(width: 60, height: 40, radius: 10),
                      AppSkeletonBox(width: 60, height: 40, radius: 10),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AppSkeletonBox(width: 80, height: 36, radius: 10),
                      AppSkeletonBox(width: 80, height: 36, radius: 10),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Leave Approval Tile Skeleton
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEDEFF3)),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 32, height: 32, radius: 8),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppSkeletonBox(width: 120, height: 14, radius: 4),
                  ),
                  AppSkeletonBox(width: 24, height: 24, radius: 12),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Roster List Header Skeleton
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeletonBox(width: 140, height: 16, radius: 4),
                AppSkeletonBox(width: 30, height: 14, radius: 4),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar Skeleton
            const AppSkeletonBox(
              width: double.infinity,
              height: 44,
              radius: 12,
            ),
            const SizedBox(height: 12),

            // Roster Item Cards Skeletons
            ...List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDEFF3)),
                  ),
                  child: const Row(
                    children: [
                      AppSkeletonBox(width: 44, height: 44, radius: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeletonBox(width: 120, height: 14, radius: 4),
                            SizedBox(height: 6),
                            AppSkeletonBox(width: 80, height: 11, radius: 4),
                          ],
                        ),
                      ),
                      AppSkeletonBox(width: 64, height: 24, radius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loader for Leave Approval Screen
class LeaveApprovalShimmer extends StatelessWidget {
  const LeaveApprovalShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SafeArea(
        top: false,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDEFF3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppSkeletonBox(width: 130, height: 14, radius: 4),
                    AppSkeletonBox(width: 70, height: 20, radius: 10),
                  ],
                ),
                SizedBox(height: 10),
                AppSkeletonBox(width: 180, height: 12, radius: 4),
                SizedBox(height: 6),
                AppSkeletonBox(width: 220, height: 12, radius: 4),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppSkeletonBox(
                        width: double.infinity,
                        height: 38,
                        radius: 10,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: AppSkeletonBox(
                        width: double.infinity,
                        height: 38,
                        radius: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer loader for Employee Attendance Detail Screen
class EmployeeAttendanceDetailShimmer extends StatelessWidget {
  const EmployeeAttendanceDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SafeArea(
        top: false,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            // Employee Header Skeleton
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDEFF3)),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 48, height: 48, radius: 24),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 130, height: 16, radius: 4),
                      SizedBox(height: 6),
                      AppSkeletonBox(width: 90, height: 12, radius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Summary Card Skeleton
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDEFF3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  AppSkeletonBox(width: 60, height: 36, radius: 8),
                  AppSkeletonBox(width: 60, height: 36, radius: 8),
                  AppSkeletonBox(width: 60, height: 36, radius: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Week Selector Skeleton
            const AppSkeletonBox(
              width: double.infinity,
              height: 48,
              radius: 12,
            ),
            const SizedBox(height: 16),

            // Day Rows Skeletons
            ...List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEDEFF3)),
                  ),
                  child: const Row(
                    children: [
                      AppSkeletonBox(width: 40, height: 40, radius: 10),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeletonBox(width: 100, height: 14, radius: 4),
                            SizedBox(height: 5),
                            AppSkeletonBox(width: 140, height: 11, radius: 4),
                          ],
                        ),
                      ),
                      AppSkeletonBox(width: 60, height: 22, radius: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
