String formatTrendLabel(double trend, {int decimalDigits = 1}) {
  if (!trend.isFinite) return '—';
  if (trend == 0) return 'Tetap';
  if (trend.abs() >= 1000) {
    return trend > 0 ? 'Naik tajam' : 'Turun tajam';
  }
  return '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(decimalDigits)}%';
}
