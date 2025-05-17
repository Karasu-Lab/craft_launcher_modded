import 'package:craft_launcher_modded/loaders/fabric/fabric_launcher.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';

class QuiltLauncher extends FabricLauncher {
  // Override base URLs and constants with Quilt specific values
  final String _quiltMavenBaseUrl =
      'https://maven.quiltmc.org/repository/release/';
  final String _quiltMainClass =
      'org.quiltmc.loader.impl.launch.knot.KnotClient';
  final String _quiltTweakClass =
      'org.quiltmc.loader.impl.launch.knot.KnotClient';
  final String _quiltPrefix = 'quilt-loader-';
  final String _quiltLauncherName = 'craft-quilt';
  final String _quiltLauncherVersion = '1.0.0';

  final String _client = 'quilt-loader-0.28.1.jar';

  // Override getters from parent class
  @override
  String get mavenBaseUrl => _quiltMavenBaseUrl;

  @override
  String get modLoaderMainClass => _quiltMainClass;

  @override
  String get modLoaderTweakClass => _quiltTweakClass;

  @override
  String get modLoaderPrefix => _quiltPrefix;

  @override
  String get launcherName => _quiltLauncherName;

  @override
  String get launcherVersion => _quiltLauncherVersion;

  @override
  bool get useClientJar => false;

  QuiltLauncher({
    required super.gameDir,
    required super.javaDir,
    required super.profiles,
    required super.activeProfile,
    required super.minecraftAccountProfile,
    super.minecraftAuth,
    super.launcherName,
    super.launcherVersion,
    super.microsoftAccount,
    super.onDownloadProgress,
    super.onOperationProgress,
    super.progressReportRate,
  });

  @override
  String getClientJarPath(String versionId) {
    // Try to find the Quilt client jar in the classpath
    String clientPath = '';
    for (var jarPath in classpathManager.classPathJarFiles) {
      String jarName = basename(jarPath);
      if (jarName.contains(_client)) {
        debugPrint('Found Quilt client jar: $jarPath');
        clientPath = jarPath;
        break;
      }
    }

    // If found, add it to classpath and return its path
    if (clientPath.isNotEmpty) {
      debugPrint('Using existing Quilt client jar: $clientPath');
      return clientPath;
    }

    // If not found, download or locate the Quilt client jar
    // and add it to the classpath
    final clientJarPath = super.getClientJarPath(versionId);
    if (clientJarPath.isNotEmpty) {
      classpathManager.addClassPath(clientJarPath);
      debugPrint('Added Quilt client jar to classpath: $clientJarPath');
    }

    return clientJarPath;
  }
}
