//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'answer_option.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AnswerOption {
  /// Returns a new [AnswerOption] instance.
  AnswerOption({required this.id, required this.text});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerOption && other.id == id && other.text == text;

  @override
  int get hashCode => id.hashCode + text.hashCode;

  factory AnswerOption.fromJson(Map<String, dynamic> json) =>
      _$AnswerOptionFromJson(json);

  Map<String, dynamic> toJson() => _$AnswerOptionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
