import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Helper class for Java module-related operations
class JavaModuleHelper {
  /// Extracts the module name from a JAR file
  ///
  /// Attempts to determine the Java module name by examining:
  /// - The JAR's file path for known module patterns
  /// - module-info.class file
  /// - META-INF/module-name or META-INF/automatic-module-name
  /// - META-INF/MANIFEST.MF for Automatic-Module-Name
  /// - Falls back to deriving a name from the filename using Java 9 automatic module naming rules
  ///
  /// [jarPath] The path to the JAR file
  /// Returns the module name if found, null otherwise
  static Future<String?> extractModuleName(String jarPath) async {
    try {
      final jarFile = File(jarPath);
      if (!await jarFile.exists()) {
        return null;
      }

      final bytes = await jarFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileName = p.basename(jarPath);
      final filePath = jarPath.replaceAll('\\', '/');

      if (filePath.contains('net/minecraftforge/securemodules/')) {
        return 'cpw.mods.securejarhandler';
      } else if (filePath.contains('net/minecraftforge/unsafe/')) {
        return 'net.minecraftforge.unsafe';
      } else if (filePath.contains('net/minecraftforge/bootstrap-api/')) {
        return 'net.minecraftforge.bootstrap.api';
      } else if (filePath.contains('net/minecraftforge/bootstrap/')) {
        return 'net.minecraftforge.bootstrap';
      } else if (filePath.contains('net/minecraftforge/JarJarFileSystems/')) {
        return 'JarJarFileSystems';
      } else if (filePath.contains('com/google/guava/guava/')) {
        return 'com.google.common';
      } else if (filePath.contains('com/google/guava/failureaccess/')) {
        return 'failureaccess';
      } else if (filePath.contains('net/minecraftforge/accesstransformers/')) {
        return 'accesstransformers';
      } else if (filePath.contains('net/minecraftforge/eventbus/')) {
        return 'net.minecraftforge.eventbus';
      } else if (filePath.contains('net/jodah/typetools/')) {
        return 'net.jodah.typetools';
      } else if (filePath.contains('net/minecraftforge/forgespi/')) {
        return 'net.minecraftforge.forgespi';
      } else if (filePath.contains('net/minecraftforge/coremods/')) {
        return 'net.minecraftforge.coremod';
      } else if (filePath.contains('org/openjdk/nashorn/')) {
        return 'org.openjdk.nashorn';
      } else if (filePath.contains('net/minecraftforge/modlauncher/')) {
        return 'cpw.mods.modlauncher';
      } else if (filePath.contains('net/minecraftforge/mergetool-api/')) {
        return 'net.minecraftforge.mergetool.api';
      } else if (filePath.contains('com/electronwill/night-config/toml/')) {
        return 'com.electronwill.nightconfig.toml';
      } else if (filePath.contains('com/electronwill/night-config/core/')) {
        return 'com.electronwill.nightconfig.core';
      } else if (filePath.contains('org/apache/maven/maven-artifact/')) {
        return 'maven.artifact';
      } else if (filePath.contains('net/minecrell/terminalconsoleappender/')) {
        return 'terminalconsoleappender';
      } else if (filePath.contains('org/jline/jline-reader/')) {
        return 'org.jline.reader';
      } else if (filePath.contains('org/jline/jline-terminal/')) {
        return 'org.jline.terminal';
      }

      if (filePath.contains('org/ow2/asm/')) {
        if (fileName.startsWith('asm-')) {
          final subModule = fileName.split('-')[1].split('.')[0];
          return 'org.objectweb.asm.$subModule';
        }
        return 'org.objectweb.asm';
      }

      final moduleInfoFile = archive.files.firstWhere(
        (file) => file.name == 'module-info.class',
        orElse:
            () => archive.files.firstWhere(
              (file) => file.name.endsWith('/module-info.class'),
              orElse:
                  () => archive.files.firstWhere(
                    (file) => file.name.toLowerCase() == 'meta-inf/module-name',
                    orElse:
                        () => archive.files.firstWhere(
                          (file) =>
                              file.name.toLowerCase() ==
                              'meta-inf/automatic-module-name',
                          orElse: () => ArchiveFile('', 0, []),
                        ),
                  ),
            ),
      );

      if (moduleInfoFile.size > 0) {
        if (moduleInfoFile.name.toLowerCase() == 'meta-inf/module-name' ||
            moduleInfoFile.name.toLowerCase() ==
                'meta-inf/automatic-module-name') {
          final content = String.fromCharCodes(
            moduleInfoFile.content as List<int>,
          );
          return content.trim();
        }

        final fileName = p.basename(jarPath);
        final moduleName = fileName.replaceAll(RegExp(r'\.jar$'), '');
        return moduleName;
      }

      final manifestFile = archive.files.firstWhere(
        (file) => file.name.toUpperCase() == 'META-INF/MANIFEST.MF',
        orElse: () => ArchiveFile('', 0, []),
      );

      if (manifestFile.size > 0) {
        final content = String.fromCharCodes(manifestFile.content as List<int>);
        final lines = content.split('\n');

        for (final line in lines) {
          if (line.startsWith('Automatic-Module-Name:')) {
            return line.substring('Automatic-Module-Name:'.length).trim();
          }
        }
      }

      final nameWithoutExtension = fileName.replaceAll(RegExp(r'\.jar$'), '');

      final versionPattern = RegExp(r'-\d+(\.\d+)*(-[a-zA-Z0-9]+)?$');
      final baseName = nameWithoutExtension.replaceAll(versionPattern, '');

      String moduleName = baseName
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '.')
          .replaceAll(RegExp(r'\.+'), '.')
          .replaceAll(RegExp(r'^\.'), '')
          .replaceAll(RegExp(r'\.$'), '');

      return moduleName;
    } catch (e) {
      debugPrint('Error extracting module name from $jarPath: $e');
      return null;
    }
  }

  /// Extracts the version information from a JAR file
  ///
  /// Attempts to determine the module version by examining:
  /// - META-INF/MANIFEST.MF for Implementation-Version or Bundle-Version
  /// - Falls back to extracting version information from the filename
  ///
  /// [jarPath] The path to the JAR file
  /// Returns the module version if found, null otherwise
  static Future<String?> extractModuleVersion(String jarPath) async {
    try {
      final jarFile = File(jarPath);
      if (!await jarFile.exists()) {
        return null;
      }

      final bytes = await jarFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestFile = archive.files.firstWhere(
        (file) => file.name.toUpperCase() == 'META-INF/MANIFEST.MF',
        orElse: () => ArchiveFile('', 0, []),
      );

      if (manifestFile.size > 0) {
        final content = String.fromCharCodes(manifestFile.content as List<int>);
        final lines = content.split('\n');

        for (final line in lines) {
          if (line.startsWith('Implementation-Version:')) {
            return line.substring('Implementation-Version:'.length).trim();
          } else if (line.startsWith('Bundle-Version:')) {
            return line.substring('Bundle-Version:'.length).trim();
          }
        }
      }

      final fileName = p.basename(jarPath);
      final versionPattern = RegExp(r'-(\d+(\.\d+)*(-[a-zA-Z0-9]+)?)\.jar$');
      final match = versionPattern.firstMatch(fileName);

      if (match != null) {
        return match.group(1);
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting module version from $jarPath: $e');
      return null;
    }
  }
}
