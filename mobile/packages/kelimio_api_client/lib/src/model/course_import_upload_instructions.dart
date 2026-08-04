//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_presigned_part.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_upload_instructions.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportUploadInstructions {
  /// Returns a new [CourseImportUploadInstructions] instance.
  CourseImportUploadInstructions({
    required this.expiresAt,

    required this.parts,
  });

  /// Earliest exact expiry among the signed part-upload URLs in this response; no URL in the response remains valid after this instant. This can be earlier than the import session's uploadExpiresAt value.
  @JsonKey(name: r'expiresAt', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'parts', required: true, includeIfNull: false)
  final List<CourseImportPresignedPart> parts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportUploadInstructions &&
          other.expiresAt == expiresAt &&
          other.parts == parts;

  @override
  int get hashCode => expiresAt.hashCode + parts.hashCode;

  factory CourseImportUploadInstructions.fromJson(Map<String, dynamic> json) =>
      _$CourseImportUploadInstructionsFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportUploadInstructionsToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'parts')) {
      json[r'parts'] = '[REDACTED]';
    }
    return json.toString();
  }
}
