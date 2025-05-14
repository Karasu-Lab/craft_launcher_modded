import 'package:craft_launcher_core/craft_launcher_core.dart';
import 'package:json_annotation/json_annotation.dart';

part 'optifine_version_info.g.dart';

@JsonSerializable()
class OptifineVersionInfo extends VersionInfo {
  final List<OptifineLibrary>? _optifineLibraries;

  OptifineVersionInfo({
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
    List<OptifineLibrary>? optifineLibraries,
  }) : _optifineLibraries = optifineLibraries;

  List<OptifineLibrary>? get optifineLibraries => _optifineLibraries;

  factory OptifineVersionInfo.fromJson(Map<String, dynamic> json) {
    final librariesData = json['libraries'] as List<dynamic>?;

    final result = _$OptifineVersionInfoFromJson(json);

    if (librariesData != null) {
      final optifineLibraries =
          librariesData
              .map(
                (lib) => OptifineLibrary.fromJson(lib as Map<String, dynamic>),
              )
              .toList();

      result._setOptifineLibraries(optifineLibraries);
    }

    return result;
  }

  void _setOptifineLibraries(List<OptifineLibrary> libraries) {
    (this as dynamic)._optifineLibraries = libraries;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$OptifineVersionInfoToJson(this);

    if (_optifineLibraries != null) {
      json['libraries'] =
          _optifineLibraries.map((lib) => lib.toJson()).toList();
    }

    return json;
  }
}

@JsonSerializable()
class OptifineLibrary {
  final String? name;

  OptifineLibrary({this.name});

  factory OptifineLibrary.fromJson(Map<String, dynamic> json) =>
      _$OptifineLibraryFromJson(json);

  Map<String, dynamic> toJson() => _$OptifineLibraryToJson(this);
}
