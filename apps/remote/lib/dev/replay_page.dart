// Development-only page: replays a `tools/pty-recorder` recording through the
// xterm widget to check rendering fidelity on a device (Phase 0, spike 3).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key, this.asset = 'assets/dev/claude-normal.rec', this.speed = 1.0});
  final String asset;
  final double speed;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  final terminal = Terminal(maxLines: 5000);
  late final ByteConversionSink _sink;
  String status = 'loading…';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Streaming UTF-8 decoder so multi-byte characters split across entries survive.
    _sink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(
      StringConversionSink.fromStringSink(_TerminalSink(terminal)),
    );
    _load();
  }

  Future<void> _load() async {
    final data = (await rootBundle.load(widget.asset)).buffer.asUint8List();
    final entries = _parse(data);
    setState(() => status = '${entries.length} entries, replaying at ${widget.speed}×');
    final start = DateTime.now();
    var i = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 20), (t) {
      final elapsed = DateTime.now().difference(start).inMicroseconds * widget.speed;
      while (i < entries.length && entries[i].micros <= elapsed) {
        final e = entries[i++];
        if (e.type == 0) {
          _sink.add(e.payload);
        } else if (e.type == 1) {
          final bd = ByteData.sublistView(e.payload);
          terminal.resize(bd.getUint16(2, Endian.little), bd.getUint16(0, Endian.little));
        }
      }
      if (i >= entries.length) {
        t.cancel();
        setState(() => status = 'done (${entries.length} entries)');
      }
    });
  }

  List<_Entry> _parse(Uint8List data) {
    final entries = <_Entry>[];
    var i = 6; // magic "BSREC\x01"
    final bd = ByteData.sublistView(data);
    while (i + 13 <= data.length) {
      final type = data[i];
      final micros = bd.getUint64(i + 1, Endian.little);
      final len = bd.getUint32(i + 9, Endian.little);
      i += 13;
      if (i + len > data.length) break;
      entries.add(_Entry(type, micros, Uint8List.sublistView(data, i, i + len)));
      i += len;
    }
    return entries;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Replay · $status', style: const TextStyle(fontSize: 14))),
      body: TerminalView(terminal, textStyle: const TerminalStyle(fontSize: 9)),
    );
  }
}

class _Entry {
  _Entry(this.type, this.micros, this.payload);
  final int type;
  final int micros;
  final Uint8List payload;
}

class _TerminalSink implements StringSink {
  _TerminalSink(this.terminal);
  final Terminal terminal;
  @override
  void write(Object? obj) => terminal.write(obj.toString());
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) => write(objects.join(separator));
  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));
  @override
  void writeln([Object? obj = '']) => write('$obj\n');
}
