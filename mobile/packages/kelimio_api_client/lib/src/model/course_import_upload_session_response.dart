//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_upload_instructions.dart';
import 'package:kelimio_api_client/src/model/course_import_status_response.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_upload_session_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportUploadSessionResponse {
  /// Returns a new [CourseImportUploadSessionResponse] instance.
  CourseImportUploadSessionResponse({
    required this.created,

    required this.import_,

    required this.upload,
  });

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @JsonKey(name: r'import', required: true, includeIfNull: false)
  final CourseImportStatusResponse import_;

  @JsonKey(name: r'upload', required: true, includeIfNull: true)
  final CourseImportUploadInstructions? upload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportUploadSessionResponse &&
          other.created == created &&
          other.import_ == import_ &&
          other.upload == upload;

  @override
  int get hashCode =>
      created.hashCode +
      import_.hashCode +
      (upload == null ? 0 : upload.hashCode);

  factory CourseImportUploadSessionResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$CourseImportUploadSessionResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CourseImportUploadSessionResponseToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'import')) {
      json[r'import'] = '[REDACTED]';
    }
    if (json.containsKey(r'upload')) {
      json[r'upload'] = '[REDACTED]';
    }
    return json.toString();
  }
}
