import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:craft_launcher_core/models/launcher_profiles.dart';
import 'package:craft_launcher_modded/loaders/fabric/fabric_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final String gameDir = p.join(
    Directory.current.path,
    'test_minecraft_fabric_dir',
  );

  final String javaDir =
      Platform.isWindows
          ? 'C:\\Program Files\\Java\\jdk-21\\'
          : '/usr/bin/java';

  var version = 'fabric-loader-0.16.14-1.21.5';

  final testFabricProfile = Profile(
    icon: 'grass',
    name: 'TestFabricProfile',
    type: 'custom',
    created: DateTime.now().toIso8601String(),
    lastUsed: DateTime.now().toIso8601String(),
    lastVersionId: version,
  );

  final testProfiles = LauncherProfiles(
    profiles: {'test_fabric_profile': testFabricProfile},
    settings: Settings(
      crashAssistance: true,
      enableAdvanced: true,
      enableAnalytics: true,
      enableHistorical: true,
      enableReleases: true,
      enableSnapshots: false,
      keepLauncherOpen: true,
      profileSorting: 'name',
      showGameLog: true,
      showMenu: true,
      soundOn: true,
    ),
    version: 3,
  );

  late FabricLauncher fabricLauncher;
  late Completer<int> completer;

  setUp(() async {
    final launcherDir = Directory(p.join(gameDir));
    if (!await launcherDir.exists()) {
      await launcherDir.create(recursive: true);
    }

    final profilesPath = p.join(gameDir, 'launcher_profiles.json');
    final profilesFile = File(profilesPath);
    await profilesFile.writeAsString(jsonEncode(testProfiles.toJson()));

    fabricLauncher = FabricLauncher(
      gameDir: gameDir,
      javaDir: javaDir,
      profiles: testProfiles,
      activeProfile: testFabricProfile,
      minecraftAccountProfile: null,
      onOperationProgress: (operation, completed, total, percentage) {
        debugPrint(
          'Operation: $operation, Completed: $completed, Total: $total, Percentage: $percentage',
        );
      },
    );

    completer = Completer<int>();

    fabricLauncher.onExit = (int exitCode) {
      debugPrint('Minecraft with Fabric process exited with code: $exitCode');
      completer.complete(exitCode);
    };
  });

  test('Initialize Fabric Adapter', () {
    expect(fabricLauncher.getGameDir(), equals(gameDir));
    expect(fabricLauncher.getJavaDir(), equals(javaDir));
    expect(fabricLauncher.getActiveProfile().name, equals('TestFabricProfile'));
    expect(fabricLauncher.getActiveProfile().lastVersionId, equals(version));
  });

  test(
    'Launch Fabric Minecraft - Integration Test',
    () async {
      try {
        try {
          await fabricLauncher.launch();
          final exitCode = await completer.future.timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              debugPrint(
                'Minecraft with Fabric process timeout after 5 minutes',
              );
              return -1;
            },
          );

          if (exitCode == 0) {
            debugPrint('Minecraft process exited successfully with code 0');
          } else if (exitCode == -1) {
            debugPrint('Minecraft process timed out, but test will continue');
          } else {
            fail('Minecraft process exited abnormally. Exit code: $exitCode');
          }
        } catch (e, stackTrace) {
          debugPrint('Error during Fabric launch: $e');
          debugPrint('Stack trace: $stackTrace');
          rethrow;
        }
      } catch (e) {
        fail('Failed to launch Minecraft with Fabric: $e');
      }
    },
    timeout: Timeout(Duration(minutes: 10)),
  );
}
