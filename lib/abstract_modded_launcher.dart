import 'package:craft_launcher_core/launcher_adapter.dart';
import 'package:craft_launcher_core/vanilla_launcher.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:http/http.dart' as http;

abstract class AbstractModdedLauncher extends VanillaLauncher
    implements LauncherAdapter {
  AbstractModdedLauncher({
    required super.gameDir,
    required super.javaDir,
    required super.profiles,
    required super.activeProfile,
    required super.minecraftAuth,
    required super.minecraftAccountProfile,
    super.launcherName,
    super.launcherVersion,
    super.microsoftAccount,
    super.onDownloadProgress,
    super.onOperationProgress,
    super.progressReportRate,
  });

  // Getters for constants
  String get mavenBaseUrl;
  String get fabricMainClass;
  String get fabricTweakClass;
  String get fabricPrefix;
  String get launcherName;
  String get launcherVersion;
  String get loaderName;

  @override
  bool isModded() {
    return true;
  }

  Map<String, String>? parseLibraryName(String name) {
    final parts = name.split(':');
    if (parts.length < 3) return null;

    final result = <String, String>{
      'group': parts[0],
      'artifact': parts[1],
      'version': parts[2],
    };

    if (parts.length > 3) {
      result['classifier'] = parts[3];
    }

    return result;
  }

  String getLibraryPath(Map<String, String> coordinates, String librariesDir) {
    final group = coordinates['group']!.replaceAll('.', '/');
    final artifact = coordinates['artifact']!;
    final version = coordinates['version']!;

    String filename = '$artifact-$version';
    if (coordinates.containsKey('classifier')) {
      filename += '-${coordinates['classifier']}';
    }
    filename += '.jar';

    return p.join(librariesDir, group, artifact, version, filename);
  }

  Future<void> downloadLibrary(
    Map<String, String> coordinates,
    String targetPath,
    String? defaultUrlBase,
    String? librarySpecificUrl,
  ) async {
    final group = coordinates['group']!.replaceAll('.', '/');
    final artifact = coordinates['artifact']!;
    final version = coordinates['version']!;

    String filename = '$artifact-$version';
    if (coordinates.containsKey('classifier')) {
      filename += '-${coordinates['classifier']}';
    }
    filename += '.jar';

    String url;
    if (librarySpecificUrl != null && librarySpecificUrl.isNotEmpty) {
      if (librarySpecificUrl.endsWith('/')) {
        url = '$librarySpecificUrl$group/$artifact/$version/$filename';
      } else {
        url = librarySpecificUrl;
        url =
            '${librarySpecificUrl.endsWith('/') ? librarySpecificUrl : '$librarySpecificUrl/'}$group/$artifact/$version/$filename';
      }
    } else if (defaultUrlBase != null && defaultUrlBase.isNotEmpty) {
      url =
          '${defaultUrlBase.endsWith('/') ? defaultUrlBase : '$defaultUrlBase/'}$group/$artifact/$version/$filename';
    } else {
      debugPrint(
        'Warning: No base URL provided for downloading $filename. Download might fail.',
      );
      return;
    }

    final directory = Directory(p.dirname(targetPath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    try {
      debugPrint('Downloading library from $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        await File(targetPath).writeAsBytes(response.bodyBytes);
        debugPrint('Successfully downloaded library to $targetPath');
      } else {
        debugPrint(
          'Failed to download library: HTTP ${response.statusCode} from $url',
        );
      }
    } catch (e) {
      debugPrint('Error downloading library from $url: $e');
    }
  }
}
