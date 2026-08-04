//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_status_response.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_status_page.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportStatusPage {
  /// Returns a new [CourseImportStatusPage] instance.
  CourseImportStatusPage({required this.items, required this.nextCursor});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<CourseImportStatusResponse> items;

  @JsonKey(name: r'nextCursor', required: true, includeIfNull: true)
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportStatusPage &&
          other.items == items &&
          other.nextCursor == nextCursor;

  @override
  int get hashCode =>
      items.hashCode + (nextCursor == null ? 0 : nextCursor.hashCode);

  factory CourseImportStatusPage.fromJson(Map<String, dynamic> json) =>
      _$CourseImportStatusPageFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportStatusPageToJson(this);

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
