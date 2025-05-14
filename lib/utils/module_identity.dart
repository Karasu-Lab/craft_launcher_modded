/// Class representing the identification information of a Java module.
/// This class is used to accurately detect library duplicates.
class ModuleIdentity {
  final String groupId;
  final String artifactId;
  final String version;
  final String path;

  // Patterns for module names (checking specific module names like "cpw.mods.securejarhandler")
  static final _knownModulePatterns = <RegExp>[
    RegExp(r'cpw\.mods\.'),
    RegExp(r'net\.minecraftforge\.unsafe'),
    RegExp(r'net\.minecraftforge\.fml'),
    RegExp(r'org\.objectweb\.asm'),
    RegExp(r'org\.ow2\.asm'),
  ];

  // Module ID cache
  static final Map<String, String> _moduleIdCache = {};

  /// Creates a new ModuleIdentity.
  ///
  /// [groupId] - The group identifier of the module (e.g., "net.fabricmc")
  /// [artifactId] - The artifact identifier of the module (e.g., "fabric-loader")
  /// [version] - The version of the module (e.g., "0.16.14")
  /// [path] - The path to the module file
  ModuleIdentity({
    required this.groupId,
    required this.artifactId,
    required this.version,
    required this.path,
  });

  /// Returns the full library key (groupId:artifactId).
  String get libraryKey => '$groupId:$artifactId';

  /// Generates a module-specific key for duplicate detection.
  String get moduleKey {
    // Check the cache
    final cacheKey = libraryKey;
    if (_moduleIdCache.containsKey(cacheKey)) {
      return _moduleIdCache[cacheKey]!;
    }

    String moduleId;

    // Detect specific known module types
    for (final pattern in _knownModulePatterns) {
      if (pattern.hasMatch(groupId)) {
        // For modules that need special handling
        if (groupId.contains('asm')) {
          // For ASM modules, use the last segment of artifactId as the module name
          moduleId = 'asm.${artifactId.split('.').last}';
          _moduleIdCache[cacheKey] = moduleId;
          return moduleId;
        } else if (groupId.contains('minecraftforge')) {
          // Special handling for Forge modules
          moduleId = 'forge.$artifactId';
          _moduleIdCache[cacheKey] = moduleId;
          return moduleId;
        } else if (groupId.contains('cpw.mods')) {
          // For CPW modules
          moduleId = 'cpw.$artifactId';
          _moduleIdCache[cacheKey] = moduleId;
          return moduleId;
        }
      }
    }

    // Standard case: combine the last groupID segment and artifactID
    final lastGroupSegment = groupId.split('.').last;
    moduleId = '$lastGroupSegment.$artifactId';

    // Save to cache
    _moduleIdCache[cacheKey] = moduleId;
    return moduleId;
  }

  /// Compares this module's version with another module's version.
  ///
  /// [other] - The other ModuleIdentity to compare with
  /// Returns true if this module's version is newer than the other module's version.
  bool isNewerThan(ModuleIdentity other) {
    if (other.groupId != groupId || other.artifactId != artifactId) {
      return false; // Can't compare different modules
    }

    return compareVersions(version, other.version);
  }

  /// Compares two semantic versions.
  ///
  /// [v1] - The first version to compare
  /// [v2] - The second version to compare
  /// Returns true if v1 is newer than v2.
  static bool compareVersions(String v1, String v2) {
    final parts1 = v1.split('.');
    final parts2 = v2.split('.');

    final minLength =
        parts1.length < parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < minLength; i++) {
      // Remove non-numeric parts (e.g., "-beta")
      final num1Part = parts1[i].split('-')[0];
      final num2Part = parts2[i].split('-')[0];

      final num1 = int.tryParse(num1Part) ?? 0;
      final num2 = int.tryParse(num2Part) ?? 0;

      if (num1 > num2) return true;
      if (num1 < num2) return false;
    }

    // Check if it's a pre-release
    final isPrerelease1 = v1.contains('-');
    final isPrerelease2 = v2.contains('-');

    // Official releases are always newer than pre-releases
    if (!isPrerelease1 && isPrerelease2) return true;
    if (isPrerelease1 && !isPrerelease2) return false;

    // If the version numbers are the same, consider the one with more segments as newer
    return parts1.length > parts2.length;
  }

  /// Creates a ModuleIdentity from a library name.
  ///
  /// [libraryName] - The full library name (e.g., "net.fabricmc:fabric-loader:0.16.14")
  /// [pathToJar] - The path to the JAR file
  /// Returns a ModuleIdentity object, or null if the library name format is invalid.
  static ModuleIdentity? fromLibraryName(String libraryName, String pathToJar) {
    final parts = libraryName.split(':');
    if (parts.length >= 3) {
      return ModuleIdentity(
        groupId: parts[0],
        artifactId: parts[1],
        version: parts[2],
        path: pathToJar,
      );
    }
    return null;
  }

  @override
  String toString() {
    return '$libraryKey:$version ($moduleKey)';
  }
}
