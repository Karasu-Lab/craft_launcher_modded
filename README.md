# Craft Launcher Modded

A Dart package for launching Minecraft Java Edition with mod loaders such as Fabric. This library extends the `craft_launcher_core` package to provide additional functionality for modded Minecraft instances.

## Features

- Minecraft mod loader support (Fabric, with planned support for Forge and Quilt)
- Custom version manifest handling for modded instances
- Automatic mod loader library management
- Custom classpath construction for mod loader requirements
- JVM arguments optimization for mod loaders
- Integration with vanilla Minecraft launcher capabilities
- Extensible modded launcher adapter system

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  craft_launcher_modded: ^0.0.1
  craft_launcher_core: ^0.0.3
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Fabric Launcher Setup

```dart
import 'package:craft_launcher_modded/loaders/fabric/fabric_launcher.dart';
import 'package:craft_launcher_core/models/launcher_profiles.dart';

// Create a Fabric profile
final fabricProfile = Profile(
  icon: 'grass',
  name: 'FabricProfile',
  type: 'custom',
  created: DateTime.now().toIso8601String(),
  lastUsed: DateTime.now().toIso8601String(),
  lastVersionId: 'fabric-loader-0.16.14-1.21.5', // Format: fabric-loader-[loader_version]-[minecraft_version]
);

// Initialize Fabric launcher
final fabricLauncher = FabricLauncher(
  gameDir: '/path/to/minecraft',
  javaDir: '/path/to/java',
  profiles: LauncherProfiles(
    profiles: {'fabric_profile': fabricProfile},
    settings: Settings(
      enableSnapshots: false,
      keepLauncherOpen: true,
      showGameLog: true,
    ),
    version: 3,
  ),
  activeProfile: fabricProfile,
  onOperationProgress: (operation, completed, total, percentage) {
    print('$operation: $percentage%');
  },
  launcherName: 'CraftFabricLauncher',
  launcherVersion: '1.0.0',
);

// Launch the game with Fabric
await fabricLauncher.launch(
  onStdout: (data) => print('Minecraft: $data'),
  onStderr: (data) => print('Error: $data'),
  onExit: (code) => print('Game exited with code: $code'),
);
```

### Using with Microsoft Authentication

```dart
import 'package:craft_launcher_modded/loaders/fabric/fabric_launcher.dart';
import 'package:craft_launcher_core/models/models.dart';
import 'package:mcid_connect/mcid_connect.dart';

// Authenticate with Microsoft (see mcid_connect package)
final authService = AuthService(
  clientId: 'your-azure-app-client-id',
  redirectUri: 'http://localhost:3000',
  scopes: ['XboxLive.signin', 'offline_access'],
  onGetDeviceCode: (deviceCodeResponse) {
    print('Please visit: ${deviceCodeResponse.verificationUri}');
    print('And enter this code: ${deviceCodeResponse.userCode}');
  },
);

await authService.startAuthenticationFlow();

// Initialize the Fabric launcher with auth
final fabricLauncher = FabricLauncher(
  // Game directory settings
  gameDir: '/path/to/minecraft',
  javaDir: '/path/to/java',
  profiles: myProfiles,
  activeProfile: fabricProfile,
  
  // Authentication data
  minecraftAccountProfile: authService.minecraftProfile,
  microsoftAccount: authService.microsoftAccount,
  
  launcherName: 'AuthenticatedFabricLauncher',
  launcherVersion: '1.0.0',
);

// Launch with authentication
await fabricLauncher.launch();
```

### Creating a Custom Modded Launcher

You can extend the `AbstractModdedLauncher` class to create a custom modded launcher for other mod loaders:

```dart
import 'package:craft_launcher_modded/abstract_modded_launcher.dart';
import 'package:craft_launcher_core/models/models.dart';

class CustomModLoader extends AbstractModdedLauncher {
  CustomModLoader({
    required super.gameDir,
    required super.javaDir,
    required super.profiles,
    required super.activeProfile,
  });
  
  @override
  Future<void> beforeFetchVersionManifest(String versionId) async {
    // Custom implementation for your mod loader
    print('Preparing to fetch version manifest for $versionId');
    // Your implementation here
  }
  
  @override
  Future<T?> afterFetchVersionManifest<T extends VersionInfo>(
    String versionId,
    T? versionInfo,
  ) async {
    // Process and modify version info for your mod loader
    // Your implementation here
    return versionInfo;
  }
  
  @override
  Future<List<String>> beforeBuildClasspath(
    VersionInfo versionInfo,
    String versionId,
  ) async {
    // Add custom libraries to the classpath
    final List<String> additionalClasspath = [];
    // Your implementation here
    return additionalClasspath;
  }
  
  // Implement other methods as needed
}
```

## Additional information

### Requirements

- Dart SDK 3.7.2 or higher
- Flutter SDK 3.19.0 or higher
- craft_launcher_core package
- Java Runtime Environment (JRE) or Java Development Kit (JDK) for running Minecraft
- Internet connection for downloading mod loader libraries and game assets

### Supported Mod Loaders

- **Fabric**: Current implementation supports Fabric mod loader
- **Forge**: Coming soon
- **Quilt**: Coming soon

### Customization Options

You can customize various aspects of the modded launcher:

- **Launcher Branding**: Set custom launcher name and version that appears in game logs and crash reports
- **Environment Variables**: Add custom environment variables for mod loader configuration
- **JVM Arguments**: Customize Java arguments specific to mod loaders
- **Library Management**: Override library download behavior for custom repositories

### Contributing

Contributions are welcome! Feel free to submit issues or pull requests on the GitHub repository.

### License

This package is available under the MIT License.
