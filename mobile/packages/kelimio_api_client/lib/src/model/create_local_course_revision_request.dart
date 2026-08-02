//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'create_local_course_revision_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateLocalCourseRevisionRequest {
  /// Returns a new [CreateLocalCourseRevisionRequest] instance.
  CreateLocalCourseRevisionRequest({required this.baseReleaseId});

  @JsonKey(name: r'baseReleaseId', required: true, includeIfNull: false)
  final String baseReleaseId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateLocalCourseRevisionRequest &&
          other.baseReleaseId == baseReleaseId;

  @override
  int get hashCode => baseReleaseId.hashCode;

  factory CreateLocalCourseRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateLocalCourseRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateLocalCourseRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
