//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_part_declaration.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPartDeclaration {
  /// Returns a new [CourseImportPartDeclaration] instance.
  CourseImportPartDeclaration({
    required this.partNumber,

    required this.sizeBytes,

    required this.sha256,
  });

  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'partNumber', required: true, includeIfNull: false)
  final int partNumber;

  // minimum: 1
  // maximum: 5242880
  @JsonKey(name: r'sizeBytes', required: true, includeIfNull: false)
  final int sizeBytes;

  @JsonKey(name: r'sha256', required: true, includeIfNull: false)
  final String sha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPartDeclaration &&
          other.partNumber == partNumber &&
          other.sizeBytes == sizeBytes &&
          other.sha256 == sha256;

  @override
  int get hashCode =>
      partNumber.hashCode + sizeBytes.hashCode + sha256.hashCode;

  factory CourseImportPartDeclaration.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPartDeclarationFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPartDeclarationToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'sha256')) {
      json[r'sha256'] = '[REDACTED]';
    }
    return json.toString();
  }
}
