// lib/main.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'package:ayocucinew/core/service/fcm_service.dart';
import 'package:ayocucinew/core/service/notification_navigation_service.dart';
import 'package:ayocucinew/core/utils/app_image_cache.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/app_providers.dart';
import 'package:ayocucinew/app_router.dart';
import 'package:ayocucinew/app_links_handler.dart';
import 'package:ayocucinew/core/theme/app_theme.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppImageCache.configureGlobalImageCache();

  // Raw `flutter run --flavor dev` should use development by default.
  // Production scripts override this through dart-define.
  const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  debugPrint('🌎 ENV=$env | API=${ApiClient.baseUrl}');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await _bootstrapServices();

  final authProvider = AuthProvider();
  runApp(AppProviders.build(authProvider: authProvider, child: const MyApp()));
}

Future<void> _bootstrapServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase Initialized with Options');
  } catch (e) {
    debugPrint('❌ Firebase Error: $e');
  }

  await initializeDateFormatting('id_ID', null);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final NavigatorObserver _notificationObserver;
  late final AppLinksHandler _linksHandler;
  StreamSubscription<AppEvent>? _appEventSubscription;

  @override
  void initState() {
    super.initState();
    _notificationObserver = NotificationNavigationService.observer;
    _linksHandler = AppLinksHandler(navigatorKey: _navigatorKey);
    _linksHandler.init();
    FCMService.configureNavigation(_navigatorKey);
    _appEventSubscription = appEventBus.stream.listen(_handleAppEvent);
    unawaited(FCMService.init());
    unawaited(FCMService.handleInitialMessage());
  }

  @override
  void dispose() {
    _appEventSubscription?.cancel();
    _linksHandler.dispose();
    super.dispose();
  }

  Future<void> _handleAppEvent(AppEvent event) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    final auth = navigator.context.read<AuthProvider>();

    late final String reason;
    if (event is ForceLogoutRequested) {
      if (auth.actorType == 'user' || auth.actorId != event.employeeId) return;
      reason = event.reason;
    } else if (event is SessionForceLogoutRequested) {
      reason = event.reason;
    } else {
      return;
    }

    navigator.context.read<AppProvider>().logout();
    await auth.logout();
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      CustomToast.show(
        context,
        message: reason,
        isError: true,
        icon: Icons.logout_rounded,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_notificationObserver],
      title: 'Ayo Cuci',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID')],
      locale: const Locale('id', 'ID'),
      theme: AppTheme.light,
      // Skala teks global:
      // 1) Clamp skala font OS agar tidak overflow saat user membesarkan font.
      // 2) Faktor per-platform: Android merender teks sedikit lebih besar/berat
      //    dibanding iOS pada nilai yang sama, jadi dikecilkan sedikit di Android
      //    agar tampilan seimbang di kedua platform. Satu tuas untuk seluruh app.
      builder: (context, child) {
        final mqData = MediaQuery.of(context);
        final double osFactor = mqData.textScaler
            .scale(1.0)
            .clamp(1.0, 1.15)
            .toDouble();
        final double platformBase = AppFont.sizeFactor;
        return MediaQuery(
          data: mqData.copyWith(
            textScaler: TextScaler.linear(osFactor * platformBase),
          ),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
