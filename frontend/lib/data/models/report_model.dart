class ReportDashboardModel {
  final SummaryReport summary;
  final List<ChartDataFinance> chartData;

  ReportDashboardModel({required this.summary, required this.chartData});

  factory ReportDashboardModel.fromJson(Map<String, dynamic> json) {
    return ReportDashboardModel(
      summary: SummaryReport.fromJson(json['summary'] ?? {}),
      chartData: (json['chart_data'] as List? ?? [])
          .map((e) => ChartDataFinance.fromJson(e))
          .toList(),
    );
  }
}

class SummaryReport {
  final double totalOmset;
  final double omsetTrend;
  final double totalIncome;
  final double incomeTrend;
  final double totalExpense;
  final double expenseTrend;
  final double profitLoss;
  final double profitLossTrend;
  final int totalTransaksi;
  final double transaksiTrend;
  final int pesananDiambil;
  final double pesananTrend;

  SummaryReport({
    required this.totalOmset,
    required this.omsetTrend,
    required this.totalIncome,
    required this.incomeTrend,
    required this.totalExpense,
    required this.expenseTrend,
    required this.profitLoss,
    required this.profitLossTrend,
    required this.totalTransaksi,
    required this.transaksiTrend,
    required this.pesananDiambil,
    required this.pesananTrend,
  });

  factory SummaryReport.fromJson(Map<String, dynamic> json) {
    return SummaryReport(
      totalOmset: (json['total_omset'] ?? 0).toDouble(),
      omsetTrend: (json['omset_trend'] ?? 0).toDouble(),
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      incomeTrend: (json['income_trend'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      expenseTrend: (json['expense_trend'] ?? 0).toDouble(),
      profitLoss: (json['profit_loss'] ?? 0).toDouble(),
      profitLossTrend: (json['profit_loss_trend'] ?? 0).toDouble(),
      totalTransaksi: json['total_transaksi'] ?? 0,
      transaksiTrend: (json['transaksi_trend'] ?? 0).toDouble(),
      pesananDiambil: json['pesanan_diambil'] ?? 0,
      pesananTrend: (json['pesanan_trend'] ?? 0).toDouble(),
    );
  }
}

class ChartDataFinance {
  final String date;
  final double omset;
  final double income;
  final double expense;
  final int totalOrder;

  ChartDataFinance({
    required this.date,
    required this.omset,
    required this.income,
    required this.expense,
    required this.totalOrder,
  });

  factory ChartDataFinance.fromJson(Map<String, dynamic> json) {
    return ChartDataFinance(
      date: json['date'] ?? "",
      omset: (json['omset'] ?? 0).toDouble(),
      income: (json['income'] ?? 0).toDouble(),
      expense: (json['expense'] ?? 0).toDouble(),
      totalOrder: json['total_order'] ?? 0,
    );
  }
}
