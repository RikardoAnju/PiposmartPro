import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/status_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class FilterDateBottomSheet extends StatefulWidget {
  final String currentStatus;
  final Function(List<String>) onSelectAll;
  final VoidCallback onEnableSelection;
  final bool showSelectionOptions;

  const FilterDateBottomSheet({
    super.key,
    required this.currentStatus,
    required this.onSelectAll,
    required this.onEnableSelection,
    this.showSelectionOptions = true,
  });

  @override
  State<FilterDateBottomSheet> createState() => _FilterDateBottomSheetState();
}

class _FilterDateBottomSheetState extends State<FilterDateBottomSheet> {
  String? _selectedLabel;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final prov = context.read<StatusProvider>();
    _startDate = prov.startDate != null
        ? DateTime.parse(prov.startDate!)
        : null;
    _endDate = prov.endDate != null ? DateTime.parse(prov.endDate!) : null;
    _selectedLabel = prov.filterLabel;
  }

  void _setQuickFilter(String label, int days) {
    setState(() {
      _selectedLabel = label;
      final now = DateTime.now();
      _endDate = now;
      if (label == "Kemarin") {
        _startDate = now.subtract(const Duration(days: 1));
        _endDate = now.subtract(const Duration(days: 1));
      } else {
        _startDate = now.subtract(Duration(days: days));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<StatusProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        // SafeArea memastikan konten tidak tertutup navigasi sistem
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 15),
            // Handle Bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Filter Tanggal",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Pilihan Cepat",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _filterButton("Hari Ini", 0, context),
                        _filterButton("Kemarin", 1, context),
                        _filterButton("Minggu Ini", 7, context),
                        _filterButton("Bulan Ini", 30, context),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Pilih Rentang Tanggal",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _datePickerField(
                            "Tanggal Mulai",
                            _startDate,
                            (d) => setState(() {
                              _startDate = d;
                              _selectedLabel = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _datePickerField(
                            "Tanggal Akhir",
                            _endDate,
                            (d) => setState(() {
                              _endDate = d;
                              _selectedLabel = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Urutkan berdasarkan",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _choiceButton(
                            "Terlama",
                            prov.orderBy == "oldest",
                            () {
                              final fmt = DateFormat('yyyy-MM-dd');
                              prov.setDateFilter(
                                order: "oldest",
                                start: _startDate != null
                                    ? fmt.format(_startDate!)
                                    : null,
                                end: _endDate != null
                                    ? fmt.format(_endDate!)
                                    : null,
                                label: prov.filterLabel,
                              );
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _choiceButton(
                            "Terbaru",
                            prov.orderBy == "newest",
                            () {
                              final fmt = DateFormat('yyyy-MM-dd');
                              prov.setDateFilter(
                                order: "newest",
                                start: _startDate != null
                                    ? fmt.format(_startDate!)
                                    : null,
                                end: _endDate != null
                                    ? fmt.format(_endDate!)
                                    : null,
                                label: prov.filterLabel,
                              );
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (widget.showSelectionOptions) ...[
                      const SizedBox(height: 24),
                      const Text(
                        "Edit Pilihan",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _choiceButton("Pilih satu", false, () {
                              Navigator.pop(context);
                              widget.onEnableSelection();
                            }),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _choiceButton("Pilih Semua", false, () {
                              final ids = prov.getAllIdsInStatus(
                                widget.currentStatus,
                              );
                              widget.onSelectAll(ids);
                              Navigator.pop(context);
                            }),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              prov.setDateFilter(
                                start: null,
                                end: null,
                                label: "Semua Waktu",
                                order: "oldest",
                              );
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Reset",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_startDate != null && _endDate != null) {
                                final fmtApi = DateFormat('yyyy-MM-dd');
                                final fmtDisplay = DateFormat('dd/MM/yyyy');
                                String finalLabel =
                                    _selectedLabel ??
                                    "${fmtDisplay.format(_startDate!)} - ${fmtDisplay.format(_endDate!)}";
                                prov.setDateFilter(
                                  start: fmtApi.format(_startDate!),
                                  end: fmtApi.format(_endDate!),
                                  label: finalLabel,
                                  order: prov.orderBy,
                                );
                                Navigator.pop(context);
                              } else {
                                CustomToast.show(
                                  context,
                                  message: "Pilih rentang tanggal",
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Terapkan",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Padding tambahan di dalam scrollview agar tombol tidak menempel SafeArea
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppPalette.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppPalette.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppPalette.primary : Colors.black,
            fontSize: 13,
            fontWeight: isActive ? AppFont.w900 : AppFont.w600,
          ),
        ),
      ),
    );
  }

  Widget _filterButton(String label, int days, BuildContext context) {
    bool isActive = _selectedLabel == label;
    double width = (MediaQuery.of(context).size.width - 68) / 2;
    return GestureDetector(
      onTap: () => _setQuickFilter(label, days),
      child: Container(
        width: width,
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppPalette.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppPalette.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppPalette.primary : Colors.black,
            fontWeight: isActive ? AppFont.w900 : AppFont.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _datePickerField(
    String label,
    DateTime? value,
    Function(DateTime) onPick,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: AppFont.w700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              initialDate: value ?? DateTime.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppPalette.primary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    value == null
                        ? "dd/mm/yyyy"
                        : DateFormat('dd/MM/yyyy').format(value),
                    style: TextStyle(
                      color: value == null ? Colors.grey : Colors.black,
                      fontSize: 12,
                      fontWeight: AppFont.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
