//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_part_headers.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_presigned_part.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPresignedPart {
  /// Returns a new [CourseImportPresignedPart] instance.
  CourseImportPresignedPart({
    required this.partNumber,

    required this.sizeBytes,

    required this.url,

    required this.requiredHeaders,
  });

  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'partNumber', required: true, includeIfNull: false)
  final int partNumber;

  // minimum: 1
  // maximum: 5242880
  @JsonKey(name: r'sizeBytes', required: true, includeIfNull: false)
  final int sizeBytes;

  @JsonKey(name: r'url', required: true, includeIfNull: false)
  final String url;

  @JsonKey(name: r'requiredHeaders', required: true, includeIfNull: false)
  final CourseImportPartHeaders requiredHeaders;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPresignedPart &&
          other.partNumber == partNumber &&
          other.sizeBytes == sizeBytes &&
          other.url == url &&
          other.requiredHeaders == requiredHeaders;

  @override
  int get hashCode =>
      partNumber.hashCode +
      sizeBytes.hashCode +
      url.hashCode +
      requiredHeaders.hashCode;

  factory CourseImportPresignedPart.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPresignedPartFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPresignedPartToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'url')) {
      json[r'url'] = '[REDACTED]';
    }
    if (json.containsKey(r'requiredHeaders')) {
      json[r'requiredHeaders'] = '[REDACTED]';
    }
    return json.toString();
  }
}
