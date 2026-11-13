import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:internet_connection_monitor/internet_connection_monitor.dart';

/// Unico monitor de Internet de la app.
///
/// Vive mientras la app esta abierta, empieza a revisar al crearse y vuelve a
/// revisar cada vez que la app regresa a primer plano.
final internetMonitorProvider = Provider<InternetConnectionMonitor>((ref) {
  final monitor = InternetConnectionMonitor();
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(monitor.check()),
  );
  unawaited(monitor.start());

  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(monitor.dispose());
  });
  return monitor;
});

/// Estado de la conexion: empieza en el ultimo conocido y emite cada cambio.
final internetStatusProvider = StreamProvider<InternetStatus>((ref) async* {
  final monitor = ref.watch(internetMonitorProvider);
  yield monitor.status;
  yield* monitor.changes;
});
