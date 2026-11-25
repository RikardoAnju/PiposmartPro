abstract final class FeatureFlags {
  static const bool nobuQrisEnabled = bool.fromEnvironment(
    'NOBU_QRIS_ENABLED',
    defaultValue: false,
  );
}
