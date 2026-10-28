import 'dart:typed_data';

/// Largest ciphertext a single frame may carry (Noise's 65535 limit).
const int maxFrameLength = 65535;

/// Prefixes [message] with its 16-bit big-endian length (SPEC.md §3).
Uint8List frame(List<int> message) {
  if (message.length > maxFrameLength) {
    throw ArgumentError.value(message.length, 'message', 'longer than $maxFrameLength bytes');
  }
  final out = Uint8List(message.length + 2);
  out[0] = message.length >> 8;
  out[1] = message.length & 0xff;
  out.setRange(2, out.length, message);
  return out;
}

/// Reassembles complete frames from an incoming byte stream.
class Framer {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  /// Appends received bytes and returns every message completed by them, in order.
  List<Uint8List> receive(List<int> chunk) {
    _buffer.add(_pending);
    _buffer.add(chunk);
    final bytes = _buffer.takeBytes();
    final messages = <Uint8List>[];
    var offset = 0;
    while (bytes.length - offset >= 2) {
      final length = (bytes[offset] << 8) | bytes[offset + 1];
      if (bytes.length - offset < 2 + length) break;
      messages.add(Uint8List.sublistView(bytes, offset + 2, offset + 2 + length));
      offset += 2 + length;
    }
    _pending = Uint8List.sublistView(bytes, offset);
    return messages;
  }

  /// Bytes received so far that do not yet form a complete frame.
  int get pendingByteCount => _pending.length;
}
