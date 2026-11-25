import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';

bool shouldEnforceAddonLock(BuildContext context) {
  final outlet = context.read<AppProvider>().outlet;
  if (outlet == null) return true;
  if (outlet.activatedAt != null) return true;
  return !DateTime.now().isBefore(outlet.trialExpiresAt);
}

bool hasAddonAccess({required BuildContext context, required bool hasAddon}) {
  return !shouldEnforceAddonLock(context) || hasAddon;
}
