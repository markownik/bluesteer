import 'dart:convert';
import 'dart:io';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Version reported in `RemoteHello`.
const appVersion = '0.1.0';

/// This device's Noise static key, its name, and the hosts it has paired
/// with, kept in the platform secure storage (Keychain / Keystore).
class Identity {
  Identity._(this.keyPair, this._storage, this.hosts, this._deviceName, [this._ephemeral = false, this._requireUnlock = false]);

  static const _keyField = 'remote_static_key';
  static const _hostsField = 'paired_hosts';
  static const _nameField = 'device_name';
  static const _unlockField = 'require_unlock';

  final NoiseKeyPair keyPair;
  final FlutterSecureStorage _storage;
  final List<PairedHost> hosts;
  String _deviceName;
  final bool _ephemeral;
  bool _requireUnlock;

  /// Shown by the host for this device ("Marek's iPhone"); sent in `RemoteHello`.
  String get deviceName => _deviceName;

  /// Ask for Face ID / fingerprint / the passcode before connecting to a Mac
  /// (a stolen phone is a terminal on the Mac otherwise; docs/threat-model.md).
  bool get requireUnlock => _requireUnlock;

  /// An identity that touches no storage (tests and the demo mode).
  Identity.inMemory({required NoiseKeyPair keyPair, String deviceName = 'test', List<PairedHost>? hosts})
      : this._(keyPair, const FlutterSecureStorage(), hosts ?? [], deviceName, true);

  static Future<Identity> load([FlutterSecureStorage? storage]) async {
    final s = storage ?? const FlutterSecureStorage();
    NoiseKeyPair keyPair;
    final stored = await s.read(key: _keyField);
    if (stored != null) {
      keyPair = await NoiseKeyPair.fromPrivateKey(base64Decode(stored));
    } else {
      keyPair = await NoiseKeyPair.generate();
      await s.write(key: _keyField, value: base64Encode(await keyPair.privateKeyBytes()));
    }
    final hostsJson = await s.read(key: _hostsField);
    final hosts = hostsJson == null
        ? <PairedHost>[]
        : (jsonDecode(hostsJson) as List).map((e) => PairedHost.fromJson(e as Map<String, dynamic>)).toList();
    final name = await s.read(key: _nameField) ?? await _defaultDeviceName();
    final unlock = await s.read(key: _unlockField) == 'true';
    return Identity._(keyPair, s, hosts, name, false, unlock);
  }

  static Future<String> _defaultDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) return (await info.iosInfo).modelName;
      if (Platform.isAndroid) return (await info.androidInfo).model;
      if (Platform.isMacOS) return (await info.macOsInfo).computerName;
    } catch (_) {}
    return Platform.operatingSystem;
  }

  Future<void> setDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _deviceName = trimmed;
    if (!_ephemeral) await _storage.write(key: _nameField, value: trimmed);
  }

  Future<void> setRequireUnlock(bool on) async {
    _requireUnlock = on;
    if (!_ephemeral) await _storage.write(key: _unlockField, value: on.toString());
  }

  /// Adds a host, or replaces the entry with the same id in place.
  Future<void> addHost(PairedHost host) async {
    final i = hosts.indexWhere((h) => h.id == host.id);
    if (i >= 0) {
      hosts[i] = host;
    } else {
      hosts.add(host);
    }
    await _save();
  }

  Future<void> removeHost(String id) async {
    hosts.removeWhere((h) => h.id == id);
    await _save();
  }

  Future<void> _save() async {
    if (_ephemeral) return;
    await _storage.write(key: _hostsField, value: jsonEncode(hosts.map((h) => h.toJson()).toList()));
  }
}

class PairedHost {
  PairedHost({required this.id, required this.name, required this.hostKey});

  /// base64url of the 16-byte host instance id (from INFO / the QR code).
  final String id;
  final String name;
  /// The host's Noise static public key, pinned at pairing.
  final List<int> hostKey;

  factory PairedHost.fromJson(Map<String, dynamic> j) =>
      PairedHost(id: j['id'] as String, name: j['name'] as String, hostKey: base64Decode(j['hostKey'] as String));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hostKey': base64Encode(hostKey)};
}
