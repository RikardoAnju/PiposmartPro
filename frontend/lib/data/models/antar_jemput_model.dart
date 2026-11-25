class JemputAntarData {
  final bool jemputEnabled;
  final String jemputAlamat;
  final double jemputBiaya;
  final bool antarEnabled;
  final String antarAlamat;
  final double antarBiaya;

  const JemputAntarData({
    this.jemputEnabled = false,
    this.jemputAlamat = '',
    this.jemputBiaya = 0,
    this.antarEnabled = false,
    this.antarAlamat = '',
    this.antarBiaya = 0,
  });

  double get totalBiaya {
    double total = 0;
    if (jemputEnabled) total += jemputBiaya;
    if (antarEnabled) total += antarBiaya;
    return total;
  }

  JemputAntarData copyWith({
    bool? jemputEnabled,
    String? jemputAlamat,
    double? jemputBiaya,
    bool? antarEnabled,
    String? antarAlamat,
    double? antarBiaya,
  }) {
    return JemputAntarData(
      jemputEnabled: jemputEnabled ?? this.jemputEnabled,
      jemputAlamat: jemputAlamat ?? this.jemputAlamat,
      jemputBiaya: jemputBiaya ?? this.jemputBiaya,
      antarEnabled: antarEnabled ?? this.antarEnabled,
      antarAlamat: antarAlamat ?? this.antarAlamat,
      antarBiaya: antarBiaya ?? this.antarBiaya,
    );
  }
}
