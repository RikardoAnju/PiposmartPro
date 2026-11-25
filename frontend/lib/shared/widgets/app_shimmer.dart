   import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? const Color(0xFFE7E7E7),
      highlightColor: highlightColor ?? const Color(0xFFF7F7F7),
      period: const Duration(milliseconds: 1100),
      child: child,
    );
  }
}

class AppSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AppCircularLoader extends StatelessWidget {
  final Color? color;
  final double strokeWidth;
  final Animation<Color?>? valueColor;

  const AppCircularLoader({
    super.key,
    this.color,
    this.strokeWidth = 4.0,
    this.valueColor,
  });

  Color get _baseColor => color ?? valueColor?.value ?? const Color(0xFFE7E7E7);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;
        final shortest = math
            .min(width > 0 ? width : 24, height > 0 ? height : 24)
            .toDouble();

        return AppShimmer(
          baseColor: _baseColor.withValues(alpha: 0.22),
          child: shortest <= 40
              ? Container(
                  width: shortest,
                  height: shortest,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSkeletonBox(width: 180, height: 14, radius: 99),
                    const SizedBox(height: 10),
                    const AppSkeletonBox(width: 120, height: 14, radius: 99),
                    const SizedBox(height: 14),
                    AppSkeletonBox(
                      width: math.min(width, 220),
                      height: math.max(30, strokeWidth * 7),
                      radius: 16,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class CustomerListSkeleton extends StatelessWidget {
  final int itemCount;

  const CustomerListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
        itemCount: itemCount,
        itemBuilder: (_, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: Colors.white),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 72, height: 10, radius: 99),
                    SizedBox(height: 8),
                    AppSkeletonBox(height: 16, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(width: 140, height: 12, radius: 99),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const AppSkeletonBox(width: 18, height: 18, radius: 99),
            ],
          ),
        ),
      ),
    );
  }
}

class OutletListSkeleton extends StatelessWidget {
  final int itemCount;

  const OutletListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        itemCount: itemCount,
        itemBuilder: (_, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            children: [
              const AppSkeletonBox(width: 52, height: 52, radius: 99),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 150, height: 16, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(height: 12, radius: 99),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              index == 0
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSkeletonBox(width: 24, height: 24, radius: 99),
                        SizedBox(height: 5),
                        AppSkeletonBox(width: 28, height: 10, radius: 99),
                      ],
                    )
                  : const AppSkeletonBox(width: 72, height: 38, radius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class ManagementListSkeleton extends StatelessWidget {
  final int itemCount;
  final bool showSearch;
  final bool grouped;

  const ManagementListSkeleton({
    super.key,
    this.itemCount = 4,
    this.showSearch = true,
    this.grouped = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        shrinkWrap: true,
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          if (showSearch) ...[
            const AppSkeletonBox(height: 46, radius: 12),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) => AppSkeletonBox(
                  width: index == 0 ? 76 : 92,
                  height: 38,
                  radius: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...List.generate(
            itemCount,
            (index) => grouped
                ? const _GroupedManagementCardSkeleton()
                : const _SimpleManagementCardSkeleton(),
          ),
        ],
      ),
    );
  }
}

class _GroupedManagementCardSkeleton extends StatelessWidget {
  const _GroupedManagementCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(child: AppSkeletonBox(height: 16, radius: 8)),
                SizedBox(width: 14),
                AppSkeletonBox(width: 72, height: 24, radius: 99),
              ],
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: [
                _InlineItemSkeleton(),
                SizedBox(height: 14),
                _InlineItemSkeleton(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(child: AppSkeletonBox(height: 42, radius: 12)),
                SizedBox(width: 12),
                Expanded(child: AppSkeletonBox(height: 42, radius: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleManagementCardSkeleton extends StatelessWidget {
  const _SimpleManagementCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          AppSkeletonBox(width: 48, height: 48, radius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 140, height: 15, radius: 8),
                SizedBox(height: 9),
                AppSkeletonBox(height: 12, radius: 99),
              ],
            ),
          ),
          SizedBox(width: 12),
          AppSkeletonBox(width: 28, height: 28, radius: 99),
        ],
      ),
    );
  }
}

class _InlineItemSkeleton extends StatelessWidget {
  const _InlineItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        AppSkeletonBox(width: 48, height: 48, radius: 12),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonBox(width: 120, height: 14, radius: 8),
              SizedBox(height: 8),
              AppSkeletonBox(width: 84, height: 12, radius: 99),
            ],
          ),
        ),
        SizedBox(width: 12),
        AppSkeletonBox(width: 78, height: 16, radius: 99),
      ],
    );
  }
}

class SettingsHomeSkeleton extends StatelessWidget {
  const SettingsHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 68, height: 68, radius: 16),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 170, height: 18, radius: 8),
                        SizedBox(height: 10),
                        AppSkeletonBox(width: 112, height: 12, radius: 99),
                        SizedBox(height: 8),
                        AppSkeletonBox(width: 150, height: 12, radius: 99),
                      ],
                    ),
                  ),
                  AppSkeletonBox(width: 34, height: 34, radius: 99),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: AppSkeletonBox(height: 68, radius: 16)),
                SizedBox(width: 12),
                Expanded(child: AppSkeletonBox(height: 68, radius: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 16),
            const AppSkeletonBox(height: 78, radius: 18),
            const SizedBox(height: 28),
            const AppSkeletonBox(width: 92, height: 15, radius: 99),
            const SizedBox(height: 12),
            ...List.generate(5, (_) => const _SimpleManagementCardSkeleton()),
          ],
        ),
      ),
    );
  }
}

class ActivationPageSkeleton extends StatelessWidget {
  const ActivationPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 176,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: AppSkeletonBox(height: 64, radius: 18)),
              SizedBox(width: 12),
              Expanded(child: AppSkeletonBox(height: 64, radius: 18)),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              AppSkeletonBox(width: 160, height: 16, radius: 99),
              Spacer(),
              AppSkeletonBox(width: 82, height: 32, radius: 99),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 46, height: 46, radius: 14),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 150, height: 15, radius: 8),
                        SizedBox(height: 9),
                        AppSkeletonBox(height: 11, radius: 99),
                        SizedBox(height: 7),
                        AppSkeletonBox(width: 96, height: 11, radius: 99),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  AppSkeletonBox(width: 78, height: 34, radius: 99),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryDashboardSkeleton extends StatelessWidget {
  const SummaryDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(17, 20, 17, 104),
        children: [
          ...List.generate(
            4,
            (index) => Container(
              height: 123,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Stack(
                children: const [
                  Positioned(
                    right: -8,
                    bottom: -22,
                    child: AppSkeletonBox(width: 112, height: 112, radius: 99),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: AppSkeletonBox(width: 150, height: 16, radius: 8),
                  ),
                  Positioned(
                    left: 0,
                    top: 30,
                    child: AppSkeletonBox(width: 210, height: 12, radius: 99),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: AppSkeletonBox(width: 52, height: 34, radius: 10),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: AppSkeletonBox(width: 44, height: 44, radius: 99),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const AppSkeletonBox(height: 84, radius: 18),
        ],
      ),
    );
  }
}

class ReportDashboardSkeleton extends StatelessWidget {
  const ReportDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 58, height: 58, radius: 16),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 170, height: 18, radius: 8),
                        SizedBox(height: 8),
                        AppSkeletonBox(height: 12, radius: 99),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: List.generate(
                  6,
                  (_) => Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 34, height: 34, radius: 12),
                        Spacer(),
                        AppSkeletonBox(width: 78, height: 12, radius: 99),
                        SizedBox(height: 10),
                        AppSkeletonBox(width: 54, height: 22, radius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const AppSkeletonBox(width: 130, height: 18, radius: 8),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (_) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    AppSkeletonBox(width: 46, height: 46, radius: 14),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonBox(height: 16, radius: 8),
                          SizedBox(height: 8),
                          AppSkeletonBox(width: 180, height: 12, radius: 99),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    AppSkeletonBox(width: 24, height: 24, radius: 99),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusDetailSkeleton extends StatelessWidget {
  const StatusDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 120, height: 14, radius: 99),
                SizedBox(height: 14),
                AppSkeletonBox(width: 210, height: 24, radius: 10),
                SizedBox(height: 10),
                AppSkeletonBox(width: 160, height: 12, radius: 99),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeletonBox(width: 50, height: 50, radius: 99),
                AppSkeletonBox(width: 50, height: 50, radius: 99),
                AppSkeletonBox(width: 50, height: 50, radius: 99),
                AppSkeletonBox(width: 50, height: 50, radius: 99),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 135, height: 16, radius: 8),
                  SizedBox(height: 14),
                  _ReceiptLineSkeleton(labelWidth: 90, valueWidth: 120),
                  _ReceiptLineSkeleton(labelWidth: 76, valueWidth: 92),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KoinTopupSkeleton extends StatelessWidget {
  const KoinTopupSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeletonBox(width: 130, height: 14, radius: 99),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (_, _) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 42, height: 42, radius: 99),
                    Spacer(),
                    AppSkeletonBox(width: 88, height: 18, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(width: 112, height: 12, radius: 99),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const AppSkeletonBox(width: 110, height: 14, radius: 99),
            const SizedBox(height: 12),
            const AppSkeletonBox(height: 54, radius: 16),
            const SizedBox(height: 18),
            const AppSkeletonBox(
              width: double.infinity,
              height: 52,
              radius: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class KoinHistorySkeleton extends StatelessWidget {
  const KoinHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
        children: [
          const AppSkeletonBox(width: 138, height: 16, radius: 8),
          const SizedBox(height: 14),
          ...List.generate(
            5,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  AppSkeletonBox(width: 44, height: 44, radius: 14),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 150, height: 16, radius: 8),
                        SizedBox(height: 8),
                        AppSkeletonBox(width: 118, height: 12, radius: 99),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  AppSkeletonBox(width: 76, height: 16, radius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusListSkeleton extends StatelessWidget {
  final int itemCount;

  const StatusListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        itemCount: itemCount,
        itemBuilder: (_, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppSkeletonBox(height: 16, radius: 8),
                            ),
                            SizedBox(width: 12),
                            AppSkeletonBox(width: 72, height: 22, radius: 99),
                          ],
                        ),
                        SizedBox(height: 12),
                        AppSkeletonBox(width: 170, height: 12, radius: 99),
                        SizedBox(height: 8),
                        AppSkeletonBox(width: 150, height: 12, radius: 99),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  AppSkeletonBox(width: 80, height: 20, radius: 99),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: AppSkeletonBox(height: 12, radius: 99)),
                  SizedBox(width: 12),
                  AppSkeletonBox(width: 82, height: 12, radius: 99),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportPageSkeleton extends StatelessWidget {
  final int itemCount;

  const ReportPageSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 110, height: 12, radius: 99),
                SizedBox(height: 12),
                AppSkeletonBox(width: 180, height: 28, radius: 10),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: AppSkeletonBox(height: 58, radius: 14)),
              SizedBox(width: 12),
              Expanded(child: AppSkeletonBox(height: 58, radius: 14)),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeletonBox(width: 120, height: 14, radius: 99),
              AppSkeletonBox(width: 90, height: 36, radius: 12),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(
            itemCount,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(height: 14, radius: 8),
                        SizedBox(height: 8),
                        AppSkeletonBox(width: 120, height: 12, radius: 99),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  AppSkeletonBox(width: 64, height: 24, radius: 99),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BankListSkeleton extends StatelessWidget {
  final int itemCount;

  const BankListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: itemCount,
        itemBuilder: (_, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F3F5), width: 2),
          ),
          child: const Row(
            children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(height: 16, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(width: 110, height: 12, radius: 99),
                  ],
                ),
              ),
              SizedBox(width: 12),
              AppSkeletonBox(width: 16, height: 16, radius: 99),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsFormSkeleton extends StatelessWidget {
  final int toggleCount;

  const SettingsFormSkeleton({super.key, this.toggleCount = 6});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonBox(width: 90, height: 14, radius: 99),
                const SizedBox(height: 16),
                const AppSkeletonBox(height: 52),
                const SizedBox(height: 12),
                const AppSkeletonBox(height: 52),
                const SizedBox(height: 12),
                const AppSkeletonBox(height: 52),
                const SizedBox(height: 20),
                const AppSkeletonBox(width: 110, height: 14, radius: 99),
                const SizedBox(height: 16),
                const AppSkeletonBox(height: 90, radius: 16),
                const SizedBox(height: 20),
                ...List.generate(
                  toggleCount,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Expanded(child: AppSkeletonBox(height: 16, radius: 99)),
                        SizedBox(width: 12),
                        AppSkeletonBox(width: 46, height: 26, radius: 99),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const AppSkeletonBox(
                  width: double.infinity,
                  height: 50,
                  radius: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditOutletProfileSkeleton extends StatelessWidget {
  const EditOutletProfileSkeleton({super.key});

  Widget _field({double width = 90}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSkeletonBox(width: width, height: 12, radius: 99),
      const SizedBox(height: 8),
      const AppSkeletonBox(height: 54, radius: 20),
    ],
  );

  Widget _selector({double width = 90}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSkeletonBox(width: width, height: 12, radius: 99),
      const SizedBox(height: 8),
      const AppSkeletonBox(height: 54, radius: 15),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: AppSkeletonBox(
                      width: 110,
                      height: 110,
                      radius: 55,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _field(width: 110),
                  const SizedBox(height: 16),
                  _field(width: 150),
                  const SizedBox(height: 16),
                  _selector(width: 60),
                  const SizedBox(height: 16),
                  _selector(width: 110),
                  const SizedBox(height: 16),
                  _selector(width: 90),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSkeletonBox(width: 120, height: 12, radius: 99),
                      const SizedBox(height: 8),
                      const AppSkeletonBox(height: 96, radius: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppSkeletonBox(
              width: double.infinity,
              height: 55,
              radius: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class NotaPreviewSkeleton extends StatelessWidget {
  const NotaPreviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        child: Center(
          child: Container(
            width: 330,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppSkeletonBox(width: 120, height: 18, radius: 8),
                SizedBox(height: 8),
                AppSkeletonBox(width: 170, height: 12, radius: 99),
                SizedBox(height: 22),
                Divider(height: 1, color: Colors.white),
                SizedBox(height: 18),
                _ReceiptLineSkeleton(labelWidth: 76, valueWidth: 128),
                _ReceiptLineSkeleton(labelWidth: 58, valueWidth: 96),
                _ReceiptLineSkeleton(labelWidth: 92, valueWidth: 118),
                SizedBox(height: 18),
                AppSkeletonBox(height: 1, radius: 0),
                SizedBox(height: 18),
                _ReceiptLineSkeleton(labelWidth: 128, valueWidth: 76),
                _ReceiptLineSkeleton(labelWidth: 110, valueWidth: 92),
                _ReceiptLineSkeleton(labelWidth: 88, valueWidth: 112),
                SizedBox(height: 16),
                AppSkeletonBox(width: 110, height: 110, radius: 10),
                SizedBox(height: 16),
                AppSkeletonBox(width: 160, height: 12, radius: 99),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptLineSkeleton extends StatelessWidget {
  final double labelWidth;
  final double valueWidth;

  const _ReceiptLineSkeleton({
    required this.labelWidth,
    required this.valueWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AppSkeletonBox(width: labelWidth, height: 12, radius: 99),
          const Spacer(),
          AppSkeletonBox(width: valueWidth, height: 12, radius: 99),
        ],
      ),
    );
  }
}
