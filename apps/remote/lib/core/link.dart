import 'dart:typed_data';

/// One byte stream each way to a host, however it is carried: BLE in the app,
/// an in-memory pipe in tests.
abstract interface class Link {
  /// Bytes from the host. Closes when the link dies, whatever the reason
  /// (BLE disconnect, a failed write, [close]).
  Stream<Uint8List> get incoming;

  Future<void> write(List<int> bytes);

  Future<void> close();
}

/// Finds hosts and connects to them.
abstract interface class Transport {
  /// Whether the radio is on: the current value first, then every change.
  Stream<bool> get powered;

  /// Connects to the host with this instance id or throws; nothing stays
  /// connected after a failure. [background] says the app is backgrounded on
  /// iOS, where scan results arrive slowly: the transport then also keeps a
  /// direct connect to the last known device pending for the whole window.
  Future<Link> connect(String hostId, {required Duration timeout, bool background = false});
}
