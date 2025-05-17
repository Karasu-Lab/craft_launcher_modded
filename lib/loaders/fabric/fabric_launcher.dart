import 'dart:convert';
import 'dart:io';

import 'package:craft_launcher_core/craft_launcher_core.dart';
import 'package:craft_launcher_core/java_arguments/java_arguments_builder.dart';
import 'package:craft_launcher_core/processes/process_manager.dart';
import 'package:craft_launcher_modded/abstract_modded_launcher.dart';
import 'package:craft_launcher_modded/models/fabric/fabric_version_info.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FabricLauncher extends AbstractModdedLauncher {
  final Map<String, FabricVersionInfo> _fabricVersionCache = {};

  FabricLauncher({
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

  @override
  Future<void> beforeFetchVersionManifest(String versionId) async {
    var versionInfo = await getVersionInfo(versionId);

    if (versionInfo?.inheritsFrom == null) {
      return;
    }

    String inheritsFrom = versionInfo?.inheritsFrom ?? versionInfo!.id;
    if (!versionId.startsWith('fabric-loader-')) {
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
      debugPrint('Fabric version json not found, will create it later');

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
    debugPrint('Fabric: Processing version manifest for $id');

    if (_fabricVersionCache.containsKey(id)) {
      debugPrint('Fabric: Returning cached version info for $id');
      return _fabricVersionCache[id] as T?;
    }

    if (!id.startsWith('fabric-loader-')) {
      debugPrint(
        'Fabric: Not a Fabric version, returning original version info',
      );
      return versionInfo;
    }

    final versionJsonPath = p.join(getGameDir(), 'versions', id, '$id.json');
    final versionJsonFile = File(versionJsonPath);

    if (await versionJsonFile.exists()) {
      try {
        debugPrint('Fabric: Reading existing version JSON file');
        final content = await versionJsonFile.readAsString();
        final json = jsonDecode(content);

        final fabricVersionInfo = FabricVersionInfo.fromJson(json);
        _fabricVersionCache[id] = fabricVersionInfo;

        debugPrint(
          'Fabric: Using existing Fabric JSON: inheritsFrom=${fabricVersionInfo.inheritsFrom}',
        );

        if (fabricVersionInfo.inheritsFrom != null) {
          debugPrint(
            'Fabric: Ensuring parent version ${fabricVersionInfo.inheritsFrom} is available',
          );
          final parentInfo = await super.fetchVersionManifest(
            fabricVersionInfo.inheritsFrom!,
          );
          if (parentInfo != null) {
            debugPrint('Fabric: Parent version info is available');
          }
        }

        return fabricVersionInfo as T?;
      } catch (e) {
        debugPrint('Fabric: Error parsing version JSON: $e');
      }
    } else {
      var inheritsFrom = versionInfo.inheritsFrom;
      if (inheritsFrom != null) {
        debugPrint(
          'Fabric: Creating version info based on parent version: $inheritsFrom',
        );

        try {
          final parentVersionInfo = await super.fetchVersionManifest(
            inheritsFrom,
          );
          if (parentVersionInfo == null) {
            debugPrint('Fabric: Parent version info not found');
            return versionInfo;
          }

          debugPrint('Fabric: Parent version info retrieved successfully');

          List<String> versionParts = id.split('-');
          String loaderVersion = '';
          String minecraftVersion = '';

          if (versionParts.length >= 4) {
            loaderVersion = versionParts[2];
            minecraftVersion = versionParts.sublist(3).join('-');
            debugPrint(
              'Fabric: Loader version: $loaderVersion, Minecraft version: $minecraftVersion',
            );
          } else {
            debugPrint('Fabric: Could not parse loader and Minecraft versions');
          }

          final libraries = parentVersionInfo.libraries ?? [];
          final fabricLibraries = <FabricLibrary>[];

          fabricLibraries.add(
            FabricLibrary(
              name: 'net.fabricmc:fabric-loader:$loaderVersion',
              url: 'https://maven.fabricmc.net/',
            ),
          );

          final fabricVersionInfo = FabricVersionInfo(
            id: id,
            inheritsFrom: inheritsFrom,
            type: 'release',
            mainClass: 'net.fabricmc.loader.impl.launch.knot.KnotClient',
            arguments: parentVersionInfo.arguments,
            minecraftArguments: parentVersionInfo.minecraftArguments,
            assetIndex: parentVersionInfo.assetIndex,
            assets: parentVersionInfo.assets,
            javaVersion: parentVersionInfo.javaVersion,
            libraries: libraries,
            fabricLibraries: fabricLibraries,
          );

          _fabricVersionCache[id] = fabricVersionInfo;

          final versionDir = Directory(p.dirname(versionJsonPath));
          if (!await versionDir.exists()) {
            await versionDir.create(recursive: true);
          }

          final jsonContent = jsonEncode(fabricVersionInfo.toJson());
          await versionJsonFile.writeAsString(jsonContent);

          debugPrint('Fabric: Created and saved version JSON file');
          return fabricVersionInfo as T?;
        } catch (e) {
          debugPrint('Fabric: Error creating version info: $e');
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
    debugPrint('Fabric: Building classpath for $versionId');
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
              debugPrint('Added Fabric library to classpath: $libraryPath');
            } else {
              debugPrint(
                'Fabric library not found, will attempt download: $libraryPath',
              );
              await downloadLibrary(
                coordinates,
                libraryPath,
                'https://maven.fabricmc.net/',
                library.url,
              );
              if (await File(libraryPath).exists()) {
                additionalClasspath.add(p.normalize(libraryPath));
                debugPrint(
                  'Downloaded and added Fabric library to classpath: $libraryPath',
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
  Future<void> afterBuildClasspath(
    VersionInfo versionInfo,
    String versionId,
    List<String> classpath,
  ) async {
    debugPrint('Fabric: Finalizing classpath for $versionId');
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
    debugPrint('Fabric: Preparing to start Minecraft with Fabric');

    environment['FABRIC_LOADER'] = 'true';
  }

  @override
  Future<void> afterStartProcess(
    String versionId,
    MinecraftProcessInfo processInfo,
    MinecraftAuth? auth,
  ) async {
    debugPrint('Fabric: Minecraft with Fabric started successfully');
  }

  @override
  Future<bool> beforeDownloadClientJar(String versionId) async {
    return true;
  }

  @override
  Future<void> afterDownloadClientJar(String versionId) async {
    debugPrint('Fabric: Client JAR downloaded for base game');
  }

  @override
  Future<bool> beforeDownloadAssets(String versionId) async {
    debugPrint('Fabric: Preparing to download assets');
    return true;
  }

  @override
  Future<void> afterDownloadAssets(String versionId) async {
    debugPrint('Fabric: Assets downloaded successfully');
  }

  @override
  Future<bool> beforeDownloadLibraries(String versionId) async {
    debugPrint('Fabric: Preparing to download libraries');
    return true;
  }

  @override
  Future<void> afterDownloadLibraries(String versionId) async {
    debugPrint('Fabric: Libraries downloaded successfully');
  }

  @override
  Future<bool> beforeGetAssetIndex<T extends VersionInfo>(
    String versionId,
    T versionInfo,
  ) async {
    if (!versionId.startsWith('fabric-loader-')) {
      return false;
    }

    debugPrint('Fabric: Intercepting asset index retrieval for $versionId');

    if (versionInfo is FabricVersionInfo && versionInfo.inheritsFrom != null) {
      final inheritsFrom = versionInfo.inheritsFrom!;
      debugPrint(
        'Fabric: Using asset index from parent version: $inheritsFrom',
      );
    }

    return false;
  }

  @override
  String? getCustomAssetIndexPath(String versionId, String assetIndex) {
    if (!versionId.startsWith('fabric-loader-')) {
      return null;
    }

    return null;
  }

  @override
  String? getCustomAssetsDirectory() {
    return null;
  }

  @override
  Future<bool> beforeExtractNativeLibraries(String versionId) async {
    debugPrint('Fabric: Preparing to extract native libraries');
    return true;
  }

  @override
  Future<void> afterExtractNativeLibraries(
    String versionId,
    String nativesPath,
  ) async {
    debugPrint(
      'Fabric: Native libraries extracted to $nativesPath for $versionId',
    );
  }

  @override
  Future<String> getAssetIndex(String versionId) async {
    debugPrint('Fabric: Getting asset index for $versionId');

    if (!versionId.startsWith('fabric-loader-')) {
      return super.getAssetIndex(versionId);
    }

    final fabricVersionInfo = await fetchVersionManifest(versionId);

    if (fabricVersionInfo?.inheritsFrom != null) {
      final inheritsFrom = fabricVersionInfo!.inheritsFrom!;
      debugPrint(
        'Fabric: Getting asset index from parent version: $inheritsFrom',
      );

      try {
        final parentAssetIndex = await super.getAssetIndex(inheritsFrom);
        debugPrint('Fabric: Using parent asset index: $parentAssetIndex');
        return parentAssetIndex;
      } catch (e) {
        debugPrint('Fabric: Error getting parent asset index: $e');
      }
    }

    var inheritsFrom = fabricVersionInfo?.inheritsFrom;
    if (inheritsFrom != null) {
      try {
        debugPrint(
          'Fabric: Trying to get asset index from base version: $inheritsFrom',
        );
        final baseAssetIndex = await super.getAssetIndex(inheritsFrom);
        debugPrint('Fabric: Using base version asset index: $baseAssetIndex');
        return baseAssetIndex;
      } catch (e) {
        debugPrint('Fabric: Error getting base version asset index: $e');
      }
    }

    debugPrint('Fabric: Falling back to vanilla asset index implementation');
    return super.getAssetIndex(versionId);
  }

  @override
  Future<Arguments?> beforeBuildJavaArguments(
    String versionId,
    JavaArgumentsBuilder builder,
    VersionInfo versionInfo,
  ) async {
    debugPrint('Fabric: Customizing Java arguments for $versionId');

    if (!versionId.startsWith('fabric-loader-')) {
      return versionInfo.arguments;
    }

    String? inheritsFrom = versionInfo.inheritsFrom;
    if (inheritsFrom == null) {
      debugPrint(
        'Fabric: No parent version found, returning original arguments',
      );
      return versionInfo.arguments;
    }

    debugPrint(
      'Fabric: Adding placeholders from parent version: $inheritsFrom',
    );

    List<String> versionParts = versionId.split('-');
    if (versionParts.length >= 4) {
      String loaderVersion = versionParts[2];
      String minecraftVersion = versionParts.sublist(3).join('-');

      Map<String, String> fabricPlaceholders = {
        'fabric_loader_version': loaderVersion,
        'minecraft_version': minecraftVersion,
        'fabric_version': versionId,
      };

      builder.addCustomPlaceholders(fabricPlaceholders);
      debugPrint(
        'Fabric: Added Fabric-specific placeholders: $fabricPlaceholders',
      );
    }

    builder.addCustomPlaceholders({
      'side': 'client',
      'launcher_name': 'craft-fabric',
      'launcher_version': '1.0.0',
    });

    builder.addRawArguments(
      '--tweakClass net.fabricmc.loader.impl.launch.knot.KnotClient',
    );

    try {
      final environmentVars = Platform.environment;
      final envPlaceholders = <String, String>{};

      environmentVars.forEach((key, value) {
        if (key.startsWith('FABRIC_') || key.startsWith('MINECRAFT_')) {
          envPlaceholders['env_$key'] = value;
        }
      });

      if (envPlaceholders.isNotEmpty) {
        builder.addCustomPlaceholders(envPlaceholders);
        debugPrint('Fabric: Added environment placeholders: $envPlaceholders');
      }
    } catch (e) {
      debugPrint('Fabric: Error adding environment placeholders: $e');
    }

    Arguments? mergedArguments;
    try {
      final parentVersionInfo = await fetchVersionManifest(inheritsFrom);
      if (parentVersionInfo != null) {
        debugPrint(
          'Fabric: Retrieved parent version info: ${parentVersionInfo.id}',
        );

        Map<String, String> parentPlaceholders = {
          'parent_version': parentVersionInfo.id,
          'parent_main_class': parentVersionInfo.mainClass ?? 'unknown',
        };

        builder.addCustomPlaceholders(parentPlaceholders);
        debugPrint(
          'Fabric: Added parent version placeholders: $parentPlaceholders',
        );

        if (parentVersionInfo.arguments != null) {
          if (versionInfo.arguments == null) {
            debugPrint('Fabric: Using parent version arguments as base');
            mergedArguments = parentVersionInfo.arguments;
          } else {
            mergedArguments = builder.mergeArguments(
              parentVersionInfo.arguments!,
              versionInfo.arguments,
              prioritizeAdditional: true,
            );

            debugPrint(
              'Fabric: Successfully merged arguments from both versions',
            );
          }
        } else if (parentVersionInfo.minecraftArguments != null) {
          debugPrint('Fabric: Parent uses legacy minecraftArguments format');
          builder.setMinecraftArguments(parentVersionInfo.minecraftArguments!);
        }

        if (parentVersionInfo.arguments == null &&
            versionInfo.arguments != null) {
          debugPrint(
            'Fabric: Parent has no arguments, using current version arguments',
          );
          mergedArguments = versionInfo.arguments;
        }
      } else {
        debugPrint('Fabric: Parent version info not found for arguments');
      }
    } catch (e) {
      debugPrint('Fabric: Error processing parent version arguments: $e');
    }

    return mergedArguments ?? versionInfo.arguments;
  }

  @override
  Future<String> afterBuildJavaArguments(
    String versionId,
    String arguments,
  ) async {
    if (!versionId.startsWith('fabric-loader-')) {
      return arguments;
    }

    debugPrint('Fabric: Post-processing Java arguments');

    List<String> versionParts = versionId.split('-');
    if (versionParts.length >= 4) {
      String loaderVersion = versionParts[2];
      String minecraftVersion = versionParts.sublist(3).join('-');

      final requiredArguments = <String, String>{
        '--tweakClass': 'net.fabricmc.loader.impl.launch.knot.KnotClient',
        '-Dfabric.loader.version=': loaderVersion,
        '-Dminecraft.version=': minecraftVersion,
      };

      List<String> argsList = _parseArgumentsString(arguments);
      bool modified = false;

      requiredArguments.forEach((prefix, value) {
        if (!_containsArgument(argsList, prefix)) {
          debugPrint('Fabric: Adding missing argument: $prefix$value');

          if (prefix == '--tweakClass') {
            argsList.add(prefix);
            argsList.add(value);
          } else {
            argsList.add('$prefix$value');
          }
          modified = true;
        }
      });

      final fabricSystemProps = <String, String>{
        '-Dfabric.side=': 'client',
        '-Dfabric.development=': 'false',
      };

      fabricSystemProps.forEach((prefix, value) {
        if (!_containsArgument(argsList, prefix)) {
          debugPrint('Fabric: Adding Fabric system property: $prefix$value');
          argsList.add('$prefix$value');
          modified = true;
        }
      });

      if (modified) {
        arguments = _buildArgumentsString(argsList);
        debugPrint('Fabric: Modified arguments for Fabric compatibility');
      }
    }

    debugPrint('Fabric: Final arguments: $arguments');
    return arguments;
  }

  List<String> _parseArgumentsString(String argsString) {
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

  String _buildArgumentsString(List<String> argsList) {
    return argsList.join(' ');
  }

  bool _containsArgument(List<String> argsList, String prefix) {
    for (final arg in argsList) {
      if (arg.startsWith(prefix)) {
        return true;
      }

      if (prefix == '--tweakClass' && arg == prefix) {
        final index = argsList.indexOf(arg);
        if (index < argsList.length - 1) {
          final nextArg = argsList[index + 1];
          if (nextArg.contains(
            'net.fabricmc.loader.impl.launch.knot.KnotClient',
          )) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
