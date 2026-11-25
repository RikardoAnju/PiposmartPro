import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import '../events/app_events.dart';

class SocketService {
  IOWebSocketChannel? _channel;
  String? _currentOutletId;
  bool _isManuallyClosed = false;

  /// Inisialisasi Koneksi berdasarkan Outlet yang aktif
  void connect(
    String outletId, {
    Function(bool success, String? error)? onResult,
  }) {
    debugPrint("🔌 Socket: Menjalankan fungsi connect untuk $outletId...");

    if (_currentOutletId == outletId && _channel != null) {
      debugPrint(
        "ℹ️ Socket: Sudah terhubung ke $outletId, mengabaikan duplikasi.",
      );
      return;
    }

    if (_channel != null) {
      debugPrint(
        "🧹 Socket: Membersihkan koneksi lama sebelum memulai yang baru.",
      );
      _closeChannel();
    }

    _isManuallyClosed = false;
    _currentOutletId = outletId;

    const String baseUrl = String.fromEnvironment(
      'WS_BASE_URL',
      // Production scripts override this through dart-define.
      defaultValue: 'wss://api-dev.ayocuci.id/api/v1/ws',
    );
    final Uri url = Uri.parse("$baseUrl?outlet_id=$outletId");

    try {
      debugPrint("🚀 Socket: Memulai jabat tangan (handshake) ke $url");
      _channel = IOWebSocketChannel.connect(url);

      _channel!.stream.listen(
        (message) {
          if (onResult != null) {
            debugPrint("✅ Socket: Stream diterima, koneksi established.");
            onResult?.call(true, null);
            onResult = null;
          }

          _handleMessage(message);
          appEventBus.add(SocketStatusChanged(true));
        },
        onDone: () {
          debugPrint("🔌 Socket: Koneksi terputus (onDone) untuk $outletId");
          _handleDisconnection(outletId);
        },
        onError: (error) {
          final errorMsg = error.toString();
          debugPrint("❌ Socket Error [$outletId]: $errorMsg");
          if (onResult != null) {
            onResult?.call(false, errorMsg);
            onResult = null;
          }
          _handleDisconnection(outletId);
        },
      );
    } catch (e) {
      final catchMsg = e.toString();
      debugPrint("❌ Socket Exception: $catchMsg");
      onResult?.call(false, catchMsg);
      _handleDisconnection(outletId);
    }
  }

  void _handleDisconnection(String outletId) {
    if (_currentOutletId == outletId) {
      _channel = null;
      _currentOutletId = null;
    }

    appEventBus.add(SocketStatusChanged(false));

    if (!_isManuallyClosed) {
      _reconnect(outletId);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      debugPrint("📥 SOCKET INCOMING DATA: $message");
      final data = jsonDecode(message);
      final String type = data['type'] ?? '';
      final payload = data['payload'] ?? {};

      switch (type) {
        // --- KOIN & BILLING ---
        case 'TOPUP_SUCCESS':
          appEventBus.add(
            TopupSucceeded(topupId: payload['topup_id']?.toString()),
          );
          appEventBus.add(CoinBalanceChanged());
          _broadcastSystemNotif(data);
          break;

        case 'COIN_UPDATED':
          appEventBus.add(CoinBalanceChanged());
          _broadcastSystemNotif(data);
          break;

        case 'TOPUP_STATUS_CHANGED':
          appEventBus.add(
            TopupStatusChanged(
              topupId: payload['topup_id'] ?? '',
              status: payload['status'] ?? '',
            ),
          );
          _broadcastSystemNotif(data);
          break;

        // --- [NEW] ADDON & PRO SIGNALS ---
        case 'OUTLET_ACTIVATED':
          debugPrint("🌟 Socket: Outlet Berhasil Jadi PRO!");
          appEventBus.add(
            OutletActivated(outletId: payload['outlet_id'] ?? ''),
          );
          _broadcastSystemNotif(data);
          break;

        case 'ADDON_PAYMENT_STATUS':
          debugPrint("💳 Socket: Status Pembayaran Addon Berubah!");
          appEventBus.add(
            AddonPaymentStatusChanged(
              addonId: payload['id'] ?? '',
              status: payload['status'] ?? '',
            ),
          );
          break;

        case 'ADDON_ACTIVATED':
          debugPrint("🚀 Socket: Fitur Addon Eceran Telah Aktif!");
          appEventBus.add(AddonActivated());
          _broadcastSystemNotif(data);
          break;

        // --- TRANSAKSI & OPERASIONAL ---
        case 'ORDER_UPDATED':
        case 'NEW_ORDER':
          appEventBus.add(OrderStatusChanged());
          break;

        case 'EXPENSE_UPDATED':
          appEventBus.add(ExpenseChanged());
          break;

        case 'DEPOSIT_UPDATED':
          appEventBus.add(
            DepositChanged(
              customerId: payload['customer_id']?.toString() ?? '',
            ),
          );
          break;

        case 'OUTLET_UPDATED':
          appEventBus.add(OutletProfileUpdated());
          appEventBus.add(OutletSwitched());
          break;

        case 'FORCE_LOGOUT':
          final employeeId = payload['employee_id']?.toString().trim() ?? '';
          if (employeeId.isNotEmpty) {
            appEventBus.add(
              ForceLogoutRequested(
                employeeId: employeeId,
                reason:
                    payload['reason']?.toString() ??
                    'Sesi Anda telah diakhiri oleh owner.',
              ),
            );
          }
          break;

        case 'SYSTEM_PROMO':
        case 'SYSTEM_ANNOUNCEMENT':
          _broadcastSystemNotif(data);
          break;

        default:
          debugPrint("❓ Unknown socket message type: $type");
      }
    } catch (e) {
      debugPrint("❌ Failed to parse socket message: $e");
    }
  }

  /// Helper untuk memicu notifikasi sistem di UI
  void _broadcastSystemNotif(Map<String, dynamic> data) {
    appEventBus.add(
      SystemNotificationReceived(
        title: data['title'] ?? 'Notifikasi Sistem',
        message: data['message'] ?? 'Ada pembaruan data.',
        extraData: data['payload'],
      ),
    );
  }

  void _reconnect(String outletId) {
    if (_isManuallyClosed) return;
    debugPrint("🔄 Socket: Menjadwalkan reconnect dalam 5 detik...");
    Timer(const Duration(seconds: 5), () {
      if (!_isManuallyClosed &&
          (_currentOutletId == null || _currentOutletId == outletId)) {
        connect(outletId);
      }
    });
  }

  void _closeChannel() {
    try {
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      debugPrint("⚠️ Error tutup channel: $e");
    }
  }

  void disconnect() {
    _isManuallyClosed = true;
    _closeChannel();
    _currentOutletId = null;
    debugPrint("🔌 Socket: Disconnected manually");
  }
}
