import 'dart:convert';
import 'dart:typed_data';

/// The contents of the QR code the host shows while pairing (SPEC.md §2.1):
/// `bluesteer://pair?v=1&id=<base64url>&psk=<base64url>&name=<name>`.
class PairingUri {
  PairingUri({required this.version, required this.hostId, required this.psk, required this.name});

  final int version;
  final Uint8List hostId;
  final Uint8List psk;
  final String name;

  static PairingUri? tryParse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'bluesteer' || uri.host != 'pair') return null;
    final q = uri.queryParameters;
    try {
      final psk = _b64url(q['psk']!);
      final id = _b64url(q['id']!);
      if (psk.length != 32 || id.length != 16) return null;
      return PairingUri(version: int.parse(q['v'] ?? '1'), hostId: id, psk: psk, name: q['name'] ?? 'Mac');
    } catch (_) {
      return null;
    }
  }

  static Uint8List _b64url(String s) => base64Url.decode(base64Url.normalize(s));
}
