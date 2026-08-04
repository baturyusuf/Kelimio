//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/completed_course_import_part.dart';
import 'package:json_annotation/json_annotation.dart';

part 'complete_course_import_upload_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CompleteCourseImportUploadRequest {
  /// Returns a new [CompleteCourseImportUploadRequest] instance.
  CompleteCourseImportUploadRequest({
    required this.sourceSha256,

    required this.parts,
  });

  @JsonKey(name: r'sourceSha256', required: true, includeIfNull: false)
  final String sourceSha256;

  @JsonKey(name: r'parts', required: true, includeIfNull: false)
  final List<CompletedCourseImportPart> parts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompleteCourseImportUploadRequest &&
          other.sourceSha256 == sourceSha256 &&
          other.parts == parts;

  @override
  int get hashCode => sourceSha256.hashCode + parts.hashCode;

  factory CompleteCourseImportUploadRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CompleteCourseImportUploadRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CompleteCourseImportUploadRequestToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'sourceSha256')) {
      json[r'sourceSha256'] = '[REDACTED]';
    }
    if (json.containsKey(r'parts')) {
      json[r'parts'] = '[REDACTED]';
    }
    return json.toString();
  }
}
