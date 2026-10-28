import 'package:flutter/material.dart';

import 'dev/replay_page.dart';

void main() => runApp(const BlueSteerRemoteApp());

/// BlueSteer Remote. During Phase 0 it opens the development replay page;
/// the real navigation (hosts, sessions, terminal) arrives in Phase 1–2.
class BlueSteerRemoteApp extends StatelessWidget {
  const BlueSteerRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueSteer',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ReplayPage(),
    );
  }
}
