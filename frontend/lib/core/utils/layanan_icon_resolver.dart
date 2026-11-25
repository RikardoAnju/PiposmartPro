const String layananAssetBasePath = 'assets/images/layanan/';
const String defaultLayananAssetFileName = 'kaos.webp';
const String defaultLayananAssetPath =
    '$layananAssetBasePath$defaultLayananAssetFileName';

const List<String> layananIconAssetNames = [
  'Boneka.webp',
  'Celana.webp',
  'Dress.webp',
  'Handuk.webp',
  'Jas.webp',
  'Kaos Kaki.webp',
  'Karpet.webp',
  'Kemeja.webp',
  'bantal.webp',
  'bed cover.webp',
  'bikini.webp',
  'blouse.webp',
  'express.webp',
  'gaun.webp',
  'hanger.webp',
  'helm.webp',
  'hijab.webp',
  'jaket.webp',
  'kaos.webp',
  'pakaian bayi.webp',
  'parfume.webp',
  'premium.webp',
  'rok.webp',
  'sajadah.webp',
  'selimut.webp',
  'setrika.webp',
  'snikers.webp',
  'sofa.webp',
  'syal.webp',
  'tas.webp',
  'tirai.webp',
];

const Map<String, String> _layananIconAliases = {
  'bedcover': 'bed cover.webp',
  'bed cover': 'bed cover.webp',
  'boneka': 'Boneka.webp',
  'celana': 'Celana.webp',
  'dress': 'Dress.webp',
  'express': 'express.webp',
  'express.png': 'express.webp',
  'ekspres': 'express.webp',
  'gaun': 'gaun.webp',
  'handuk': 'Handuk.webp',
  'hanger': 'hanger.webp',
  'helm': 'helm.webp',
  'hijab': 'hijab.webp',
  'jaket': 'jaket.webp',
  'jas': 'Jas.webp',
  'kaos': 'kaos.webp',
  'kaos kaki': 'Kaos Kaki.webp',
  'karpet': 'Karpet.webp',
  'kemeja': 'Kemeja.webp',
  'kiloan': 'kaos.webp',
  'kiloan.png': 'kaos.webp',
  'kilat': 'express.webp',
  'kilat.png': 'express.webp',
  'layanan': 'kaos.webp',
  'layanan.png': 'kaos.webp',
  'parfum': 'parfume.webp',
  'parfume': 'parfume.webp',
  'premium': 'premium.webp',
  'rok': 'rok.webp',
  'sajadah': 'sajadah.webp',
  'selimut': 'selimut.webp',
  'setrika': 'setrika.webp',
  'sneaker': 'snikers.webp',
  'snikers': 'snikers.webp',
  'sofa': 'sofa.webp',
  'syal': 'syal.webp',
  'tas': 'tas.webp',
  'tirai': 'tirai.webp',
};

const Map<String, String> _layananKeywordMap = {
  'bed cover': 'bed cover.webp',
  'bedcover': 'bed cover.webp',
  'bantal': 'bantal.webp',
  'bayi': 'pakaian bayi.webp',
  'bikini': 'bikini.webp',
  'blouse': 'blouse.webp',
  'boneka': 'Boneka.webp',
  'celana': 'Celana.webp',
  'cuci': 'kaos.webp',
  'dress': 'Dress.webp',
  'ekspres': 'express.webp',
  'express': 'express.webp',
  'gaun': 'gaun.webp',
  'handuk': 'Handuk.webp',
  'hanger': 'hanger.webp',
  'helm': 'helm.webp',
  'hijab': 'hijab.webp',
  'jaket': 'jaket.webp',
  'jas': 'Jas.webp',
  'kaos': 'kaos.webp',
  'kaos kaki': 'Kaos Kaki.webp',
  'karpet': 'Karpet.webp',
  'kemeja': 'Kemeja.webp',
  'kerudung': 'hijab.webp',
  'kiloan': 'kaos.webp',
  'laundry': 'kaos.webp',
  'pakaian bayi': 'pakaian bayi.webp',
  'parfum': 'parfume.webp',
  'parfume': 'parfume.webp',
  'premium': 'premium.webp',
  'rok': 'rok.webp',
  'sajadah': 'sajadah.webp',
  'selimut': 'selimut.webp',
  'sepatu': 'snikers.webp',
  'setrika': 'setrika.webp',
  'sneaker': 'snikers.webp',
  'snikers': 'snikers.webp',
  'sofa': 'sofa.webp',
  'syal': 'syal.webp',
  'tas': 'tas.webp',
  'tirai': 'tirai.webp',
};

final Map<String, String> _layananAssetIndex = () {
  final map = <String, String>{};
  for (final fileName in layananIconAssetNames) {
    final normalized = _normalizeLayananIconKey(fileName);
    map[normalized] = fileName;
    map[_stripExtension(normalized)] = fileName;
  }
  return map;
}();

String _stripExtension(String value) {
  return value.replaceAll(RegExp(r'\.\w+$'), '');
}

String _normalizeLayananIconKey(String value) {
  final fileName = value.trim().replaceAll('\\', '/').split('/').last;
  return fileName
      .toLowerCase()
      .replaceAll('%20', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? resolveLayananIconFileName(String? raw) {
  if (raw == null) return null;
  final normalized = _normalizeLayananIconKey(raw);
  if (normalized.isEmpty) return null;

  final alias =
      _layananIconAliases[normalized] ??
      _layananIconAliases[_stripExtension(normalized)];
  if (alias != null) return alias;

  return _layananAssetIndex[normalized] ??
      _layananAssetIndex[_stripExtension(normalized)];
}

String? tryResolveLayananIconPath(String? raw) {
  if (raw == null) return null;
  final candidate = raw.trim();
  if (candidate.isEmpty) return null;
  if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
    return candidate;
  }

  final fileName = resolveLayananIconFileName(candidate);
  if (fileName == null) return null;
  return '$layananAssetBasePath$fileName';
}

String resolveLayananIconPath(
  String? raw, {
  String categoryName = '',
  String serviceName = '',
  String fallbackFileName = defaultLayananAssetFileName,
}) {
  final resolved = tryResolveLayananIconPath(raw);
  if (resolved != null) return resolved;

  final lookup = '$categoryName $serviceName'.toLowerCase();
  final keywordEntries = _layananKeywordMap.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in keywordEntries) {
    if (lookup.contains(entry.key)) {
      return '$layananAssetBasePath${entry.value}';
    }
  }

  final fallbackFile =
      resolveLayananIconFileName(fallbackFileName) ??
      defaultLayananAssetFileName;
  return '$layananAssetBasePath$fallbackFile';
}
