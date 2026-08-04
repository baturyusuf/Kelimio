//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'problem.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Problem {
  /// Returns a new [Problem] instance.
  Problem({
    required this.type,

    required this.title,

    required this.status,

    this.detail,

    this.instance,

    this.code,

    this.requestId,
  });

  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  // minimum: 400
  // maximum: 599
  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final int status;

  @JsonKey(name: r'detail', required: false, includeIfNull: false)
  final String? detail;

  @JsonKey(name: r'instance', required: false, includeIfNull: false)
  final String? instance;

  @JsonKey(name: r'code', required: false, includeIfNull: false)
  final String? code;

  @JsonKey(name: r'requestId', required: false, includeIfNull: false)
  final String? requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Problem &&
          other.type == type &&
          other.title == title &&
          other.status == status &&
          other.detail == detail &&
          other.instance == instance &&
          other.code == code &&
          other.requestId == requestId;

  @override
  int get hashCode =>
      type.hashCode +
      title.hashCode +
      status.hashCode +
      detail.hashCode +
      instance.hashCode +
      code.hashCode +
      requestId.hashCode;

  factory Problem.fromJson(Map<String, dynamic> json) =>
      _$ProblemFromJson(json);

  Map<String, dynamic> toJson() => _$ProblemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
