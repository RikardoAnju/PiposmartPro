import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'package:ayocucinew/core/theme/app_palette.dart';

class CelebrationChipData {
  const CelebrationChipData({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class CeremonialSuccessScreen extends StatefulWidget {
  const CeremonialSuccessScreen({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    required this.chips,
    this.chipsVertical = false,
    this.mascotAsset = 'assets/maskot/outlet_pro_mascot.png',
    this.soundAsset,
    this.playSound = true,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<CelebrationChipData> chips;
  final bool chipsVertical;
  final String mascotAsset;
  final String? soundAsset;
  final bool playSound;

  @override
  State<CeremonialSuccessScreen> createState() =>
      _CeremonialSuccessScreenState();
}

class _CeremonialSuccessScreenState extends State<CeremonialSuccessScreen>
    with TickerProviderStateMixin {
  static const _confettiColors = [
    Color(0xFFFFE34D),
    Color(0xFF2897FF),
    Color(0xFFFF4B92),
    Colors.white,
    Color(0xFFFF7A2F),
  ];

  late final AnimationController _controller;
  late final AnimationController _idleController;
  late final ConfettiController _burstConfettiController;
  late final ConfettiController _rainConfettiController;
  late final ConfettiController _leftConfettiController;
  late final ConfettiController _rightConfettiController;
  late final AudioPlayer _audioPlayer;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _panelSlide;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroFloat;
  late final Animation<double> _heroIdleFloat;
  late final Animation<double> _heroIdleScale;
  late final Animation<double> _badgeOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _burstConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 1600),
    );
    _rainConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 2600),
    );
    _leftConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 1800),
    );
    _rightConfettiController = ConfettiController(
      duration: const Duration(milliseconds: 1800),
    );
    _audioPlayer = AudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _burstConfettiController.play();
      _rainConfettiController.play();
      _leftConfettiController.play();
      _rightConfettiController.play();
      _playSuccessSound();
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _idleController.repeat(reverse: true);
      }
    });

    _panelOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _panelSlide = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _heroScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.68, curve: Curves.elasticOut),
      ),
    );
    _heroFloat = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.18, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _heroIdleFloat = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine),
    );
    _heroIdleScale = Tween<double>(begin: 1, end: 1.015).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine),
    );
    _badgeOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _burstConfettiController.dispose();
    _rainConfettiController.dispose();
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    _idleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _playSuccessSound() async {
    if (!widget.playSound) return;
    final soundAsset = widget.soundAsset;
    if (soundAsset == null || soundAsset.trim().isEmpty) return;
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(
        AssetSource(soundAsset.replaceFirst('assets/', '')),
      );
    } catch (e) {
      debugPrint('🔇 Success sound playback failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF223041);
    const bodyColor = Color(0xFF6E7B8B);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF7),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFCFA), Color(0xFFFFF2EA)],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Opacity(
                  opacity: _panelOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _panelSlide.value),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            child: Column(
                              children: [
                                Opacity(
                                  opacity: _badgeOpacity.value,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        widget.badge,
                                        style: const TextStyle(
                                          color: AppPalette.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.only(
                                          bottom: 20,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight,
                                          ),
                                          child: IntrinsicHeight(
                                            child: IgnorePointer(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Transform.translate(
                                                    offset: Offset(
                                                      0,
                                                      _heroFloat.value +
                                                          _heroIdleFloat.value,
                                                    ),
                                                    child: Transform.scale(
                                                      scale:
                                                          _heroScale.value *
                                                          _heroIdleScale.value,
                                                      child: Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          Container(
                                                            width: 292,
                                                            height: 292,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              gradient: const LinearGradient(
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                                colors: [
                                                                  Color(
                                                                    0xFFFFD8C2,
                                                                  ),
                                                                  Color(
                                                                    0xFFFFF2EA,
                                                                  ),
                                                                ],
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: AppPalette
                                                                      .primary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.16,
                                                                      ),
                                                                  blurRadius:
                                                                      48,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        20,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Container(
                                                            width: 226,
                                                            height: 226,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.98,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: AppPalette
                                                                      .primary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.1,
                                                                      ),
                                                                  blurRadius:
                                                                      28,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        10,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Image.asset(
                                                            widget.mascotAsset,
                                                            width: 226,
                                                            fit: BoxFit.contain,
                                                          ),
                                                          Positioned(
                                                            top: 34,
                                                            right: 20,
                                                            child: _FloatingSpark(
                                                              progress:
                                                                  _controller
                                                                      .value,
                                                              delay: 0.08,
                                                              icon: Icons
                                                                  .auto_awesome,
                                                            ),
                                                          ),
                                                          Positioned(
                                                            left: 20,
                                                            bottom: 44,
                                                            child: _FloatingSpark(
                                                              progress:
                                                                  _controller
                                                                      .value,
                                                              delay: 0.18,
                                                              icon: Icons
                                                                  .stars_rounded,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 28),
                                                  Text(
                                                    widget.title,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: titleColor,
                                                      fontSize: 30,
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    widget.subtitle,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: bodyColor,
                                                      fontSize: 14,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 22),
                                                  if (widget.chipsVertical)
                                                    Column(
                                                      children: widget.chips
                                                          .map(
                                                            (chip) => Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    bottom: 10,
                                                                  ),
                                                              child:
                                                                  _FeatureChip(
                                                                    icon: chip
                                                                        .icon,
                                                                    text: chip
                                                                        .text,
                                                                    fullWidth:
                                                                        true,
                                                                  ),
                                                            ),
                                                          )
                                                          .toList(),
                                                    )
                                                  else
                                                    Wrap(
                                                      alignment:
                                                          WrapAlignment.center,
                                                      spacing: 10,
                                                      runSpacing: 10,
                                                      children: widget.chips
                                                          .map(
                                                            (
                                                              chip,
                                                            ) => _FeatureChip(
                                                              icon: chip.icon,
                                                              text: chip.text,
                                                            ),
                                                          )
                                                          .toList(),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SafeArea(
                                  top: false,
                                  minimum: const EdgeInsets.only(bottom: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: widget.onPrimary,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF6A3D,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        shadowColor: const Color(
                                          0xFFFF6A3D,
                                        ).withValues(alpha: 0.22),
                                      ),
                                      child: Text(
                                        widget.primaryLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
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
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _burstConfettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          colors: _confettiColors,
                          emissionFrequency: 0.05,
                          numberOfParticles: 48,
                          maxBlastForce: 75,
                          minBlastForce: 38,
                          gravity: 0.2,
                          minimumSize: const Size(8, 10),
                          maximumSize: const Size(16, 18),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _rainConfettiController,
                          blastDirectionality: BlastDirectionality.directional,
                          blastDirection: 1.57,
                          shouldLoop: false,
                          colors: _confettiColors,
                          emissionFrequency: 0.02,
                          numberOfParticles: 18,
                          maxBlastForce: 16,
                          minBlastForce: 7,
                          gravity: 0.18,
                          minimumSize: const Size(8, 10),
                          maximumSize: const Size(14, 16),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(-1.08, -0.12),
                        child: ConfettiWidget(
                          confettiController: _leftConfettiController,
                          blastDirectionality: BlastDirectionality.directional,
                          blastDirection: -0.45,
                          shouldLoop: false,
                          colors: _confettiColors,
                          emissionFrequency: 0.08,
                          numberOfParticles: 20,
                          maxBlastForce: 34,
                          minBlastForce: 20,
                          gravity: 0.28,
                          minimumSize: const Size(7, 9),
                          maximumSize: const Size(14, 16),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(1.08, -0.12),
                        child: ConfettiWidget(
                          confettiController: _rightConfettiController,
                          blastDirectionality: BlastDirectionality.directional,
                          blastDirection: 3.59,
                          shouldLoop: false,
                          colors: _confettiColors,
                          emissionFrequency: 0.08,
                          numberOfParticles: 20,
                          maxBlastForce: 34,
                          minBlastForce: 20,
                          gravity: 0.28,
                          minimumSize: const Size(7, 9),
                          maximumSize: const Size(14, 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingSpark extends StatelessWidget {
  const _FloatingSpark({
    required this.progress,
    required this.delay,
    required this.icon,
  });

  final double progress;
  final double delay;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final shifted = ((progress - delay) / 0.55).clamp(0.0, 1.0);
    final opacity = Curves.easeOut.transform(shifted);
    final lift = (1 - shifted) * 12;
    final scale = 0.8 + (0.2 * opacity);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppPalette.primary, size: 18),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.icon,
    required this.text,
    this.fullWidth = false,
  });

  final IconData icon;
  final String text;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppPalette.primary),
          const SizedBox(width: 8),
          if (fullWidth)
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF304255), fontSize: 13),
              ),
            )
          else
            Text(
              text,
              style: const TextStyle(color: Color(0xFF304255), fontSize: 13),
            ),
        ],
      ),
    );
  }
}
