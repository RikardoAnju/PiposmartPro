class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
    required this.raw,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;
  final String raw;

  static AppVersion? tryParse(String? input) {
    final value = input?.trim();
    if (value == null || value.isEmpty) return null;

    final normalized = value.startsWith('v') || value.startsWith('V')
        ? value.substring(1)
        : value;
    final parts = normalized.split('+');
    final semantic = parts.first.split('.');

    int parseSegment(int index) {
      if (index >= semantic.length) return 0;
      return int.tryParse(semantic[index]) ?? 0;
    }

    return AppVersion(
      major: parseSegment(0),
      minor: parseSegment(1),
      patch: parseSegment(2),
      build: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      raw: value,
    );
  }

  String get normalizedLabel =>
      build > 0 ? '$major.$minor.$patch+$build' : '$major.$minor.$patch';

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }
}
