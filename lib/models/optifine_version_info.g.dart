// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'optifine_version_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OptifineVersionInfo _$OptifineVersionInfoFromJson(Map<String, dynamic> json) =>
    OptifineVersionInfo(
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
              : JavaVersion.fromJson(
                json['javaVersion'] as Map<String, dynamic>,
              ),
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
      optifineLibraries:
          (json['optifineLibraries'] as List<dynamic>?)
              ?.map((e) => OptifineLibrary.fromJson(e as Map<String, dynamic>))
              .toList(),
    );

Map<String, dynamic> _$OptifineVersionInfoToJson(
  OptifineVersionInfo instance,
) => <String, dynamic>{
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
  'optifineLibraries': instance.optifineLibraries,
};

OptifineLibrary _$OptifineLibraryFromJson(Map<String, dynamic> json) =>
    OptifineLibrary(name: json['name'] as String?);

Map<String, dynamic> _$OptifineLibraryToJson(OptifineLibrary instance) =>
    <String, dynamic>{'name': instance.name};
