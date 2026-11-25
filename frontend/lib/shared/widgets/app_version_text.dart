import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key, this.style, this.showBuildNumber = false});

  final TextStyle? style;
  final bool showBuildNumber;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version;
        final buildNumber = info?.buildNumber;
        final text = version == null || version.isEmpty
            ? 'v.-'
            : showBuildNumber && buildNumber != null && buildNumber.isNotEmpty
            ? 'v.$version ($buildNumber)'
            : 'v.$version';

        return Text(text, style: style);
      },
    );
  }
}
