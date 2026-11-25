// File: lib/core/events/app_events.dart
import 'dart:async';

/// Base Class untuk semua event di aplikasi
abstract class AppEvent {}

// --- EVENT TRANSAKSI & OPERASIONAL ---
class OrderStatusChanged extends AppEvent {}

class OutletSwitched extends AppEvent {}

class AppDataReady extends AppEvent {}

class ExpenseChanged extends AppEvent {}

class CoinBalanceChanged extends AppEvent {}

class TopupSucceeded extends AppEvent {
  final String? topupId;
  TopupSucceeded({this.topupId});
}

// --- [NEW] EVENT ADDON & AKTIVASI PRO ---

/// Dipicu saat outlet berhasil diaktivasi menjadi PRO (Permanen)
class OutletActivated extends AppEvent {
  final String outletId;
  OutletActivated({required this.outletId});
}

/// Dipicu saat status pembayaran addon berubah (PENDING -> SUCCESS/FAILED)
class AddonPaymentStatusChanged extends AppEvent {
  final String addonId;
  final String status;
  AddonPaymentStatusChanged({required this.addonId, required this.status});
}

/// Dipicu saat ada addon baru yang aktif (Eceran)
class AddonActivated extends AppEvent {}

// --- EVENT DATA MASTER ---
class ServiceDataChanged extends AppEvent {}

class CustomerDataChanged extends AppEvent {}

class DepositChanged extends AppEvent {
  final String customerId;
  DepositChanged({required this.customerId});
}

class InventoryDataChanged extends AppEvent {}

// --- EVENT DEVICE & SETTING ---
class OutletProfileUpdated extends AppEvent {}

class PrintSettingChanged extends AppEvent {}

// --- EVENT SISTEM & REAL-TIME ---
class SystemNotificationReceived extends AppEvent {
  final String title;
  final String message;
  final Map<String, dynamic>? extraData;

  SystemNotificationReceived({
    required this.title,
    required this.message,
    this.extraData,
  });
}

class SocketStatusChanged extends AppEvent {
  final bool isConnected;
  SocketStatusChanged(this.isConnected);
}

class TopupStatusChanged extends AppEvent {
  final String topupId;
  final String status;
  TopupStatusChanged({required this.topupId, required this.status});
}

class StaffActivityChanged extends AppEvent {}

class ForceLogoutRequested extends AppEvent {
  final String employeeId;
  final String reason;

  ForceLogoutRequested({required this.employeeId, required this.reason});
}

/// Fallback otoritatif dari API ketika sesi sudah dicabut di server. Tidak
/// bergantung pada koneksi WebSocket.
class SessionForceLogoutRequested extends AppEvent {
  final String reason;

  SessionForceLogoutRequested({required this.reason});
}

/// Bus Utama
final StreamController<AppEvent> appEventBus =
    StreamController<AppEvent>.broadcast();
