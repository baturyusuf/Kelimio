//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'approve_course_import_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ApproveCourseImportRequest {
  /// Returns a new [ApproveCourseImportRequest] instance.
  ApproveCourseImportRequest({required this.approvalBindingSha256});

  @JsonKey(name: r'approvalBindingSha256', required: true, includeIfNull: false)
  final String approvalBindingSha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApproveCourseImportRequest &&
          other.approvalBindingSha256 == approvalBindingSha256;

  @override
  int get hashCode => approvalBindingSha256.hashCode;

  factory ApproveCourseImportRequest.fromJson(Map<String, dynamic> json) =>
      _$ApproveCourseImportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ApproveCourseImportRequestToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'approvalBindingSha256')) {
      json[r'approvalBindingSha256'] = '[REDACTED]';
    }
    return json.toString();
  }
}
