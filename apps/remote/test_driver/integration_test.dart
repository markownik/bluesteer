// Driver for integration_test/screenshots_test.dart. Without tools/store-shots.sh
// (no STORE_SHOTS_PORT) the test saves Flutter's own render of each screen, which
// lands here after the run: build/screenshots/<platform>/<name>.png (relative to apps/remote).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        final file = File('build/screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        stdout.writeln('screenshot ${file.path}');
        return true;
      },
    );
