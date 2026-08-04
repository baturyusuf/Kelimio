//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_source.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportSource {
  /// Returns a new [CourseImportSource] instance.
  CourseImportSource({
    required this.sheetOrdinal,

    required this.sheetName,

    required this.rowNumber,

    required this.columnNumber,

    required this.reference,
  });

  // minimum: 0
  // maximum: 63
  @JsonKey(name: r'sheetOrdinal', required: true, includeIfNull: false)
  final int sheetOrdinal;

  @JsonKey(name: r'sheetName', required: true, includeIfNull: false)
  final String sheetName;

  // minimum: 1
  // maximum: 1048576
  @JsonKey(name: r'rowNumber', required: true, includeIfNull: false)
  final int rowNumber;

  // minimum: 1
  // maximum: 64
  @JsonKey(name: r'columnNumber', required: true, includeIfNull: true)
  final int? columnNumber;

  @JsonKey(name: r'reference', required: true, includeIfNull: true)
  final String? reference;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportSource &&
          other.sheetOrdinal == sheetOrdinal &&
          other.sheetName == sheetName &&
          other.rowNumber == rowNumber &&
          other.columnNumber == columnNumber &&
          other.reference == reference;

  @override
  int get hashCode =>
      sheetOrdinal.hashCode +
      sheetName.hashCode +
      rowNumber.hashCode +
      (columnNumber == null ? 0 : columnNumber.hashCode) +
      (reference == null ? 0 : reference.hashCode);

  factory CourseImportSource.fromJson(Map<String, dynamic> json) =>
      _$CourseImportSourceFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportSourceToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'sheetName')) {
      json[r'sheetName'] = '[REDACTED]';
    }
    if (json.containsKey(r'reference')) {
      json[r'reference'] = '[REDACTED]';
    }
    return json.toString();
  }
}
