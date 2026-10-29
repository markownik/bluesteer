import 'package:flutter/material.dart';

import 'core/identity.dart';
import 'demo/demo.dart';
import 'ui/hosts_page.dart';

void main() => runApp(const BlueSteerRemoteApp());

/// BlueSteer Remote: an offline Bluetooth terminal for agent sessions on a Mac.
class BlueSteerRemoteApp extends StatelessWidget {
  const BlueSteerRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueSteer',
      debugShowCheckedModeBanner: !demoMode,
      theme: ThemeData.dark(useMaterial3: true),
      home: FutureBuilder<Identity>(
        future: demoMode ? demoIdentity() : Identity.load(),
        builder: (context, snapshot) {
          final identity = snapshot.data;
          if (identity == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return HostsPage(identity: identity);
        },
      ),
    );
  }
}
