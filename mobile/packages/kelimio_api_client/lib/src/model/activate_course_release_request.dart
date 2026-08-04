//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'activate_course_release_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ActivateCourseReleaseRequest {
  /// Returns a new [ActivateCourseReleaseRequest] instance.
  ActivateCourseReleaseRequest({
    required this.expectedActiveReleaseId,

    required this.impactBindingSha256,
  });

  @JsonKey(
    name: r'expectedActiveReleaseId',
    required: true,
    includeIfNull: true,
  )
  final String? expectedActiveReleaseId;

  @JsonKey(name: r'impactBindingSha256', required: true, includeIfNull: false)
  final String impactBindingSha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivateCourseReleaseRequest &&
          other.expectedActiveReleaseId == expectedActiveReleaseId &&
          other.impactBindingSha256 == impactBindingSha256;

  @override
  int get hashCode =>
      (expectedActiveReleaseId == null ? 0 : expectedActiveReleaseId.hashCode) +
      impactBindingSha256.hashCode;

  factory ActivateCourseReleaseRequest.fromJson(Map<String, dynamic> json) =>
      _$ActivateCourseReleaseRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ActivateCourseReleaseRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
