//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_summary.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_page.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CoursePage {
  /// Returns a new [CoursePage] instance.
  CoursePage({required this.items, this.nextCursor});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<CourseSummary> items;

  @JsonKey(name: r'nextCursor', required: false, includeIfNull: false)
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoursePage &&
          other.items == items &&
          other.nextCursor == nextCursor;

  @override
  int get hashCode =>
      items.hashCode + (nextCursor == null ? 0 : nextCursor.hashCode);

  factory CoursePage.fromJson(Map<String, dynamic> json) =>
      _$CoursePageFromJson(json);

  Map<String, dynamic> toJson() => _$CoursePageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
