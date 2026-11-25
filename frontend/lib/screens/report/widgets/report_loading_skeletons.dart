import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';

class ReportExportIconSkeleton extends StatelessWidget {
  const ReportExportIconSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: AppSkeletonBox(width: 22, height: 22, radius: 6),
    );
  }
}

class ReportLoadMoreTileSkeleton extends StatelessWidget {
  const ReportLoadMoreTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
        ),
        child: const Row(
          children: [
            AppSkeletonBox(width: 42, height: 42, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 150, height: 13, radius: 99),
                  SizedBox(height: 8),
                  AppSkeletonBox(width: 112, height: 11, radius: 99),
                ],
              ),
            ),
            SizedBox(width: 12),
            AppSkeletonBox(width: 82, height: 16, radius: 99),
          ],
        ),
      ),
    );
  }
}

class ReportTransactionSliverSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const ReportTransactionSliverSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 40),
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, index) => Opacity(
            opacity: index == itemCount - 1 ? 0.55 : 1,
            child: const ReportLoadMoreTileSkeleton(),
          ),
          childCount: itemCount,
        ),
      ),
    );
  }
}

class ReportTransactionListSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const ReportTransactionListSkeleton({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (_, index) => Opacity(
        opacity: index == itemCount - 1 ? 0.55 : 1,
        child: const ReportLoadMoreTileSkeleton(),
      ),
    );
  }
}

class ReportExpenseDetailSkeleton extends StatelessWidget {
  const ReportExpenseDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 120, height: 12, radius: 99),
                      SizedBox(height: 12),
                      AppSkeletonBox(width: 170, height: 30, radius: 10),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AppSkeletonBox(height: 48, radius: 14),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: AppSkeletonBox(height: 48, radius: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(child: AppSkeletonBox(height: 46, radius: 14)),
                    SizedBox(width: 10),
                    AppSkeletonBox(width: 46, height: 46, radius: 14),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: 4,
              itemBuilder: (_, index) => Opacity(
                opacity: index == 3 ? 0.55 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          AppSkeletonBox(width: 42, height: 42, radius: 12),
                          SizedBox(width: 12),
                          Expanded(
                            child: AppSkeletonBox(height: 14, radius: 99),
                          ),
                          SizedBox(width: 12),
                          AppSkeletonBox(width: 86, height: 16, radius: 99),
                        ],
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AppSkeletonBox(height: 11, radius: 99),
                          ),
                          SizedBox(width: 10),
                          AppSkeletonBox(width: 74, height: 11, radius: 99),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCustomerDetailSkeleton extends StatelessWidget {
  const ReportCustomerDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 132, height: 12, radius: 99),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: AppSkeletonBox(height: 54, radius: 16),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: AppSkeletonBox(height: 54, radius: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Expanded(child: AppSkeletonBox(height: 48, radius: 16)),
                    SizedBox(width: 10),
                    AppSkeletonBox(width: 48, height: 48, radius: 16),
                  ],
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    AppSkeletonBox(width: 130, height: 14, radius: 99),
                    Spacer(),
                    AppSkeletonBox(width: 72, height: 12, radius: 99),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(child: ReportTransactionListSkeleton()),
        ],
      ),
    );
  }
}

class ReportChartCardSkeleton extends StatelessWidget {
  const ReportChartCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: 250,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                AppSkeletonBox(width: 130, height: 14, radius: 99),
                Spacer(),
                AppSkeletonBox(width: 84, height: 32, radius: 14),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final height in const [
                    0.40,
                    0.72,
                    0.55,
                    0.90,
                    0.62,
                    0.78,
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FractionallySizedBox(
                          heightFactor: height,
                          alignment: Alignment.bottomCenter,
                          child: const AppSkeletonBox(
                            height: double.infinity,
                            radius: 8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                AppSkeletonBox(width: 78, height: 11, radius: 99),
                SizedBox(width: 12),
                AppSkeletonBox(width: 94, height: 11, radius: 99),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReportInlineDetailSkeleton extends StatelessWidget {
  const ReportInlineDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Opacity(
                opacity: i == 2 ? 0.55 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      AppSkeletonBox(width: 34, height: 34, radius: 10),
                      SizedBox(width: 10),
                      Expanded(child: AppSkeletonBox(height: 12, radius: 99)),
                      SizedBox(width: 12),
                      AppSkeletonBox(width: 72, height: 12, radius: 99),
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
