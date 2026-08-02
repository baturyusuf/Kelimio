//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_part_declaration.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_course_import_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCourseImportRequest {
  /// Returns a new [CreateCourseImportRequest] instance.
  CreateCourseImportRequest({
    required this.originalFileName,

    required this.declaredMediaType,

    required this.fileSizeBytes,

    required this.sourceSha256,

    required this.parts,
  });

  @JsonKey(name: r'originalFileName', required: true, includeIfNull: false)
  final String originalFileName;

  @JsonKey(name: r'declaredMediaType', required: true, includeIfNull: false)
  final CreateCourseImportRequestDeclaredMediaTypeEnum declaredMediaType;

  // minimum: 1
  // maximum: 26214400
  @JsonKey(name: r'fileSizeBytes', required: true, includeIfNull: false)
  final int fileSizeBytes;

  @JsonKey(name: r'sourceSha256', required: true, includeIfNull: false)
  final String sourceSha256;

  @JsonKey(name: r'parts', required: true, includeIfNull: false)
  final List<CourseImportPartDeclaration> parts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCourseImportRequest &&
          other.originalFileName == originalFileName &&
          other.declaredMediaType == declaredMediaType &&
          other.fileSizeBytes == fileSizeBytes &&
          other.sourceSha256 == sourceSha256 &&
          other.parts == parts;

  @override
  int get hashCode =>
      originalFileName.hashCode +
      declaredMediaType.hashCode +
      fileSizeBytes.hashCode +
      sourceSha256.hashCode +
      parts.hashCode;

  factory CreateCourseImportRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCourseImportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateCourseImportRequestToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'originalFileName')) {
      json[r'originalFileName'] = '[REDACTED]';
    }
    if (json.containsKey(r'sourceSha256')) {
      json[r'sourceSha256'] = '[REDACTED]';
    }
    if (json.containsKey(r'parts')) {
      json[r'parts'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CreateCourseImportRequestDeclaredMediaTypeEnum {
  @JsonValue(
    r'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  )
  applicationSlashVndPeriodOpenxmlformatsOfficedocumentPeriodSpreadsheetmlPeriodSheet(
    r'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const CreateCourseImportRequestDeclaredMediaTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
