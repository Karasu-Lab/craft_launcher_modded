import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Helper class for Java-related operations
class JavaHelper {
  /// Extracts a JAR file to the specified directory
  ///
  /// [jarPath] - Path to the JAR file
  /// [extractDir] - Directory where the JAR contents will be extracted
  /// Returns true if extraction was successful, false otherwise
  static Future<bool> extractJar(String jarPath, String extractDir) async {
    try {
      final dir = Directory(extractDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final process = await Process.run('jar', [
        'xf',
        jarPath,
      ], workingDirectory: extractDir);

      if (process.exitCode != 0) {
        final javaProcess = await Process.run('java', [
          '-jar',
          '-xf',
          jarPath,
        ], workingDirectory: extractDir);

        if (javaProcess.exitCode != 0) {
          return await _extractJarAsZip(jarPath, extractDir);
        }
      }

      return true;
    } catch (e) {
      return await _extractJarAsZip(jarPath, extractDir);
    }
  }

  /// Extracts a JAR file by treating it as a ZIP file
  ///
  /// [jarPath] - Path to the JAR file
  /// [extractDir] - Directory where the JAR contents will be extracted
  /// Returns true if extraction was successful, false otherwise
  static Future<bool> _extractJarAsZip(
    String jarPath,
    String extractDir,
  ) async {
    try {
      final jarFile = File(jarPath);
      if (!await jarFile.exists()) {
        return false;
      }

      if (Platform.isWindows) {
        final process = await Process.run('powershell.exe', [
          '-Command',
          "Add-Type -AssemblyName System.IO.Compression.FileSystem; " "[System.IO.Compression.ZipFile]::ExtractToDirectory('$jarPath', '$extractDir')",
        ]);
        return process.exitCode == 0;
      } else {
        final process = await Process.run('unzip', [
          '-o',
          jarPath,
          '-d',
          extractDir,
        ]);
        return process.exitCode == 0;
      }
    } catch (e) {
      debugPrint('Error extracting JAR as ZIP: $e');
      return false;
    }
  }

  /// Extracts the module name from a JAR file
  ///
  /// Attempts to determine the module name by examining:
  /// - module-info.class
  /// - META-INF/MANIFEST.MF for Automatic-Module-Name or Microsoft-Module-Name
  /// - Bundle-SymbolicName
  /// - Falls back to extracting module information from the filename
  ///
  /// [jarPath] - Path to the JAR file
  /// Returns the module name if found, null otherwise
  static Future<String?> extractModuleName(String jarPath) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('jar_module_');

      try {
        final moduleInfoPath = p.join(tempDir.path, 'module-info.class');

        final process = await Process.run('jar', [
          'xf',
          jarPath,
          'module-info.class',
        ], workingDirectory: tempDir.path);

        if (process.exitCode == 0 && await File(moduleInfoPath).exists()) {
          final jarName = p.basename(jarPath).toLowerCase();
          final nameParts = jarName.split('-');

          if (nameParts.isNotEmpty) {
            return nameParts[0];
          }
        }

        final manifestDir = p.join(tempDir.path, 'META-INF');
        final manifestPath = p.join(manifestDir, 'MANIFEST.MF');

        final manifestProcess = await Process.run('jar', [
          'xf',
          jarPath,
          'META-INF/MANIFEST.MF',
        ], workingDirectory: tempDir.path);

        if (manifestProcess.exitCode == 0 &&
            await File(manifestPath).exists()) {
          final manifestFile = File(manifestPath);
          final content = await manifestFile.readAsString();

          final moduleNameMatch = RegExp(
            r'(Automatic-Module-Name|Microsoft-Module-Name): ([^\r\n]+)',
          ).firstMatch(content);

          if (moduleNameMatch != null && moduleNameMatch.groupCount >= 2) {
            return moduleNameMatch.group(2)?.trim();
          }

          final bundleNameMatch = RegExp(
            r'Bundle-SymbolicName: ([^\r\n;]+)',
          ).firstMatch(content);

          if (bundleNameMatch != null && bundleNameMatch.groupCount >= 1) {
            return bundleNameMatch.group(1)?.trim();
          }
        }

        final jarFileName = p.basenameWithoutExtension(jarPath);
        final fileNameParts = jarFileName.split('-');

        if (fileNameParts.isNotEmpty) {
          String moduleName = fileNameParts[0];

          for (int i = 1; i < fileNameParts.length; i++) {
            final part = fileNameParts[i];
            if (RegExp(r'^\d').hasMatch(part)) {
              break;
            }
            moduleName += '-$part';
          }

          return moduleName;
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error extracting module name: $e');
    }

    return null;
  }

  /// Extracts the version information from a JAR file
  ///
  /// Attempts to determine the module version by examining:
  /// - Version information in the filename
  /// - META-INF/MANIFEST.MF for Implementation-Version, Bundle-Version, or Specification-Version
  ///
  /// [jarPath] - Path to the JAR file
  /// Returns the module version if found, null otherwise
  static Future<String?> extractModuleVersion(String jarPath) async {
    try {
      final jarFileName = p.basenameWithoutExtension(jarPath);
      final fileNameParts = jarFileName.split('-');

      if (fileNameParts.length >= 2) {
        for (int i = 1; i < fileNameParts.length; i++) {
          final part = fileNameParts[i];
          if (RegExp(r'^\d+(\.\d+)*$').hasMatch(part)) {
            return part;
          }
        }
      }

      final tempDir = await Directory.systemTemp.createTemp('jar_version_');

      try {
        final manifestPath = p.join(tempDir.path, 'META-INF', 'MANIFEST.MF');

        final process = await Process.run('jar', [
          'xf',
          jarPath,
          'META-INF/MANIFEST.MF',
        ], workingDirectory: tempDir.path);

        if (process.exitCode == 0 && await File(manifestPath).exists()) {
          final manifestFile = File(manifestPath);
          final content = await manifestFile.readAsString();

          final versionMatch = RegExp(
            r'(Implementation-Version|Bundle-Version|Specification-Version): ([^\r\n]+)',
          ).firstMatch(content);

          if (versionMatch != null && versionMatch.groupCount >= 2) {
            return versionMatch.group(2)?.trim();
          }
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error extracting module version: $e');
    }

    return null;
  }
}
