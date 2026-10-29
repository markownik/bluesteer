// Store screenshots. Runs the app in demo mode against a scripted Mac and
// captures each screen the listings show:
//
//   flutter drive --dart-define=BLUESTEER_DEMO=true \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <device>
//
// `tools/store-shots.sh` wraps this for the iOS simulator and an Android device:
// it also starts tools/shot-server.py and passes its port as STORE_SHOTS_PORT, so
// each screen is captured natively (status bar included) while the test waits.
import 'dart:io';

import 'package:bluesteer_remote/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = Platform.operatingSystem;
  const port = int.fromEnvironment('STORE_SHOTS_PORT'); // 0: save Flutter's own render through the driver

  testWidgets('store screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    if (port == 0 && Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      if (port == 0) {
        await binding.takeScreenshot('$platform/$name');
        return;
      }
      await tester.runAsync(() async {
        final client = HttpClient();
        final response = await (await client.getUrl(Uri.parse('http://localhost:$port/shot/$platform/$name'))).close();
        await response.drain<void>();
        client.close();
        if (response.statusCode != 200) throw StateError('capture of $name failed: HTTP ${response.statusCode}');
      });
    }

    // 1. Paired Macs.
    expect(find.text('MacBook Pro'), findsOneWidget);
    await shot('01-hosts');

    // 2. Terminals on the Mac.
    await tester.tap(find.text('MacBook Pro'));
    await tester.pumpAndSettle();
    expect(find.text('~/Projects/app'), findsOneWidget);
    await shot('02-sessions');

    // 3. A terminal with Claude Code waiting for permission.
    await tester.tap(find.text('~/Projects/app'));
    await tester.pumpAndSettle();
    // The snapshot lands after the view reports its size; the status line reads "Claude needs permission  ·  ~/Projects/app".
    for (var i = 0; i < 20 && find.textContaining('Claude needs permission').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('Claude needs permission'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus(); // no software keyboard in the capture
    await tester.pumpAndSettle();
    await shot('03-terminal');

    // 4. Pairing: the nearby list.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pair with a Mac'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to pair by code'), findsOneWidget);
    await shot('04-pair');

    // 5. The 6-digit code.
    await tester.tap(find.text('Tap to pair by code'));
    await tester.pumpAndSettle();
    expect(find.text('It matches'), findsOneWidget);
    await shot('05-pair-code');

    // 6. Settings.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock before connecting'), findsOneWidget);
    await shot('06-settings');
  });
}
