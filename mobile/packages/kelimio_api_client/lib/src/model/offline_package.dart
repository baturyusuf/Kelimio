//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'offline_package.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OfflinePackage {
  /// Returns a new [OfflinePackage] instance.
  OfflinePackage({
    required this.courseId,

    required this.courseReleaseId,

    required this.supportLanguage,

    required this.formatVersion,

    required this.sha256,

    required this.downloadUrl,

    required this.expiresAt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'courseReleaseId', required: true, includeIfNull: false)
  final String courseReleaseId;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'supportLanguage', required: true, includeIfNull: false)
  final String supportLanguage;

  @JsonKey(name: r'formatVersion', required: true, includeIfNull: false)
  final OfflinePackageFormatVersionEnum formatVersion;

  @JsonKey(name: r'sha256', required: true, includeIfNull: false)
  final String sha256;

  @JsonKey(name: r'downloadUrl', required: true, includeIfNull: false)
  final String downloadUrl;

  @JsonKey(name: r'expiresAt', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflinePackage &&
          other.courseId == courseId &&
          other.courseReleaseId == courseReleaseId &&
          other.supportLanguage == supportLanguage &&
          other.formatVersion == formatVersion &&
          other.sha256 == sha256 &&
          other.downloadUrl == downloadUrl &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      courseId.hashCode +
      courseReleaseId.hashCode +
      supportLanguage.hashCode +
      formatVersion.hashCode +
      sha256.hashCode +
      downloadUrl.hashCode +
      expiresAt.hashCode;

  factory OfflinePackage.fromJson(Map<String, dynamic> json) =>
      _$OfflinePackageFromJson(json);

  Map<String, dynamic> toJson() => _$OfflinePackageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum OfflinePackageFormatVersionEnum {
  @JsonValue(1)
  number1('1');

  const OfflinePackageFormatVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
