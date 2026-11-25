import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

enum AppUpdatePromptKind { optional, mandatory }

class AppUpdatePromptView extends StatelessWidget {
  const AppUpdatePromptView({
    super.key,
    required this.kind,
    required this.currentVersion,
    required this.targetVersion,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.isBusy = false,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final AppUpdatePromptKind kind;
  final String currentVersion;
  final String targetVersion;
  final String primaryLabel;
  final Future<void> Function() onPrimaryPressed;
  final bool isBusy;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondaryPressed;

  bool get _isMandatory => kind == AppUpdatePromptKind.mandatory;

  String get _title =>
      _isMandatory ? 'Update aplikasi diperlukan' : 'Update baru tersedia';

  String get _subtitle => _isMandatory
      ? 'Versi aplikasi kamu sudah terlalu lama. Update dulu supaya AyoCuci bisa terus dipakai dengan aman.'
      : 'Ada versi yang lebih baru dengan perbaikan terbaru. Kamu bisa update sekarang atau lanjut dulu.';

  String get _versionLabel =>
      _isMandatory ? 'Minimum didukung' : 'Versi terbaru';

  String get _badgeLabel => _isMandatory ? 'Wajib update' : 'Disarankan update';

  String get _mascotAsset =>
      _isMandatory ? 'assets/maskot/3 1.webp' : 'assets/maskot/4 1.webp';

  IconData get _badgeIcon =>
      _isMandatory ? Icons.gpp_maybe_rounded : Icons.auto_awesome_rounded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.primaryPale,
      body: SafeArea(
        child: Stack(
          children: [
            // Wash brand hangat (oranye → peach → putih) menggantikan gradient
            // pink sebelumnya agar sesuai identitas AyoCuci.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                    colors: [
                      AppPalette.primarySoft,
                      AppPalette.primaryPale,
                      Colors.white,
                      AppPalette.primaryPale,
                      AppPalette.primarySoft,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0.02),
                    radius: 0.92,
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      AppPalette.primaryPale.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
            // Glow oranye di belakang maskot.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 0.84,
                    colors: [
                      AppPalette.primary.withValues(
                        alpha: _isMandatory ? 0.16 : 0.12,
                      ),
                      AppPalette.primaryWarm.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 420,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.22, 1.0],
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0xF7FFFFFF),
                      Colors.white,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppPalette.primaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _badgeIcon,
                            size: 14,
                            color: _isMandatory
                                ? AppPalette.primaryDeep
                                : AppPalette.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _badgeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isMandatory
                                  ? AppPalette.primaryDeep
                                  : AppPalette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Image.asset(_mascotAsset, height: 244, fit: BoxFit.contain),
                  const SizedBox(height: 20),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.muted,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppPalette.primaryBorder),
                    ),
                    child: Column(
                      children: [
                        _VersionRow(
                          label: 'Versi sekarang',
                          value: currentVersion,
                        ),
                        const SizedBox(height: 12),
                        _VersionRow(
                          label: _versionLabel,
                          value: targetVersion,
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: isBusy
                          ? const []
                          : AppShadows.colored(AppPalette.primary),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppPalette.heroGradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(27),
                          onTap: isBusy ? null : onPrimaryPressed,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            alignment: Alignment.center,
                            child: isBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    primaryLabel,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (secondaryLabel != null && onSecondaryPressed != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isBusy ? null : onSecondaryPressed,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: AppPalette.primary,
                      ),
                      child: Text(
                        isBusy ? 'Memeriksa...' : secondaryLabel!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isMandatory
                              ? AppPalette.muted
                              : AppPalette.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppPalette.muted,
          ),
        ),
        const Spacer(),
        if (highlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppPalette.primaryDeep,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppPalette.ink,
            ),
          ),
      ],
    );
  }
}
