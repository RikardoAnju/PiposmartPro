import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/api_client.dart';
import '../utils/auth_storage.dart';

class LifecycleEventService {
  LifecycleEventService._();

  static final Map<String, DateTime> _recentEvents = {};

  static void track(
    String eventName, {
    Map<String, dynamic> metadata = const {},
    Duration localCooldown = const Duration(minutes: 10),
  }) {
    final now = DateTime.now();
    final previous = _recentEvents[eventName];
    if (previous != null && now.difference(previous) < localCooldown) return;
    _recentEvents[eventName] = now;
    unawaited(_send(eventName, now, metadata));
  }

  static Future<void> _send(
    String eventName,
    DateTime occurredAt,
    Map<String, dynamic> metadata,
  ) async {
    final token = AuthStorage.token;
    if (token == null || token.isEmpty) return;
    final eventID = '${eventName}_${occurredAt.microsecondsSinceEpoch}';
    try {
      await ApiClient.post(
        '/lifecycle/events',
        token: token,
        body: {
          'event_id': eventID,
          'event_name': eventName,
          'occurred_at': occurredAt.toUtc().toIso8601String(),
          'metadata': metadata,
        },
      );
    } catch (error) {
      debugPrint('⚠️ Lifecycle event gagal dikirim: $eventName ($error)');
    }
  }
}
