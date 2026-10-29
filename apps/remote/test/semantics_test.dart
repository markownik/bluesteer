import 'package:bluesteer_protocol_dart/bluesteer_protocol_dart.dart';
import 'package:bluesteer_remote/core/host_connection.dart';
import 'package:bluesteer_remote/core/identity.dart';
import 'package:bluesteer_remote/ui/hosts_page.dart';
import 'package:bluesteer_remote/ui/pair_code_page.dart';
import 'package:bluesteer_remote/ui/terminal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// What a screen reader gets: labelled keys and buttons, status as text in a
/// live region, the pairing code digit by digit, a confirmed delete.
void main() {
  late Identity identity;
  late PairedHost host;

  setUpAll(() async {
    final hostKey = await NoiseKeyPair.generate();
    host = PairedHost(id: 'host-1', name: 'mini', hostKey: hostKey.publicKey);
    identity = Identity.inMemory(keyPair: await NoiseKeyPair.generate(), hosts: [host]);
  });

  testWidgets('terminal keys have spoken labels and the status is a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    final connection = HostConnection(identity: identity, host: host, transport: FakeTransport());
    await tester.pumpWidget(MaterialApp(
      home: TerminalPage(connection: connection, sessionId: 's1', hostName: 'mini', cwd: '/home/me'),
    ));
    await tester.pump();
    for (final label in ['Escape', 'Tab', 'Shift Tab', 'Control C', 'Control D', 'Up arrow', 'Down arrow', 'Left arrow', 'Right arrow', 'Enter']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    final status = tester.getSemantics(find.text('Connecting…  ·  /home/me'));
    expect(status.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
    await connection.close();
  });

  testWidgets('forgetting a Mac asks first', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HostsPage(identity: identity)));
    await tester.pump();
    expect(find.text('mini'), findsOneWidget);
    await tester.longPress(find.text('mini'));
    await tester.pumpAndSettle();
    expect(find.text('Forget mini?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('mini'), findsOneWidget, reason: 'cancel keeps the Mac');
    await tester.longPress(find.text('mini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(find.text('mini'), findsNothing);
    expect(find.byTooltip('Pair with a Mac'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('the pairing code is read digit by digit', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PairingCode('388832'))));
    expect(find.text('388 832'), findsOneWidget);
    expect(find.bySemanticsLabel('3 8 8, 8 3 2'), findsOneWidget);
    semantics.dispose();
  });
}
