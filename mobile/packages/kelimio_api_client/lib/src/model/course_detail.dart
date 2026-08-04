//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/test_summary.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_detail.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseDetail {
  /// Returns a new [CourseDetail] instance.
  CourseDetail({
    required this.id,

    required this.name,

    this.description,

    required this.targetLanguage,

    required this.supportLanguages,

    required this.accessType,

    required this.visibility,

    required this.enrolled,

    required this.ownerDisplayName,

    required this.releaseId,

    required this.tests,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'targetLanguage', required: true, includeIfNull: false)
  final String targetLanguage;

  @JsonKey(name: r'supportLanguages', required: true, includeIfNull: false)
  final Set<String> supportLanguages;

  @JsonKey(name: r'accessType', required: true, includeIfNull: false)
  final CourseDetailAccessTypeEnum accessType;

  @JsonKey(name: r'visibility', required: true, includeIfNull: false)
  final CourseDetailVisibilityEnum visibility;

  @JsonKey(name: r'enrolled', required: true, includeIfNull: false)
  final bool enrolled;

  @JsonKey(name: r'ownerDisplayName', required: true, includeIfNull: false)
  final String ownerDisplayName;

  @JsonKey(name: r'releaseId', required: true, includeIfNull: false)
  final String releaseId;

  @JsonKey(name: r'tests', required: true, includeIfNull: false)
  final List<TestSummary> tests;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseDetail &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.targetLanguage == targetLanguage &&
          other.supportLanguages == supportLanguages &&
          other.accessType == accessType &&
          other.visibility == visibility &&
          other.enrolled == enrolled &&
          other.ownerDisplayName == ownerDisplayName &&
          other.releaseId == releaseId &&
          other.tests == tests;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      (description == null ? 0 : description.hashCode) +
      targetLanguage.hashCode +
      supportLanguages.hashCode +
      accessType.hashCode +
      visibility.hashCode +
      enrolled.hashCode +
      ownerDisplayName.hashCode +
      releaseId.hashCode +
      tests.hashCode;

  factory CourseDetail.fromJson(Map<String, dynamic> json) =>
      _$CourseDetailFromJson(json);

  Map<String, dynamic> toJson() => _$CourseDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CourseDetailAccessTypeEnum {
  @JsonValue(r'FREE')
  FREE(r'FREE'),
  @JsonValue(r'PAID')
  PAID(r'PAID');

  const CourseDetailAccessTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseDetailVisibilityEnum {
  @JsonValue(r'PUBLIC')
  PUBLIC(r'PUBLIC'),
  @JsonValue(r'PRIVATE')
  PRIVATE(r'PRIVATE');

  const CourseDetailVisibilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
