import 'dart:io';

import 'package:craft_launcher_core/craft_launcher_core.dart';
import 'package:craft_launcher_core/java_arguments/java_arguments_builder.dart';
import 'package:craft_launcher_modded/abstract_modded_launcher.dart';
import 'package:craft_launcher_modded/models/fabric/fabric_version_info.dart';
import 'package:flutter/foundation.dart';

class FabricLauncher extends AbstractModdedLauncher {
  final Map<String, FabricVersionInfo> _fabricVersionCache = {};

  // Base URLs and constants
  final String _mavenBaseUrl = 'https://maven.fabricmc.net/';
  final String _fabricMainClass =
      'net.fabricmc.loader.impl.launch.knot.KnotClient';
  final String _fabricTweakClass =
      'net.fabricmc.loader.impl.launch.knot.KnotClient';
  final String _fabricPrefix = 'fabric-loader-';
  final String _launcherName = 'craft-fabric';
  final String _launcherVersion = '1.0.0';

  final String _loaderName = 'Fabric';

  // Getters for constants
  @override
  String get mavenBaseUrl => _mavenBaseUrl;

  @override
  String get fabricMainClass => _fabricMainClass;

  @override
  String get fabricTweakClass => _fabricTweakClass;

  @override
  String get fabricPrefix => _fabricPrefix;

  @override
  String get launcherName => _launcherName;

  @override
  String get launcherVersion => _launcherVersion;

  @override
  String get loaderName => _loaderName;

  @override
  Map<String, VersionInfo> get versionInfoCache => _fabricVersionCache;

  @override
  String get loaderLibraryPackage => 'net.fabricmc:fabric-loader';

  FabricLauncher({
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
  Future<bool> beforeDownloadClientJar(String versionId) async {
    return true;
  }

  @override
  Future<bool> beforeDownloadAssets(String versionId) async {
    debugPrint('$loaderName: Preparing to download assets');
    return false;
  }

  @override
  Future<bool> beforeDownloadLibraries(String versionId) async {
    debugPrint('$loaderName: Preparing to download libraries');
    return true;
  }

  @override
  Future<bool> beforeExtractNativeLibraries(String versionId) async {
    debugPrint('$loaderName: Preparing to extract native libraries');
    return true;
  }

  @override
  Future<void> afterExtractNativeLibraries(
    String versionId,
    String nativesPath,
  ) async {
    debugPrint(
      '$loaderName: Native libraries extracted to $nativesPath for $versionId',
    );
  }

  @override
  Future<Arguments?> beforeBuildJavaArguments(
    String versionId,
    JavaArgumentsBuilder builder,
    VersionInfo versionInfo,
  ) async {
    debugPrint('$loaderName: Customizing Java arguments for $versionId');

    if (!versionId.startsWith(fabricPrefix)) {
      return versionInfo.arguments;
    }

    String? inheritsFrom = versionInfo.inheritsFrom;
    if (inheritsFrom == null) {
      debugPrint(
        '$loaderName: No parent version found, returning original arguments',
      );
      return versionInfo.arguments;
    }

    debugPrint(
      '$loaderName: Adding placeholders from parent version: $inheritsFrom',
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
        '$loaderName: Added $loaderName-specific placeholders: $fabricPlaceholders',
      );
    }

    builder.addCustomPlaceholders({
      'side': 'client',
      'launcher_name': launcherName,
      'launcher_version': launcherVersion,
    });

    builder.addRawArguments('--tweakClass $fabricTweakClass');

    try {
      final environmentVars = Platform.environment;
      final envPlaceholders = <String, String>{};

      environmentVars.forEach((key, value) {
        if (key.startsWith('${loaderName.toUpperCase()}_') ||
            key.startsWith('MINECRAFT_')) {
          envPlaceholders['env_$key'] = value;
        }
      });

      if (envPlaceholders.isNotEmpty) {
        builder.addCustomPlaceholders(envPlaceholders);
        debugPrint(
          '$loaderName: Added environment placeholders: $envPlaceholders',
        );
      }
    } catch (e) {
      debugPrint('$loaderName: Error adding environment placeholders: $e');
    }

    Arguments? mergedArguments;
    try {
      final parentVersionInfo = await fetchVersionManifest(inheritsFrom);
      if (parentVersionInfo != null) {
        debugPrint(
          '$loaderName: Retrieved parent version info: ${parentVersionInfo.id}',
        );

        Map<String, String> parentPlaceholders = {
          'parent_version': parentVersionInfo.id,
          'parent_main_class': parentVersionInfo.mainClass ?? 'unknown',
        };

        builder.addCustomPlaceholders(parentPlaceholders);
        debugPrint(
          '$loaderName: Added parent version placeholders: $parentPlaceholders',
        );

        if (parentVersionInfo.arguments != null) {
          if (versionInfo.arguments == null) {
            debugPrint('$loaderName: Using parent version arguments as base');
            mergedArguments = parentVersionInfo.arguments;
          } else {
            mergedArguments = builder.mergeArguments(
              parentVersionInfo.arguments!,
              versionInfo.arguments,
              prioritizeAdditional: true,
            );

            debugPrint(
              '$loaderName: Successfully merged arguments from both versions',
            );
          }
        } else if (parentVersionInfo.minecraftArguments != null) {
          debugPrint(
            '$loaderName: Parent uses legacy minecraftArguments format',
          );
          builder.setMinecraftArguments(parentVersionInfo.minecraftArguments!);
        }

        if (parentVersionInfo.arguments == null &&
            versionInfo.arguments != null) {
          debugPrint(
            '$loaderName: Parent has no arguments, using current version arguments',
          );
          mergedArguments = versionInfo.arguments;
        }
      } else {
        debugPrint('$loaderName: Parent version info not found for arguments');
      }
    } catch (e) {
      debugPrint('$loaderName: Error processing parent version arguments: $e');
    }

    return mergedArguments ?? versionInfo.arguments;
  }

  @override
  Future<String> afterBuildJavaArguments(
    String versionId,
    String arguments,
  ) async {
    if (!versionId.startsWith(fabricPrefix)) {
      return arguments;
    }

    debugPrint('$loaderName: Post-processing Java arguments');

    List<String> versionParts = versionId.split('-');
    if (versionParts.length >= 4) {
      String loaderVersion = versionParts[2];
      String minecraftVersion = versionParts.sublist(3).join('-');

      final requiredArguments = <String, String>{
        '--tweakClass': fabricTweakClass,
        '-Dfabric.loader.version=': loaderVersion,
        '-Dminecraft.version=': minecraftVersion,
      };

      List<String> argsList = parseArgumentsString(arguments);
      bool modified = false;

      requiredArguments.forEach((prefix, value) {
        if (!containsArgument(argsList, prefix)) {
          debugPrint('$loaderName: Adding missing argument: $prefix$value');

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
        if (!containsArgument(argsList, prefix)) {
          debugPrint(
            '$loaderName: Adding $loaderName system property: $prefix$value',
          );
          argsList.add('$prefix$value');
          modified = true;
        }
      });

      if (modified) {
        arguments = buildArgumentsString(argsList);
        debugPrint(
          '$loaderName: Modified arguments for $loaderName compatibility',
        );
      }
    }

    debugPrint('$loaderName: Final arguments: $arguments');
    return arguments;
  }
}
