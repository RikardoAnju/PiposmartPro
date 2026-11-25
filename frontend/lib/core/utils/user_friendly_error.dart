String userFriendlyError(Object? error) {
  final raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) return 'Ada kendala sebentar. Coba lagi ya.';

  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^ClientException:\s*'), '')
      .trim();
  final lower = cleaned.toLowerCase();

  final isNetworkIssue =
      lower.contains('clientsftware') ||
      lower.contains('clientsoftware') ||
      lower.contains('connection abort') ||
      lower.contains('connection aborted') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection timed out') ||
      lower.contains('timeout') ||
      lower.contains('timed out') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('httpsexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('uri=http') ||
      lower.contains('uri=https') ||
      lower.contains('/api/v1/');

  if (isNetworkIssue) {
    return 'Jaringan kurang stabil. Coba lagi sebentar ya.';
  }

  if (lower.contains('format exception') ||
      lower.contains('unexpected character')) {
    return 'Data dari server belum bisa dibaca. Coba lagi ya.';
  }

  if (lower.contains('unauthorized') || lower.contains('401')) {
    return 'Sesi login sudah habis. Silakan masuk lagi ya.';
  }

  if (lower.contains('forbidden') || lower.contains('403')) {
    return 'Akun ini belum punya akses ke data tersebut.';
  }

  if (lower.contains('server') ||
      lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('504')) {
    return 'Server lagi sibuk. Coba lagi sebentar ya.';
  }

  return cleaned;
}
