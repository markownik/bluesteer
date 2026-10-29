import 'dart:async';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:bluesteer_remote/core/link.dart';

/// An in-memory link whose far end is a Mac: a `SecureChannel.host` that
/// answers `RemoteHello` with `HostHello` and pings with pongs.
class FakeLink implements Link {
  FakeLink(this.name, {required this.hostKey, required this.pairedKeys});
  final String name;
  final NoiseKeyPair hostKey;
  final Set<String> pairedKeys;
  final _toRemote = StreamController<Uint8List>();
  SecureChannel? _mac;
  bool _first = true;
  bool closed = false;
  bool failNextWrite = false;
  int writes = 0;

  @override
  Stream<Uint8List> get incoming => _toRemote.stream;

  @override
  Future<void> write(List<int> bytes) async {
    writes++;
    if (closed) throw StateError('link closed');
    if (failNextWrite) {
      failNextWrite = false;
      await close();
      throw StateError('write failed');
    }
    if (_first) {
      _first = false;
      bytes = bytes.sublist(1); // the selector byte (SPEC.md §2.0)
      _mac = await SecureChannel.host(staticKey: hostKey, pairedKeys: pairedKeys);
    }
    final mac = _mac!;
    for (final event in await mac.receive(bytes)) {
      switch (event) {
        case SendEvent(:final bytes):
          _toRemote.add(bytes);
        case EstablishedEvent():
          break;
        case MessageEvent(:final plaintext):
          final e = Envelope.fromBuffer(plaintext);
          if (e.hasRemoteHello()) {
            _toRemote.add(await mac.encrypt(
                (Envelope()..hostHello = (HostHello()..hostName = name..protocolVersion = protocolVersion)).writeToBuffer()));
          }
          if (e.hasPing()) {
            _toRemote.add(await mac.encrypt((Envelope()..pong = (Pong()..nonce = e.ping.nonce)).writeToBuffer()));
          }
      }
    }
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _toRemote.close(); // not awaited: it completes only once a listener saw "done"
  }
}

/// Connect attempts are completed by the test; `powered` is driven by [power].
class FakeTransport implements Transport {
  FakeTransport({this.initiallyOn = true});
  final bool initiallyOn;
  final power = StreamController<bool>.broadcast();
  final attempts = <Completer<Link>>[];
  final timeouts = <Duration>[];
  final backgrounds = <bool>[];

  @override
  Stream<bool> get powered async* {
    yield initiallyOn;
    yield* power.stream;
  }

  /// Like the real transport, a link that turns up after the window is closed.
  @override
  Future<Link> connect(String hostId, {required Duration timeout, bool background = false}) {
    final c = Completer<Link>();
    attempts.add(c);
    timeouts.add(timeout);
    backgrounds.add(background);
    return c.future.timeout(timeout, onTimeout: () {
      c.future.then((link) => link.close());
      throw TimeoutException('scan window over', timeout);
    });
  }
}

