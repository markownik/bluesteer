// Demo mode: the app runs against a scripted Mac that lives in this file, so
// the store screenshots (integration_test/screenshots_test.dart) show real
// screens with neutral content and need no host, no Bluetooth and no camera.
// Enabled with `--dart-define=BLUESTEER_DEMO=true`; a normal build tree-shakes it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:fixnum/fixnum.dart';

import '../core/identity.dart';
import '../core/link.dart';

const demoMode = bool.fromEnvironment('BLUESTEER_DEMO');

/// Paired Macs shown on the hosts page, by host id.
const demoHosts = {'demo-macbook': 'MacBook Pro', 'demo-mini': 'Mac mini'};

final _hostKeys = <String, Future<NoiseKeyPair>>{};

Future<NoiseKeyPair> _hostKey(String hostId) => _hostKeys.putIfAbsent(hostId, NoiseKeyPair.generate);

/// A fresh remote identity with both demo Macs already paired.
Future<Identity> demoIdentity() async {
  final hosts = <PairedHost>[];
  for (final e in demoHosts.entries) {
    hosts.add(PairedHost(id: e.key, name: e.value, hostKey: (await _hostKey(e.key)).publicKey));
  }
  return Identity.inMemory(keyPair: await NoiseKeyPair.generate(), deviceName: Platform.isIOS ? 'iPhone' : 'Android phone', hosts: hosts);
}

/// Connects to a [DemoMac] instead of scanning.
class DemoTransport implements Transport {
  DemoTransport(this.identity);
  final Identity identity;

  @override
  Stream<bool> get powered => Stream<bool>.multi((c) => c.add(true));

  @override
  Future<Link> connect(String hostId, {required Duration timeout, bool background = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return DemoMac(hostId, pairedKeys: {SecureChannel.keyId(identity.keyPair.publicKey)});
  }
}

/// One in-memory link whose far end behaves like BlueSteer Host: Noise XX
/// handshake, hellos, a fixed list of terminals and a scripted Claude Code
/// screen for the first one (SPEC.md §4).
class DemoMac implements Link {
  DemoMac(this.hostId, {required this.pairedKeys, this.acceptUnknown = false});
  final String hostId;
  final Set<String> pairedKeys;
  final bool acceptUnknown;
  final _toRemote = StreamController<Uint8List>();
  SecureChannel? _mac;
  bool _first = true;
  bool _closed = false;
  Int64 _seq = Int64.ZERO;

  static final _sessions = <String, SessionState>{
    'demo-1': SessionState()
      ..sessionId = 'demo-1'
      ..source = SessionSource.SESSION_SOURCE_WRAPPED
      ..command = 'claude'
      ..title = 'Claude Code'
      ..cwd = '~/Projects/app'
      ..status = SessionStatus.SESSION_STATUS_WAITING_PERMISSION,
    'demo-2': SessionState()
      ..sessionId = 'demo-2'
      ..source = SessionSource.SESSION_SOURCE_HOST_SPAWNED
      ..command = 'copilot'
      ..cwd = '~/Projects/api'
      ..status = SessionStatus.SESSION_STATUS_IDLE,
    'demo-3': SessionState()
      ..sessionId = 'demo-3'
      ..source = SessionSource.SESSION_SOURCE_HOST_SPAWNED
      ..command = '/bin/zsh'
      ..cwd = '~'
      ..status = SessionStatus.SESSION_STATUS_IDLE,
  };

  @override
  Stream<Uint8List> get incoming => _toRemote.stream;

  @override
  Future<void> write(List<int> bytes) async {
    if (_closed) throw StateError('link closed');
    if (_first) {
      _first = false;
      bytes = bytes.sublist(1); // the selector byte (SPEC.md §2.0)
      _mac = await SecureChannel.host(staticKey: await _hostKey(hostId), pairedKeys: pairedKeys, acceptUnknownRemote: acceptUnknown);
    }
    for (final event in await _mac!.receive(bytes)) {
      switch (event) {
        case SendEvent(:final bytes):
          _toRemote.add(bytes);
        case EstablishedEvent():
          break;
        case MessageEvent(:final plaintext):
          await _handle(Envelope.fromBuffer(plaintext));
      }
    }
  }

  Future<void> _send(Envelope e) async {
    if (_closed) return;
    _toRemote.add(await _mac!.encrypt(e.writeToBuffer()));
  }

  Future<void> _ack(Int64 cmdId, {String sessionId = ''}) =>
      _send(Envelope()..ack = (Ack()..cmdId = cmdId..ok = true..sessionId = sessionId));

  Future<void> _handle(Envelope e) async {
    if (e.hasRemoteHello() || e.hasPairConfirm()) {
      await _send(Envelope()
        ..hostHello = (HostHello()
          ..protocolVersion = protocolVersion
          ..hostName = demoHosts[hostId] ?? 'Mac'
          ..hostVersion = '1.0.0'));
    } else if (e.hasPing()) {
      await _send(Envelope()..pong = (Pong()..nonce = e.ping.nonce));
    } else if (e.hasListSessions()) {
      await _send(Envelope()..sessionList = (SessionList()..sessions.addAll(_sessions.values)));
      await _ack(e.listSessions.cmdId);
    } else if (e.hasSubscribe()) {
      final s = e.subscribe;
      await _ack(s.cmdId);
      final state = _sessions[s.sessionId];
      if (state == null) return;
      await _send(Envelope()..sessionState = state);
      _seq += 1;
      await _send(Envelope()
        ..termSnapshot = (TermSnapshot()
          ..sessionId = s.sessionId
          ..seq = _seq
          ..rows = s.rows
          ..cols = s.cols
          ..vt = utf8.encode(_screen(state, s.cols))));
    } else if (e.hasNewSession()) {
      final id = 'demo-${_sessions.length + 1}';
      _sessions[id] = SessionState()
        ..sessionId = id
        ..source = SessionSource.SESSION_SOURCE_HOST_SPAWNED
        ..command = '/bin/zsh'
        ..cwd = '~'
        ..status = SessionStatus.SESSION_STATUS_IDLE;
      await _send(Envelope()..sessionState = _sessions[id]!);
      await _ack(e.newSession.cmdId, sessionId: id);
    } else if (e.hasUnsubscribe()) {
      await _ack(e.unsubscribe.cmdId);
    } else if (e.hasResize()) {
      await _ack(e.resize.cmdId);
    } else if (e.hasStopSession()) {
      await _ack(e.stopSession.cmdId);
    }
  }

  /// The terminal content: a Claude Code turn ending in a permission prompt
  /// for the first session, a prompt for the others.
  static String _screen(SessionState s, int cols) {
    const reset = '\x1b[0m', bold = '\x1b[1m', dim = '\x1b[2m';
    const green = '\x1b[32m', blue = '\x1b[34m', yellow = '\x1b[33m', cyan = '\x1b[36m';
    final prompt = '$green${s.cwd} %$reset ';
    if (s.sessionId != 'demo-1') return '\r\n$prompt';
    final w = cols.clamp(36, 52) - 2; // inner width of the boxes
    String box(List<String> lines, {String color = ''}) {
      final top = '$color╭${'─' * w}╮$reset';
      final bottom = '$color╰${'─' * w}╯$reset';
      final body = lines.map((l) {
        final visible = l.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
        final pad = (w - 1 - visible.length).clamp(0, w);
        return '$color│$reset $l${' ' * pad}$color│$reset';
      });
      return [top, ...body, bottom].join('\r\n');
    }

    return [
      '${prompt}claude',
      box(['$bold✻ Welcome to Claude Code!$reset', '', '$dim/help for help, /status for your current setup$reset', '', '${dim}cwd: ${s.cwd}$reset']),
      '',
      '$bold> add a retry with backoff to the upload client$reset',
      '',
      '$blue●$reset I\'ll look at the upload client first.',
      '',
      '$blue●$reset ${bold}Read$reset(lib/upload.dart)',
      '  ⎿  Read 84 lines',
      '',
      '$blue●$reset ${bold}Update$reset(lib/upload.dart)',
      '  ⎿  Retry loop with exponential backoff,',
      '     3 attempts, 200 ms base delay.',
      '',
      box([
        '${bold}Edit file$reset',
        '${cyan}lib/upload.dart$reset',
        '',
        'Do you want to make this edit?',
        '$green❯ 1. Yes$reset',
        '  2. Yes, allow all edits this session',
        '  3. No, and tell Claude what to do',
      ], color: yellow),
      '$dim  » auto mode on (shift+tab to cycle)$reset',
    ].join('\r\n');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _toRemote.close();
  }
}
