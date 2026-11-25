import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/service/fcm_service.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/responsive_center.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const seenKey = 'has_seen_first_run_onboarding_v2';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _isFinishing = false;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      eyebrow: '',
      title: 'Siap Terima Pesanan',
      body:
          'Pantau status cucian, proses pengerjaan, hingga pesanan selesai dalam satu tampilan yang rapi dan terorganisir.',
      previewAsset: 'assets/onboarding/1/image 272.png',
      topRibbonAsset: 'assets/onboarding/1/image 281.png',
      mascotAsset: 'assets/onboarding/1/2 12.png',
      accessoryAsset: 'assets/onboarding/1/image 303.png',
      buttonLabel: 'Selanjutnya',
      previewHeightFactor: 0.29,
      previewWidthFactor: 0.92,
      mascotWidthFactor: 0.46,
      mascotTopOffset: -22,
      mascotAlignX: 0,
      previewTopOffset: 24,
      previewFlex: 7,
      mascotFlex: 6,
      accessoryWidthFactor: 0.42,
      accessoryLeftFactor: -0.26,
      accessoryBottom: 16,
      titleTopSpacing: 6,
      eyebrowTopSpacing: 10,
      contentShift: 0.035,
    ),
    _OnboardingSlideData(
      eyebrow: '',
      title: 'Jangan Sampai Terlewat',
      body:
          'Dapatkan informasi status cucian secara langsung untuk membantu tim bekerja lebih cepat dan tepat waktu.',
      previewAsset: 'assets/onboarding/2/Frame 3588.png',
      mascotAsset: 'assets/onboarding/2/4 2.png',
      buttonLabel: 'Selanjutnya',
      previewHeightFactor: 0.43,
      previewWidthFactor: 0.98,
      floatingMascotWidthFactor: 0.30,
      floatingMascotBottomFactor: 0.62,
      floatingMascotRightFactor: 0.07,
      titleTopSpacing: 8,
      eyebrowTopSpacing: 8,
      textHorizontalPadding: 22,
      contentShift: 0.03,
    ),
    _OnboardingSlideData(
      eyebrow: '',
      title: 'Bisnis Terus Tumbuh',
      body:
          'Pantau penjualan, transaksi, dan performa layanan melalui laporan yang jelas untuk membantu mengambil keputusan lebih baik.',
      previewAsset: 'assets/onboarding/3/image 300.png',
      mascotAsset: 'assets/maskot/1 501.webp',
      accessoryAsset: 'assets/onboarding/3/image 302.png',
      buttonLabel: 'Mulai Sekarang',
      previewHeightFactor: 0.27,
      previewWidthFactor: 0.56,
      previewOffsetX: -70,
      previewTopOffset: 60,
      previewScale: 1.35,
      mascotWidthFactor: 0.52,
      mascotTopOffset: -8,
      mascotAlignX: -0.14,
      accessoryWidthFactor: 0.62,
      accessoryLeftFactor: 0.62,
      accessoryBottom: 4,
      titleTopSpacing: 6,
      eyebrowTopSpacing: 8,
      textHorizontalPadding: 26,
      contentShift: 0.025,
    ),
  ];

  bool get _isLastStep => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_isLastStep) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      await FCMService.ensureNotificationReadiness(
        context: context,
        promptIfNeeded: true,
        reason: 'onboarding_finish',
      );
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
    await _finish();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.seenKey, true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEFE8), Colors.white, Color(0xFFFFF6F2)],
            stops: [0, 0.5, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -120,
              right: -80,
              child: _AmbientGlow(size: 240, color: Color(0x15FF7A45)),
            ),
            const Positioned(
              left: -90,
              top: 180,
              child: _AmbientGlow(size: 180, color: Color(0x10FFB58F)),
            ),
            SafeArea(
              child: ResponsiveCenter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              AppAssetImage(
                                'assets/icons/logo/logo_login_screen.webp',
                                height: 28,
                                errorWidget: Text(
                                  'ayocuci',
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: AppPalette.primaryDeep,
                                    fontWeight: AppFont.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppPalette.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${_index + 1}/${_slides.length}',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: AppPalette.primaryDeep,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: List.generate(
                              _slides.length,
                              (index) => Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                  height: 5,
                                  margin: EdgeInsets.only(
                                    right: index == _slides.length - 1 ? 0 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: index <= _index
                                        ? const LinearGradient(
                                            colors: AppPalette.brandGradient,
                                          )
                                        : null,
                                    color: index <= _index
                                        ? null
                                        : AppPalette.primary.withValues(
                                            alpha: 0.14,
                                          ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemBuilder: (context, index) {
                          return _OnboardingSlide(data: _slides[index]);
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 18, 24, 25),
                      child: SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _isFinishing ? null : _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(29),
                            ),
                          ),
                          child: _isFinishing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _slides[_index].buttonLabel,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: AppFont.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
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

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final _OnboardingSlideData data;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textTheme = Theme.of(context).textTheme;
    final previewWidth = size.width * data.previewWidthFactor;
    final mascotWidth = size.width * data.mascotWidthFactor;
    final floatingMascotWidth = size.width * data.floatingMascotWidthFactor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
      child: Column(
        children: [
          // Area visual FLEKSIBEL: mengecil sendiri di layar pendek sehingga
          // blok teks di bawah selalu tampil (tidak akan terpotong tombol).
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => data.hasFloatingMascot
                  ? _floatingVisual(
                      size,
                      box,
                      previewWidth,
                      floatingMascotWidth,
                    )
                  : _stackedVisual(previewWidth, mascotWidth),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: textTheme.headlineLarge?.copyWith(
              fontSize: 23,
              height: 1.18,
              fontWeight: AppFont.w800,
              color: const Color(0xFF22252C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.body,
            textAlign: TextAlign.center,
            maxLines: 3,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: AppFont.w500,
              color: const Color(0xFF6E7480),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Slide 1 & 3: preview di atas, mascot (lebih besar) di bawah. Keduanya
  // Flexible + BoxFit.contain → selalu muat berapa pun tinggi yang tersedia.
  Widget _stackedVisual(double previewWidth, double mascotWidth) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: data.previewFlex,
          // Transform.translate menurunkan kartu tanpa mengubah layout mascot.
          child: Transform.translate(
            offset: Offset(data.previewOffsetX, data.previewTopOffset),
            child: Transform.scale(
              scale: data.previewScale,
              child: _previewBlock(previewWidth),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          flex: data.mascotFlex,
          // mascotAlignX menggeser horizontal, mascotTopOffset menariknya naik
          // agar overlap dengan kartu di atasnya (mis. slide 1).
          child: Transform.translate(
            offset: Offset(
              mascotWidth * data.mascotAlignX,
              data.mascotTopOffset,
            ),
            child: _mascotBlock(mascotWidth),
          ),
        ),
      ],
    );
  }

  Widget _previewBlock(double previewWidth) {
    final preview = SizedBox(
      width: previewWidth,
      child: AppAssetImage(
        data.previewAsset,
        fit: BoxFit.contain,
        cacheWidth: (previewWidth * 2).round(),
      ),
    );
    if (data.topRibbonAsset == null) {
      return Center(child: preview);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: previewWidth,
          height: 34,
          child: AppAssetImage(
            data.topRibbonAsset!,
            fit: BoxFit.contain,
            cacheWidth: (previewWidth * 2).round(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SizedBox(
              width: previewWidth,
              child: _SoftFramedPreview(child: preview),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mascotBlock(double mascotWidth) {
    final mascot = AppAssetImage(
      data.mascotAsset,
      fit: BoxFit.contain,
      cacheWidth: (mascotWidth * 2).round(),
    );
    if (data.accessoryAsset == null) {
      return Center(
        child: SizedBox(width: mascotWidth, child: mascot),
      );
    }
    return Center(
      child: SizedBox(
        width: mascotWidth,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: mascotWidth * data.accessoryLeftFactor,
              bottom: data.accessoryBottom,
              width: mascotWidth * data.accessoryWidthFactor,
              child: AppAssetImage(
                data.accessoryAsset!,
                fit: BoxFit.contain,
                cacheWidth: ((mascotWidth * data.accessoryWidthFactor) * 2)
                    .round(),
              ),
            ),
            mascot,
          ],
        ),
      ),
    );
  }

  // Slide 2: kartu-kartu dengan mascot MENYEMBUL di atas (overlap tepi atas).
  Widget _floatingVisual(
    Size size,
    BoxConstraints box,
    double previewWidth,
    double floatingMascotWidth,
  ) {
    // Seberapa jauh kartu digeser turun = bagian mascot yang tampak di atasnya.
    final peek = floatingMascotWidth * 0.5;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Mascot DI BELAKANG kartu (child pertama = paling belakang), menyembul
        // di atas. Bagian bawahnya nanti tertutup kartu.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(
            alignment: const Alignment(0.4, 0),
            child: SizedBox(
              width: floatingMascotWidth,
              child: AppAssetImage(
                data.mascotAsset,
                fit: BoxFit.contain,
                cacheWidth: (floatingMascotWidth * 2).round(),
              ),
            ),
          ),
        ),
        // Kartu di DEPAN, digeser turun sehingga menutupi bagian bawah mascot.
        Padding(
          padding: EdgeInsets.only(top: peek),
          child: Center(
            child: SizedBox(
              width: previewWidth,
              child: AppAssetImage(
                data.previewAsset,
                fit: BoxFit.contain,
                cacheWidth: (previewWidth * 2).round(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SoftFramedPreview extends StatelessWidget {
  const _SoftFramedPreview({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10FF7C45),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.previewAsset,
    required this.mascotAsset,
    required this.buttonLabel,
    this.topRibbonAsset,
    this.accessoryAsset,
    this.previewHeightFactor = 0.25,
    this.previewWidthFactor = 0.85,
    this.mascotWidthFactor = 0.5,
    this.floatingMascotWidthFactor = 0,
    this.floatingMascotBottomFactor = 0,
    this.floatingMascotRightFactor = 0,
    this.accessoryWidthFactor = 0.3,
    this.accessoryLeftFactor = 0,
    this.accessoryBottom = 28,
    this.mascotTopOffset = 0,
    this.mascotAlignX = 0,
    this.previewTopOffset = 0,
    this.previewOffsetX = 0,
    this.previewScale = 1.0,
    this.previewFlex = 5,
    this.mascotFlex = 6,
    this.titleTopSpacing = 10,
    this.eyebrowTopSpacing = 6,
    this.textHorizontalPadding = 16,
    this.contentShift = 0,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String previewAsset;
  final String mascotAsset;
  final String buttonLabel;
  final String? topRibbonAsset;
  final String? accessoryAsset;
  final double previewHeightFactor;
  final double previewWidthFactor;
  final double mascotWidthFactor;
  final double mascotAlignX;
  final double previewTopOffset;
  final double previewOffsetX;
  final double previewScale;
  final int previewFlex;
  final int mascotFlex;
  final double floatingMascotWidthFactor;
  final double floatingMascotBottomFactor;
  final double floatingMascotRightFactor;
  final double accessoryWidthFactor;
  final double accessoryLeftFactor;
  final double accessoryBottom;
  final double mascotTopOffset;
  final double titleTopSpacing;
  final double eyebrowTopSpacing;
  final double textHorizontalPadding;
  final double contentShift;

  bool get hasFloatingMascot => floatingMascotWidthFactor > 0;
}
