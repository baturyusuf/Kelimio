//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'session_revocation.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionRevocation {
  /// Returns a new [SessionRevocation] instance.
  SessionRevocation({required this.revokedAt});

  @JsonKey(name: r'revokedAt', required: true, includeIfNull: false)
  final DateTime revokedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRevocation && other.revokedAt == revokedAt;

  @override
  int get hashCode => revokedAt.hashCode;

  factory SessionRevocation.fromJson(Map<String, dynamic> json) =>
      _$SessionRevocationFromJson(json);

  Map<String, dynamic> toJson() => _$SessionRevocationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
