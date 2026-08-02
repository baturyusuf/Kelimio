//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_preview_row.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_preview_page.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPreviewPage {
  /// Returns a new [CourseImportPreviewPage] instance.
  CourseImportPreviewPage({required this.items, this.nextCursor});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<CourseImportPreviewRow> items;

  @JsonKey(name: r'nextCursor', required: false, includeIfNull: false)
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPreviewPage &&
          other.items == items &&
          other.nextCursor == nextCursor;

  @override
  int get hashCode =>
      items.hashCode + (nextCursor == null ? 0 : nextCursor.hashCode);

  factory CourseImportPreviewPage.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPreviewPageFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPreviewPageToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'items')) {
      json[r'items'] = '[REDACTED]';
    }
    if (json.containsKey(r'nextCursor')) {
      json[r'nextCursor'] = '[REDACTED]';
    }
    return json.toString();
  }
}
