// Development-only: renders the same VT snapshot in two TerminalView configurations.
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class TermTestPage extends StatefulWidget {
  const TermTestPage({super.key});
  @override
  State<TermTestPage> createState() => _TermTestPageState();
}

class _TermTestPageState extends State<TermTestPage> {
  final a = Terminal(maxLines: 1000);
  final b = Terminal(maxLines: 1000);
  final c = Terminal(maxLines: 1000);
  final ctl = TerminalController();
  static const vt = '\x1b[0m\x1b[H\x1b[2J\x1b[1;1H\x1b[0m(base) user@macbook ~ % hello\x1b[2;1H second line\x1b[0m\x1b[1;28H';

  @override
  void initState() {
    super.initState();
    a.write(vt);
    b.write(vt);
    c.resize(80, 24);
    c.write(vt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('term test: A ctl+autofocus 11 / B plain 9 / C resized 80x24')),
      body: Column(children: [
        Expanded(child: TerminalView(a, controller: ctl, textStyle: const TerminalStyle(fontSize: 11), autofocus: true)),
        const Divider(),
        Expanded(child: TerminalView(b, textStyle: const TerminalStyle(fontSize: 9))),
        const Divider(),
        Expanded(child: TerminalView(c, textStyle: const TerminalStyle(fontSize: 11))),
      ]),
    );
  }
}
