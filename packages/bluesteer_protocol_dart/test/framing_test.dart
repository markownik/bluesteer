import 'dart:typed_data';

import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:test/test.dart';

void main() {
  test('round trips a single message', () {
    final framer = Framer();
    final message = [104, 101, 108, 108, 111];
    expect(framer.receive(frame(message)), [message]);
    expect(framer.pendingByteCount, 0);
  });

  test('reassembles across arbitrary chunks', () {
    final a = List.filled(300, 0x41);
    final b = List.filled(7, 0x42);
    final stream = Uint8List.fromList([...frame(a), ...frame(b)]);
    final framer = Framer();
    final got = <List<int>>[];
    for (var i = 0; i < stream.length; i += 3) {
      got.addAll(framer.receive(stream.sublist(i, i + 3 > stream.length ? stream.length : i + 3)));
    }
    expect(got, [a, b]);
    expect(framer.pendingByteCount, 0);
  });

  test('empty message is valid', () {
    expect(Framer().receive(frame([])), [<int>[]]);
  });

  test('rejects oversized message', () {
    expect(() => frame(List.filled(maxFrameLength + 1, 0)), throwsArgumentError);
  });

  test('keeps a partial frame', () {
    final framer = Framer();
    final framed = frame([97, 98, 99]);
    expect(framer.receive(framed.sublist(0, 4)), isEmpty);
    expect(framer.pendingByteCount, 4);
    expect(framer.receive(framed.sublist(4)), [[97, 98, 99]]);
  });
}
