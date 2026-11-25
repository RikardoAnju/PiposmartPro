part of '../../payroll_screen.dart';

class _PayrollPageSkeleton extends StatelessWidget {
  const _PayrollPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Icon(
          Icons.arrow_back_ios_new,
          color: AppPalette.ink,
          size: 20,
        ),
        title: const Text(
          'Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: AppShimmer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _PayrollHeroSkeleton(),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _PayrollStatSkeleton()),
                SizedBox(width: 12),
                Expanded(child: _PayrollStatSkeleton()),
              ],
            ),
            SizedBox(height: 14),
            _ActionCardSkeleton(),
            SizedBox(height: 18),
            _TabBarSkeleton(),
            SizedBox(height: 16),
            _PayrollListSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _PayrollListSkeleton extends StatelessWidget {
  const _PayrollListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: const _PayrollGroupCardSkeleton(),
        ),
      ),
    );
  }
}

class _PayrollDetailSkeleton extends StatelessWidget {
  const _PayrollDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Icon(
          Icons.arrow_back_ios_new,
          color: AppPalette.ink,
          size: 20,
        ),
        title: const Text(
          'Detail Penggajian',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: AppShimmer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _PayrollHeaderSkeleton(),
            SizedBox(height: 14),
            _PayrollDetailCardSkeleton(),
            SizedBox(height: 16),
            _PayrollSectionSkeleton(),
            SizedBox(height: 14),
            _PayrollSectionSkeleton(),
            SizedBox(height: 14),
            _PayrollSummarySkeleton(),
            SizedBox(height: 14),
            _PayrollMethodSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _PayrollConfigListSkeleton extends StatelessWidget {
  const _PayrollConfigListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
          child: const _ConfigCardSkeleton(),
        ),
      ),
    );
  }
}

class _PayrollHeroSkeleton extends StatelessWidget {
  const _PayrollHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6A39).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeletonBox(width: 42, height: 42, radius: 14),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 120, height: 16, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(width: 160, height: 12, radius: 99),
                  ],
                ),
              ),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppSkeletonBox(width: 42, height: 10, radius: 99),
                  SizedBox(height: 8),
                  AppSkeletonBox(width: 84, height: 14, radius: 8),
                ],
              ),
            ],
          ),
          SizedBox(height: 18),
          AppSkeletonBox(width: 96, height: 12, radius: 99),
          SizedBox(height: 8),
          AppSkeletonBox(width: 180, height: 28, radius: 10),
          SizedBox(height: 14),
          Row(
            children: [
              AppSkeletonBox(width: 88, height: 28, radius: 99),
              SizedBox(width: 10),
              AppSkeletonBox(width: 88, height: 28, radius: 99),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayrollStatSkeleton extends StatelessWidget {
  const _PayrollStatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBox(width: 28, height: 18, radius: 8),
          SizedBox(height: 8),
          AppSkeletonBox(width: 84, height: 12, radius: 99),
        ],
      ),
    );
  }
}

class _ActionCardSkeleton extends StatelessWidget {
  const _ActionCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Row(
        children: [
          AppSkeletonBox(width: 44, height: 44, radius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 160, height: 15, radius: 8),
                SizedBox(height: 8),
                AppSkeletonBox(width: 190, height: 12, radius: 99),
              ],
            ),
          ),
          SizedBox(width: 12),
          AppSkeletonBox(width: 18, height: 18, radius: 99),
        ],
      ),
    );
  }
}

class _TabBarSkeleton extends StatelessWidget {
  const _TabBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: AppSkeletonBox(height: 42, radius: 14)),
        SizedBox(width: 12),
        Expanded(child: AppSkeletonBox(height: 42, radius: 14)),
      ],
    );
  }
}

class _PayrollGroupCardSkeleton extends StatelessWidget {
  const _PayrollGroupCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppSkeletonBox(width: 42, height: 42, radius: 14),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 110, height: 15, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(width: 72, height: 11, radius: 99),
                  ],
                ),
              ),
              SizedBox(width: 12),
              AppSkeletonBox(width: 92, height: 26, radius: 99),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: _PayrollGroupMetricSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _PayrollGroupMetricSkeleton()),
            ],
          ),
          const SizedBox(height: 12),
          const AppSkeletonBox(height: 56, radius: 14),
        ],
      ),
    );
  }
}

class _PayrollGroupMetricSkeleton extends StatelessWidget {
  const _PayrollGroupMetricSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBox(width: 64, height: 11, radius: 99),
          SizedBox(height: 8),
          AppSkeletonBox(width: 86, height: 16, radius: 8),
        ],
      ),
    );
  }
}

class _PayrollHeaderSkeleton extends StatelessWidget {
  const _PayrollHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Row(
        children: [
          AppSkeletonBox(width: 54, height: 54, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 140, height: 16, radius: 8),
                SizedBox(height: 8),
                AppSkeletonBox(width: 76, height: 12, radius: 99),
              ],
            ),
          ),
          SizedBox(width: 12),
          AppSkeletonBox(width: 94, height: 28, radius: 99),
        ],
      ),
    );
  }
}

class _PayrollDetailCardSkeleton extends StatelessWidget {
  const _PayrollDetailCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppSkeletonBox(width: 100, height: 12, radius: 99),
              ),
              SizedBox(width: 12),
              Expanded(
                child: AppSkeletonBox(width: 120, height: 14, radius: 99),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppSkeletonBox(width: 100, height: 12, radius: 99),
              ),
              SizedBox(width: 12),
              Expanded(
                child: AppSkeletonBox(width: 90, height: 14, radius: 99),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppSkeletonBox(width: 100, height: 12, radius: 99),
              ),
              SizedBox(width: 12),
              Expanded(
                child: AppSkeletonBox(width: 86, height: 14, radius: 99),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(height: 18),
          AppSkeletonBox(width: double.infinity, height: 96, radius: 16),
        ],
      ),
    );
  }
}

class _PayrollSectionSkeleton extends StatelessWidget {
  const _PayrollSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBox(width: 120, height: 14, radius: 99),
          SizedBox(height: 14),
          AppSkeletonBox(width: double.infinity, height: 54, radius: 14),
          SizedBox(height: 10),
          AppSkeletonBox(width: 110, height: 14, radius: 99),
        ],
      ),
    );
  }
}

class _PayrollSummarySkeleton extends StatelessWidget {
  const _PayrollSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBox(width: 130, height: 14, radius: 99),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppSkeletonBox(width: 90, height: 12, radius: 99),
              ),
              SizedBox(width: 12),
              AppSkeletonBox(width: 100, height: 14, radius: 99),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppSkeletonBox(width: 90, height: 12, radius: 99),
              ),
              SizedBox(width: 12),
              AppSkeletonBox(width: 100, height: 14, radius: 99),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayrollMethodSkeleton extends StatelessWidget {
  const _PayrollMethodSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBox(width: 130, height: 14, radius: 99),
          SizedBox(height: 14),
          AppSkeletonBox(width: double.infinity, height: 52, radius: 14),
        ],
      ),
    );
  }
}

class _ConfigCardSkeleton extends StatelessWidget {
  const _ConfigCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.cardSoft,
      ),
      child: const Row(
        children: [
          AppSkeletonBox(width: 46, height: 46, radius: 14),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 120, height: 15, radius: 8),
                SizedBox(height: 8),
                AppSkeletonBox(width: 150, height: 12, radius: 99),
              ],
            ),
          ),
          SizedBox(width: 12),
          AppSkeletonBox(width: 72, height: 24, radius: 99),
        ],
      ),
    );
  }
}
