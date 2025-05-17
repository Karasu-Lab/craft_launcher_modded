import 'dart:convert';

import 'package:craft_launcher_core/craft_launcher_core.dart';
import 'package:craft_launcher_core/launcher_adapter.dart';
import 'package:craft_launcher_core/vanilla_launcher.dart';
import 'package:craft_launcher_modded/models/fabric/fabric_version_info.dart';
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
  String get modLoaderMainClass;
  String get modLoaderTweakClass;
  String get modLoaderPrefix;
  String get launcherName;
  String get launcherVersion;
  String get loaderName;
  Map<String, VersionInfo> get versionInfoCache;
  String get loaderLibraryPackage;

  Library getLoaderLibrary(String loaderVersion) {
    return FabricLibrary(
      name: '$loaderLibraryPackage:$loaderVersion',
      url: mavenBaseUrl,
    );
  }

  @override
  bool isModded() {
    return true;
  }

  @override
  Future<void> beforeFetchVersionManifest(String versionId) async {
    var versionInfo = await getVersionInfo(versionId);

    if (versionInfo?.inheritsFrom == null) {
      return;
    }

    String inheritsFrom = versionInfo?.inheritsFrom ?? versionInfo!.id;
    if (!versionId.startsWith(modLoaderPrefix)) {
      return;
    }

    final versionJsonPath = p.join(
      getGameDir(),
      'versions',
      versionId,
      '$versionId.json',
    );
    final versionJsonFile = File(versionJsonPath);

    if (!await versionJsonFile.exists()) {
      debugPrint('$loaderName version json not found, will create it later');

      debugPrint('Found base Minecraft version: $inheritsFrom');

      final baseVersionJsonPath = p.join(
        getGameDir(),
        'versions',
        inheritsFrom,
        '$inheritsFrom.json',
      );
      final baseVersionJsonFile = File(baseVersionJsonPath);

      if (!await baseVersionJsonFile.exists()) {
        debugPrint('Base version JSON not found, downloading vanilla first');
      }
    }
  }

  @override
  Future<T?> afterFetchVersionManifest<T extends VersionInfo>(
    String versionId,
    T? versionInfo,
  ) async {
    if (versionInfo == null) return null;

    final id = versionInfo.id;
    debugPrint('$loaderName: Processing version manifest for $id');

    if (versionInfoCache.containsKey(id)) {
      debugPrint('$loaderName: Returning cached version info for $id');
      return versionInfoCache[id] as T?;
    }

    if (!id.startsWith(modLoaderPrefix)) {
      debugPrint(
        '$loaderName: Not a $loaderName version, returning original version info',
      );
      return versionInfo;
    }

    final versionJsonPath = p.join(getGameDir(), 'versions', id, '$id.json');
    final versionJsonFile = File(versionJsonPath);

    if (await versionJsonFile.exists()) {
      try {
        debugPrint('$loaderName: Reading existing version JSON file');
        final content = await versionJsonFile.readAsString();
        final json = jsonDecode(content);

        final fabricVersionInfo = FabricVersionInfo.fromJson(json);
        versionInfoCache[id] = fabricVersionInfo;

        debugPrint(
          '$loaderName: Using existing Fabric JSON: inheritsFrom=${fabricVersionInfo.inheritsFrom}',
        );

        if (fabricVersionInfo.inheritsFrom != null) {
          debugPrint(
            '$loaderName: Ensuring parent version ${fabricVersionInfo.inheritsFrom} is available',
          );
          final parentInfo = await super.fetchVersionManifest(
            fabricVersionInfo.inheritsFrom!,
          );
          if (parentInfo != null) {
            debugPrint('$loaderName: Parent version info is available');
          }
        }

        return fabricVersionInfo as T?;
      } catch (e) {
        debugPrint('$loaderName: Error parsing version JSON: $e');
      }
    } else {
      var inheritsFrom = versionInfo.inheritsFrom;
      if (inheritsFrom != null) {
        debugPrint(
          '$loaderName: Creating version info based on parent version: $inheritsFrom',
        );

        try {
          final parentVersionInfo = await super.fetchVersionManifest(
            inheritsFrom,
          );
          if (parentVersionInfo == null) {
            debugPrint('$loaderName: Parent version info not found');
            return versionInfo;
          }

          debugPrint('$loaderName: Parent version info retrieved successfully');

          List<String> versionParts = id.split('-');
          String loaderVersion = '';
          String minecraftVersion = '';

          if (versionParts.length >= 4) {
            loaderVersion = versionParts[2];
            minecraftVersion = versionParts.sublist(3).join('-');
            debugPrint(
              '$loaderName: Loader version: $loaderVersion, Minecraft version: $minecraftVersion',
            );
          } else {
            debugPrint(
              '$loaderName: Could not parse loader and Minecraft versions',
            );
          }

          final libraries = parentVersionInfo.libraries ?? [];
          final fabricLibraries = <Library>[];

          fabricLibraries.add(getLoaderLibrary(loaderVersion));

          final fabricVersionInfo = VersionInfo(
            id: id,
            inheritsFrom: inheritsFrom,
            type: versionInfo.type,
            mainClass: modLoaderMainClass,
            arguments: parentVersionInfo.arguments,
            minecraftArguments: parentVersionInfo.minecraftArguments,
            assetIndex: parentVersionInfo.assetIndex,
            assets: parentVersionInfo.assets,
            javaVersion: parentVersionInfo.javaVersion,
            libraries: [...libraries, ...fabricLibraries],
          );

          versionInfoCache[id] = fabricVersionInfo;

          final versionDir = Directory(p.dirname(versionJsonPath));
          if (!await versionDir.exists()) {
            await versionDir.create(recursive: true);
          }

          final jsonContent = jsonEncode(fabricVersionInfo.toJson());
          await versionJsonFile.writeAsString(jsonContent);

          debugPrint('$loaderName: Created and saved version JSON file');
          return fabricVersionInfo as T?;
        } catch (e) {
          debugPrint('$loaderName: Error creating version info: $e');
        }
      }
    }

    return versionInfo;
  }

  @override
  Future<List<String>> beforeBuildClasspath(
    VersionInfo versionInfo,
    String versionId,
  ) async {
    debugPrint('$loaderName: Building classpath for $versionId');
    final List<String> additionalClasspath = [];

    final fabricLibraries = versionInfo.libraries;
    if (fabricLibraries != null) {
      final librariesDir = p.join(getGameDir(), 'libraries');

      for (var library in fabricLibraries) {
        if (library.name != null) {
          final coordinates = parseLibraryName(library.name!);
          if (coordinates != null) {
            final libraryPath = getLibraryPath(coordinates, librariesDir);
            if (await File(libraryPath).exists()) {
              additionalClasspath.add(p.normalize(libraryPath));
              debugPrint(
                'Added $loaderName library to classpath: $libraryPath',
              );
            } else {
              debugPrint(
                '$loaderName library not found, will attempt download: $libraryPath',
              );
              await downloadLibrary(
                coordinates,
                libraryPath,
                mavenBaseUrl,
                library.url,
              );
              if (await File(libraryPath).exists()) {
                additionalClasspath.add(p.normalize(libraryPath));
                debugPrint(
                  'Downloaded and added $loaderName library to classpath: $libraryPath',
                );
              }
            }
          }
        }
      }
    }

    if (versionInfo.inheritsFrom != null) {
      var info =
          await fetchVersionManifest(versionInfo.inheritsFrom!) as VersionInfo;
      additionalClasspath.addAll(
        await classpathManager.buildClasspath(info, info.id),
      );
    }

    return classpathManager.removeDuplicateLibraries(additionalClasspath);
  }

  @override
  Future<void> beforeStartProcess(
    String javaExe,
    List<String> javaArgs,
    String workingDirectory,
    Map<String, String> environment,
    String versionId,
    MinecraftAuth? auth,
  ) async {
    debugPrint('$loaderName: Preparing to start Minecraft with $loaderName');

    environment['${loaderName.toUpperCase()}_LOADER'] = 'true';
  }

  @override
  Future<bool> beforeGetAssetIndex<T extends VersionInfo>(
    String versionId,
    T versionInfo,
  ) async {
    if (!versionId.startsWith(modLoaderPrefix)) {
      return false;
    }

    debugPrint(
      '$loaderName: Intercepting asset index retrieval for $versionId',
    );

    if (versionInfo is FabricVersionInfo && versionInfo.inheritsFrom != null) {
      final inheritsFrom = versionInfo.inheritsFrom!;
      debugPrint(
        '$loaderName: Using asset index from parent version: $inheritsFrom',
      );
    }

    return false;
  }

  @override
  Future<String> getAssetIndex(String versionId) async {
    debugPrint('$loaderName: Getting asset index for $versionId');

    if (!versionId.startsWith(modLoaderPrefix)) {
      return super.getAssetIndex(versionId);
    }

    final fabricVersionInfo = await fetchVersionManifest(versionId);

    if (fabricVersionInfo?.inheritsFrom != null) {
      final inheritsFrom = fabricVersionInfo!.inheritsFrom!;
      debugPrint(
        '$loaderName: Getting asset index from parent version: $inheritsFrom',
      );

      try {
        final parentAssetIndex = await super.getAssetIndex(inheritsFrom);
        debugPrint('$loaderName: Using parent asset index: $parentAssetIndex');
        return parentAssetIndex;
      } catch (e) {
        debugPrint('$loaderName: Error getting parent asset index: $e');
      }
    }

    var inheritsFrom = fabricVersionInfo?.inheritsFrom;
    if (inheritsFrom != null) {
      try {
        debugPrint(
          '$loaderName: Trying to get asset index from base version: $inheritsFrom',
        );
        final baseAssetIndex = await super.getAssetIndex(inheritsFrom);
        debugPrint(
          '$loaderName: Using base version asset index: $baseAssetIndex',
        );
        return baseAssetIndex;
      } catch (e) {
        debugPrint('$loaderName: Error getting base version asset index: $e');
      }
    }

    debugPrint(
      '$loaderName: Falling back to vanilla asset index implementation',
    );
    return super.getAssetIndex(versionId);
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

  List<String> parseArgumentsString(String argsString) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer currentArg = StringBuffer();

    for (int i = 0; i < argsString.length; i++) {
      final char = argsString[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        currentArg.write(char);
      } else if (char == ' ' && !inQuotes) {
        if (currentArg.isNotEmpty) {
          result.add(currentArg.toString());
          currentArg.clear();
        }
      } else {
        currentArg.write(char);
      }
    }

    if (currentArg.isNotEmpty) {
      result.add(currentArg.toString());
    }

    return result;
  }

  String buildArgumentsString(List<String> argsList) {
    return argsList.join(' ');
  }

  bool containsArgument(List<String> argsList, String prefix) {
    for (final arg in argsList) {
      if (arg.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }
}
