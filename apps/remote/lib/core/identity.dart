import 'dart:convert';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// This device's Noise static key and the hosts it has paired with, kept in
/// the platform secure storage (Keychain / Keystore).
class Identity {
  Identity._(this.keyPair, this._storage, this.hosts);

  static const _keyField = 'remote_static_key';
  static const _hostsField = 'paired_hosts';

  final NoiseKeyPair keyPair;
  final FlutterSecureStorage _storage;
  final List<PairedHost> hosts;

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
    return Identity._(keyPair, s, hosts);
  }

  Future<void> addHost(PairedHost host) async {
    hosts.removeWhere((h) => h.id == host.id);
    hosts.add(host);
    await _save();
  }

  Future<void> removeHost(String id) async {
    hosts.removeWhere((h) => h.id == id);
    await _save();
  }

  Future<void> _save() => _storage.write(key: _hostsField, value: jsonEncode(hosts.map((h) => h.toJson()).toList()));
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
