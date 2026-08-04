//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_part_headers.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPartHeaders {
  /// Returns a new [CourseImportPartHeaders] instance.
  CourseImportPartHeaders({required this.contentLength, required this.sha256});

  /// Exact decimal Content-Length header value.
  @JsonKey(name: r'contentLength', required: true, includeIfNull: false)
  final String contentLength;

  @JsonKey(name: r'sha256', required: true, includeIfNull: false)
  final String sha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPartHeaders &&
          other.contentLength == contentLength &&
          other.sha256 == sha256;

  @override
  int get hashCode => contentLength.hashCode + sha256.hashCode;

  factory CourseImportPartHeaders.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPartHeadersFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPartHeadersToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'sha256')) {
      json[r'sha256'] = '[REDACTED]';
    }
    return json.toString();
  }
}
