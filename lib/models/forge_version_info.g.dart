// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forge_version_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ForgeVersionInfo _$ForgeVersionInfoFromJson(
  Map<String, dynamic> json,
) => ForgeVersionInfo(
  id: json['id'] as String,
  inheritsFrom: json['inheritsFrom'] as String?,
  type: json['type'] as String?,
  mainClass: json['mainClass'] as String?,
  minecraftArguments: json['minecraftArguments'] as String?,
  arguments:
      json['arguments'] == null
          ? null
          : Arguments.fromJson(json['arguments'] as Map<String, dynamic>),
  assetIndex:
      json['assetIndex'] == null
          ? null
          : AssetIndex.fromJson(json['assetIndex'] as Map<String, dynamic>),
  assets: json['assets'] as String?,
  complianceLevel: (json['complianceLevel'] as num?)?.toInt(),
  downloads:
      json['downloads'] == null
          ? null
          : Downloads.fromJson(json['downloads'] as Map<String, dynamic>),
  javaVersion:
      json['javaVersion'] == null
          ? null
          : JavaVersion.fromJson(json['javaVersion'] as Map<String, dynamic>),
  libraries:
      (json['libraries'] as List<dynamic>?)
          ?.map((e) => Library.fromJson(e as Map<String, dynamic>))
          .toList(),
  logging:
      json['logging'] == null
          ? null
          : Logging.fromJson(json['logging'] as Map<String, dynamic>),
  minimumLauncherVersion: (json['minimumLauncherVersion'] as num?)?.toInt(),
  releaseTime: json['releaseTime'] as String?,
  time: json['time'] as String?,
  comments:
      (json['_comment_'] as List<dynamic>?)?.map((e) => e as String).toList(),
  forgeLibraries:
      (json['forgeLibraries'] as List<dynamic>?)
          ?.map((e) => ForgeLibrary.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$ForgeVersionInfoToJson(ForgeVersionInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      if (instance.inheritsFrom case final value?) 'inheritsFrom': value,
      'type': instance.type,
      'mainClass': instance.mainClass,
      'minecraftArguments': instance.minecraftArguments,
      'arguments': instance.arguments,
      'assetIndex': instance.assetIndex,
      'assets': instance.assets,
      'complianceLevel': instance.complianceLevel,
      'downloads': instance.downloads,
      'javaVersion': instance.javaVersion,
      'libraries': instance.libraries,
      'logging': instance.logging,
      'minimumLauncherVersion': instance.minimumLauncherVersion,
      'releaseTime': instance.releaseTime,
      'time': instance.time,
      '_comment_': instance.comments,
      'forgeLibraries': instance.forgeLibraries,
    };

ForgeLibrary _$ForgeLibraryFromJson(Map<String, dynamic> json) => ForgeLibrary(
  name: json['name'] as String?,
  url: json['url'] as String?,
  downloads:
      json['downloads'] == null
          ? null
          : ForgeLibraryDownloads.fromJson(
            json['downloads'] as Map<String, dynamic>,
          ),
);

Map<String, dynamic> _$ForgeLibraryToJson(ForgeLibrary instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'downloads': instance.downloads,
    };

ForgeLibraryDownloads _$ForgeLibraryDownloadsFromJson(
  Map<String, dynamic> json,
) => ForgeLibraryDownloads(
  artifact:
      json['artifact'] == null
          ? null
          : ForgeArtifact.fromJson(json['artifact'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ForgeLibraryDownloadsToJson(
  ForgeLibraryDownloads instance,
) => <String, dynamic>{'artifact': instance.artifact};

ForgeArtifact _$ForgeArtifactFromJson(Map<String, dynamic> json) =>
    ForgeArtifact(
      path: json['path'] as String?,
      url: json['url'] as String?,
      sha1: json['sha1'] as String?,
      size: (json['size'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ForgeArtifactToJson(ForgeArtifact instance) =>
    <String, dynamic>{
      'path': instance.path,
      'url': instance.url,
      'sha1': instance.sha1,
      'size': instance.size,
    };
