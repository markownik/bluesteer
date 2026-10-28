import 'dart:io';

import 'package:flutter/services.dart';

/// Android foreground service that keeps the BLE link alive in the background
/// (android/.../LinkService.kt). A no-op elsewhere.
class LinkService {
  static const _channel = MethodChannel('dev.bluesteer/link_service');

  static Future<void> start(String hostName) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('start', {'host': hostName});
    } on PlatformException catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (_) {}
  }
}
