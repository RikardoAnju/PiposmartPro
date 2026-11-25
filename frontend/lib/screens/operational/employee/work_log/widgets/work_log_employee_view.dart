import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/providers/work_log_provider.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_activity_card.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_badge.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/widgets/work_log_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:intl/intl.dart';

class WorkLogEmployeeView extends StatelessWidget {
  const WorkLogEmployeeView({super.key, required this.workLog});

  final WorkLogProvider workLog;

  @override
  Widget build(BuildContext context) {
    final employee = workLog.selectedEmployee!;
    final transactionCount = workLog.transactionCount;
    final customerCount = workLog.customerCount;
    final serviceCount = workLog.serviceCount;
    final newCount = workLog.newOrderCount;
    final processingCount = workLog.processingCount;
    final readyCount = workLog.readyCount;
    final completeCount = workLog.completedCount;
    final cancelledCount = workLog.cancelledCount;
    final rangeLabel =
        '${DateFormat('d', 'id_ID').format(workLog.selectedRange.start)}–'
        '${DateFormat('d MMM yyyy', 'id_ID').format(workLog.selectedRange.end)}';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        28 + MediaQuery.paddingOf(context).bottom + 16,
      ),
      children: [
        _EmployeeHeader(employee: employee),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: AppBorders.card,
            boxShadow: AppShadows.cardSoft,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RINGKASAN KERJA',
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontSize: 12,
                            letterSpacing: .7,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Aktivitas pada periode terpilih',
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Material(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => workLog.pickRange(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: AppPalette.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  rangeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.primary,
                                    fontSize: 11,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_outlined,
                      size: 16,
                      color: AppPalette.muted,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Include pesanan Batal',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: !workLog.excludeCancelled,
                      onChanged: (includeCancelled) {
                        workLog.setExcludeCancelled(!includeCancelled);
                      },
                      activeColor: AppPalette.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
                mainAxisExtent: 82,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  WorkLogStatCard(
                    icon: Icons.person_rounded,
                    label: 'Pelanggan',
                    value: '$customerCount',
                    color: AppPalette.primary,
                  ),
                  WorkLogStatCard(
                    icon: Icons.receipt_long_rounded,
                    label: 'Pesanan',
                    value: '$transactionCount',
                    color: AppPalette.info,
                  ),
                  WorkLogStatCard(
                    icon: Icons.local_laundry_service_rounded,
                    label: 'Layanan',
                    value: '$serviceCount',
                    color: AppPalette.success,
                  ),
                ],
              ),
              if (workLog.totalQuantities.isNotEmpty) ...[
                const SizedBox(height: 4),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: _EmployeeQuantitySummary(
                    quantities: workLog.totalQuantities,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'AKTIVITAS BERDASARKAN TAHAPAN',
          style: TextStyle(
            color: AppPalette.muted,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: AppFont.w800,
          ),
        ),
        const SizedBox(height: 9),
        WorkLogActivityCard(
          assetPath: AppImages.icAntrian,
          title: 'Cucian Baru',
          subtitle: 'Antrian → Proses',
          count: newCount,
          color: AppPalette.primary,
          onTap: () => workLog.selectStage(WorkLogStage.newOrder),
        ),
        WorkLogActivityCard(
          assetPath: AppImages.icProses,
          title: 'Cucian Dikerjakan',
          subtitle: 'Proses pencucian',
          count: processingCount,
          color: AppPalette.info,
          onTap: () => workLog.selectStage(WorkLogStage.processing),
        ),
        WorkLogActivityCard(
          assetPath: AppImages.icSiapAmbil,
          title: 'Pesanan Siap Ambil',
          subtitle: 'Siap diambil pelanggan',
          count: readyCount,
          color: AppPalette.warning,
          onTap: () => workLog.selectStage(WorkLogStage.ready),
        ),
        WorkLogActivityCard(
          assetPath: AppImages.icSelesai,
          title: 'Menyelesaikan Pesanan',
          subtitle: 'Pesanan sudah diambil',
          count: completeCount,
          color: AppPalette.success,
          onTap: () => workLog.selectStage(WorkLogStage.completed),
        ),
        const SizedBox(height: 13),
        const Text(
          'AKTIVITAS LAINNYA',
          style: TextStyle(
            color: AppPalette.muted,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: AppFont.w800,
          ),
        ),
        const SizedBox(height: 9),
        WorkLogActivityCard(
          assetPath: AppImages.icBatal,
          title: 'Membatalkan Pesanan',
          subtitle: 'Pesanan dibatalkan',
          count: cancelledCount,
          color: AppPalette.danger,
          showDivider: false,
          onTap: () => workLog.selectStage(WorkLogStage.cancelled),
        ),
      ],
    );
  }
}

class _EmployeeQuantitySummary extends StatelessWidget {
  const _EmployeeQuantitySummary({required this.quantities});

  final Map<String, double> quantities;

  @override
  Widget build(BuildContext context) {
    final normalizedQuantities = <String, double>{
      'kg': 0,
      'pcs': 0,
      'meter': 0,
    };
    for (final entry in quantities.entries) {
      final raw = entry.key.trim().toLowerCase();
      final unit = switch (raw) {
        'm' || 'meter' || 'meteran' || 'meter persegi' || 'm²' => 'meter',
        'kg' || 'kilogram' => 'kg',
        'pc' || 'pcs' || 'piece' => 'pcs',
        _ => raw.isEmpty ? 'pcs' : raw,
      };
      normalizedQuantities[unit] =
          (normalizedQuantities[unit] ?? 0) + entry.value;
    }

    Color unitColor(String unit) {
      switch (unit.toLowerCase()) {
        case 'kg':
        case 'kilogram':
          return const Color(0xFF8B5CF6);
        case 'm':
        case 'meter':
        case 'meteran':
          return const Color(0xFFF59E0B);
        case 'pcs':
        case 'pc':
          return const Color(0xFF06B6D4);
        default:
          return AppPalette.info;
      }
    }

    IconData unitIcon(String unit) {
      switch (unit.toLowerCase()) {
        case 'kg':
        case 'kilogram':
          return Icons.scale_rounded;
        case 'm':
        case 'meter':
        case 'meteran':
          return Icons.straighten_rounded;
        case 'pcs':
        case 'pc':
          return Icons.checkroom_rounded;
        default:
          return Icons.inventory_2_rounded;
      }
    }

    String unitLabel(String unit) {
      switch (unit.toLowerCase()) {
        case 'kg':
        case 'kilogram':
          return 'Kilogram';
        case 'm':
        case 'meter':
        case 'meteran':
          return 'Meter';
        case 'pcs':
        case 'pc':
          return 'Pcs';
        default:
          return unit;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: normalizedQuantities.entries.toList().asMap().entries.map((indexed) {
          final entry = indexed.value;
          final index = indexed.key;
          final value = entry.value % 1 == 0
              ? entry.value.toInt().toString()
              : entry.value.toStringAsFixed(1);

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < normalizedQuantities.length - 1 ? 10 : 0,
              ),
              child: AspectRatio(
                aspectRatio: 1.18,
                child: WorkLogStatCard(
                  icon: unitIcon(entry.key),
                  label: unitLabel(entry.key),
                  value: value,
                  color: unitColor(entry.key),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({required this.employee});

  final Pegawai employee;

  @override
  Widget build(BuildContext context) {
    final role = employee.role?.nama.toUpperCase() ?? 'KARYAWAN';
    final type = employee.type == 'base' ? 'PEGAWAI DASAR' : 'PEGAWAI ADD-ON';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: AppBorders.card,
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 21,
            backgroundColor: AppPalette.primarySoft,
            child: Icon(Icons.person_rounded, color: AppPalette.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.nama.toUpperCase(),
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 12,
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 5,
                  children: [
                    WorkLogBadge(label: role),
                    WorkLogBadge(label: type),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
