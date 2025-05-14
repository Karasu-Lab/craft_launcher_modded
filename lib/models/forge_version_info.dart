import 'package:craft_launcher_core/craft_launcher_core.dart';
import 'package:json_annotation/json_annotation.dart';

part 'forge_version_info.g.dart';

@JsonSerializable()
class ForgeVersionInfo extends VersionInfo {
  @JsonKey(name: '_comment_')
  final List<String>? comments;

  final List<ForgeLibrary>? _forgeLibraries;

  ForgeVersionInfo({
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
    this.comments,
    List<ForgeLibrary>? forgeLibraries,
  }) : _forgeLibraries = forgeLibraries;

  List<ForgeLibrary>? get forgeLibraries => _forgeLibraries;

  factory ForgeVersionInfo.fromJson(Map<String, dynamic> json) {
    final librariesData = json['libraries'] as List<dynamic>?;

    final result = _$ForgeVersionInfoFromJson(json);

    if (librariesData != null) {
      final forgeLibraries =
          librariesData
              .map((lib) => ForgeLibrary.fromJson(lib as Map<String, dynamic>))
              .toList();

      result._setForgeLibraries(forgeLibraries);
    }

    return result;
  }

  void _setForgeLibraries(List<ForgeLibrary> libraries) {
    (this as dynamic)._forgeLibraries = libraries;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = _$ForgeVersionInfoToJson(this);

    if (_forgeLibraries != null) {
      json['libraries'] = _forgeLibraries.map((lib) => lib.toJson()).toList();
    }

    return json;
  }
}

@JsonSerializable()
class ForgeLibrary {
  final String? name;
  final String? url;
  final ForgeLibraryDownloads? downloads;

  ForgeLibrary({this.name, this.url, this.downloads});

  factory ForgeLibrary.fromJson(Map<String, dynamic> json) =>
      _$ForgeLibraryFromJson(json);

  Map<String, dynamic> toJson() => _$ForgeLibraryToJson(this);
}

@JsonSerializable()
class ForgeLibraryDownloads {
  final ForgeArtifact? artifact;

  ForgeLibraryDownloads({this.artifact});

  factory ForgeLibraryDownloads.fromJson(Map<String, dynamic> json) =>
      _$ForgeLibraryDownloadsFromJson(json);

  Map<String, dynamic> toJson() => _$ForgeLibraryDownloadsToJson(this);
}

@JsonSerializable()
class ForgeArtifact {
  final String? path;
  final String? url;
  final String? sha1;
  final int? size;

  ForgeArtifact({this.path, this.url, this.sha1, this.size});

  factory ForgeArtifact.fromJson(Map<String, dynamic> json) =>
      _$ForgeArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$ForgeArtifactToJson(this);
}
