import 'package:flutter/foundation.dart';
import 'package:ayocucinew/shared/widgets/app_update_prompt_card.dart';
import 'package:flutter/material.dart';

class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({
    super.key,
    required this.currentVersion,
    required this.minimumVersion,
    required this.onUpdatePressed,
    required this.onRetryPressed,
    this.isRetrying = false,
  });

  final String currentVersion;
  final String minimumVersion;
  final Future<void> Function() onUpdatePressed;
  final Future<void> Function() onRetryPressed;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    return AppUpdatePromptView(
      kind: AppUpdatePromptKind.mandatory,
      currentVersion: currentVersion,
      targetVersion: minimumVersion,
      primaryLabel: defaultTargetPlatform == TargetPlatform.iOS
          ? 'Buka App Store'
          : 'Update Sekarang',
      onPrimaryPressed: onUpdatePressed,
      isBusy: isRetrying,
      secondaryLabel: 'Saya Sudah Update',
      onSecondaryPressed: onRetryPressed,
    );
  }
}
