import 'package:flutter/material.dart';

import 'package:ayocucinew/shared/widgets/ceremonial_success_screen.dart';

enum AddonSuccessKind { firstActivation, renewed, updated }

class AddonSuccessScreen extends StatelessWidget {
  const AddonSuccessScreen({
    super.key,
    required this.kind,
    required this.onPrimary,
    this.featureName,
    this.featureId,
    this.featureNames,
  });

  final AddonSuccessKind kind;
  final VoidCallback onPrimary;
  final String? featureName;
  final String? featureId;
  final List<String>? featureNames;

  bool get _hasBulkFeatures =>
      featureNames != null &&
      featureNames!.where((e) => e.trim().isNotEmpty).length > 1;

  List<String> get _resolvedFeatureNames {
    final names = <String>[
      if (featureName != null && featureName!.trim().isNotEmpty)
        featureName!.trim(),
      ...?featureNames,
    ];
    final cleaned = names.where((e) => e.trim().isNotEmpty).toSet().toList();
    return cleaned;
  }

  String _mascotAsset() {
    return switch (kind) {
      AddonSuccessKind.firstActivation => 'assets/maskot/1 501.webp',
      AddonSuccessKind.renewed => 'assets/maskot/4 1.webp',
      AddonSuccessKind.updated => 'assets/maskot/3 1.webp',
    };
  }

  ({String title, List<CelebrationChipData> chips}) _featureVariant() {
    final feature = featureName?.toLowerCase() ?? '';
    final id = featureId?.toUpperCase() ?? '';
    final bulkNames = _resolvedFeatureNames;

    if (bulkNames.length > 1) {
      return (
        title: '${bulkNames.length} Fitur Aktif',
        chips: [
          ...bulkNames.map(
            (name) => CelebrationChipData(
              icon: Icons.check_circle_rounded,
              text: name.trim(),
            ),
          ),
        ],
      );
    }

    if (id == 'AD-001') {
      return (
        title: 'Fitur Pegawai',
        chips: const [
          CelebrationChipData(icon: Icons.people_alt_rounded, text: 'Pegawai'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.bolt_rounded, text: 'Siap Pakai'),
        ],
      );
    }
    if (id == 'AD-002') {
      return (
        title: 'Laporan Laba Rugi',
        chips: const [
          CelebrationChipData(icon: Icons.query_stats_rounded, text: 'Profit'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.insights_rounded, text: 'Report'),
        ],
      );
    }
    if (id == 'AD-003') {
      return (
        title: 'Laporan Piutang',
        chips: const [
          CelebrationChipData(
            icon: Icons.receipt_long_rounded,
            text: 'Piutang',
          ),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(
            icon: Icons.monitor_heart_rounded,
            text: 'Pantau',
          ),
        ],
      );
    }
    if (id == 'AD-004') {
      return (
        title: 'Ringkasan Per Layanan',
        chips: const [
          CelebrationChipData(icon: Icons.view_list_rounded, text: 'Layanan'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.bar_chart_rounded, text: 'Summary'),
        ],
      );
    }
    if (id == 'AD-005') {
      return (
        title: 'Analisa Pertumbuhan Pelanggan',
        chips: const [
          CelebrationChipData(icon: Icons.groups_rounded, text: 'Pelanggan'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.analytics_rounded, text: 'Growth'),
        ],
      );
    }

    if (feature.contains('pegawai') || feature.contains('karyawan')) {
      return (
        title: 'Fitur Pegawai',
        chips: const [
          CelebrationChipData(icon: Icons.people_alt_rounded, text: 'Pegawai'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.bolt_rounded, text: 'Siap Pakai'),
        ],
      );
    }
    if (feature.contains('service summary') ||
        feature.contains('ringkasan') ||
        feature.contains('layanan')) {
      return (
        title: 'Ringkasan Per Layanan',
        chips: const [
          CelebrationChipData(icon: Icons.view_list_rounded, text: 'Layanan'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.bar_chart_rounded, text: 'Summary'),
        ],
      );
    }
    if (feature.contains('piutang') || feature.contains('debt')) {
      return (
        title: 'Laporan Piutang',
        chips: const [
          CelebrationChipData(
            icon: Icons.receipt_long_rounded,
            text: 'Piutang',
          ),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(
            icon: Icons.monitor_heart_rounded,
            text: 'Pantau',
          ),
        ],
      );
    }
    if (feature.contains('laba rugi') ||
        feature.contains('profit') ||
        feature.contains('loss')) {
      return (
        title: 'Laporan Laba Rugi',
        chips: const [
          CelebrationChipData(icon: Icons.query_stats_rounded, text: 'Profit'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.insights_rounded, text: 'Report'),
        ],
      );
    }
    if (feature.contains('pertumbuhan pelanggan') ||
        feature.contains('customer growth')) {
      return (
        title: 'Analisa Pertumbuhan Pelanggan',
        chips: const [
          CelebrationChipData(icon: Icons.groups_rounded, text: 'Pelanggan'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.analytics_rounded, text: 'Growth'),
        ],
      );
    }
    if (feature.contains('pelanggan') || feature.contains('customer')) {
      return (
        title: 'Fitur Pelanggan',
        chips: const [
          CelebrationChipData(icon: Icons.groups_rounded, text: 'Pelanggan'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.auto_awesome_rounded, text: 'Baru'),
        ],
      );
    }
    if (feature.contains('laporan') || feature.contains('keuangan')) {
      return (
        title: 'Fitur Laporan',
        chips: const [
          CelebrationChipData(icon: Icons.insights_rounded, text: 'Laporan'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.tune_rounded, text: 'Analitik'),
        ],
      );
    }
    if (feature.contains('whatsapp')) {
      return (
        title: 'Fitur WhatsApp',
        chips: const [
          CelebrationChipData(icon: Icons.chat_rounded, text: 'WhatsApp'),
          CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
          CelebrationChipData(icon: Icons.send_rounded, text: 'Broadcast'),
        ],
      );
    }

    return (
      title: 'Fitur Aktif',
      chips: const [
        CelebrationChipData(icon: Icons.check_circle_rounded, text: 'Aktif'),
        CelebrationChipData(icon: Icons.auto_awesome_rounded, text: 'Baru'),
        CelebrationChipData(icon: Icons.bolt_rounded, text: 'Siap Pakai'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = _featureVariant();
    final config = switch (kind) {
      AddonSuccessKind.firstActivation => (
        badge: 'Fitur Baru Aktif',
        title: variant.title,
        subtitle: _hasBulkFeatures
            ? 'Beberapa add-on sudah aktif.'
            : 'Fitur baru siap dipakai.',
        chips: variant.chips,
      ),
      AddonSuccessKind.renewed => (
        badge: 'Add-on Diperpanjang',
        title: _hasBulkFeatures ? variant.title : '${variant.title} Baru',
        subtitle: _hasBulkFeatures
            ? 'Beberapa add-on sudah diperpanjang.'
            : 'Add-on tetap aktif.',
        chips: [
          CelebrationChipData(
            icon: Icons.refresh_rounded,
            text: 'Diperpanjang',
          ),
          ...variant.chips.take(2),
        ],
      ),
      AddonSuccessKind.updated => (
        badge: 'Fitur Diperbarui',
        title: variant.title,
        subtitle: _hasBulkFeatures
            ? 'Semua perubahan sudah aktif.'
            : 'Perubahan sudah aktif.',
        chips: [
          CelebrationChipData(icon: Icons.tune_rounded, text: 'Update'),
          ...variant.chips.take(2),
        ],
      ),
    };

    return CeremonialSuccessScreen(
      badge: config.badge,
      title: config.title,
      subtitle: _hasBulkFeatures
          ? 'Beberapa add-on sudah aktif.'
          : config.subtitle,
      primaryLabel: _hasBulkFeatures
          ? 'Lihat Semua Add-on'
          : 'Lihat Fitur Aktif',
      onPrimary: onPrimary,
      chips: config.chips,
      chipsVertical: _hasBulkFeatures,
      mascotAsset: _mascotAsset(),
      soundAsset: 'assets/sounds/success_bright_3.wav',
    );
  }
}
