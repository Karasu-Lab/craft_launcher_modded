import 'package:craft_launcher_core/craft_launcher_core.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fabric_version_info.g.dart';

@JsonSerializable()
class FabricVersionInfo extends VersionInfo {
  List<Library>? _fabricLibraries;

  FabricVersionInfo({
    required super.id,
    super.inheritsFrom,
    super.type,
    super.mainClass,
    super.minecraftArguments,
    super.arguments,
    super.assetIndex,
    super.assets,
    super.complianceLevel,
    super.downloads,
    super.javaVersion,
    super.libraries,
    super.logging,
    super.minimumLauncherVersion,
    super.releaseTime,
    super.time,
    List<Library>? fabricLibraries,
  }) : _fabricLibraries = fabricLibraries;

  List<Library>? get fabricLibraries => _fabricLibraries;

  factory FabricVersionInfo.fromJson(Map<String, dynamic> json) {
    final librariesData = json['libraries'] as List<dynamic>?;

    final result = _$FabricVersionInfoFromJson(json);

    if (librariesData != null) {
      final fabricLibraries =
          librariesData
              .map((lib) => FabricLibrary.fromJson(lib as Map<String, dynamic>))
              .toList();

      result._setFabricLibraries(fabricLibraries);
    }

    return result;
  }

  void _setFabricLibraries(List<FabricLibrary> libraries) {
    _fabricLibraries = libraries;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$FabricVersionInfoToJson(this);

    if (_fabricLibraries != null) {
      json['libraries'] = _fabricLibraries?.map((lib) => lib.toJson()).toList();
    }

    return json;
  }
}

@JsonSerializable()
class FabricLibrary extends Library {
  FabricLibrary({super.name, super.url});

  factory FabricLibrary.fromJson(Map<String, dynamic> json) =>
      _$FabricLibraryFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$FabricLibraryToJson(this);
}
