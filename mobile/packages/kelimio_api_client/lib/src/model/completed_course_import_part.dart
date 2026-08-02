//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'completed_course_import_part.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CompletedCourseImportPart {
  /// Returns a new [CompletedCourseImportPart] instance.
  CompletedCourseImportPart({
    required this.partNumber,

    required this.eTag,

    required this.sha256,
  });

  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'partNumber', required: true, includeIfNull: false)
  final int partNumber;

  @JsonKey(name: r'eTag', required: true, includeIfNull: false)
  final String eTag;

  @JsonKey(name: r'sha256', required: true, includeIfNull: false)
  final String sha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedCourseImportPart &&
          other.partNumber == partNumber &&
          other.eTag == eTag &&
          other.sha256 == sha256;

  @override
  int get hashCode => partNumber.hashCode + eTag.hashCode + sha256.hashCode;

  factory CompletedCourseImportPart.fromJson(Map<String, dynamic> json) =>
      _$CompletedCourseImportPartFromJson(json);

  Map<String, dynamic> toJson() => _$CompletedCourseImportPartToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'eTag')) {
      json[r'eTag'] = '[REDACTED]';
    }
    if (json.containsKey(r'sha256')) {
      json[r'sha256'] = '[REDACTED]';
    }
    return json.toString();
  }
}
