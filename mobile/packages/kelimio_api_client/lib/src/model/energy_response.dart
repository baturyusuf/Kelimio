//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'energy_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EnergyResponse {
  /// Returns a new [EnergyResponse] instance.
  EnergyResponse({
    required this.balance,

    required this.maximum,

    required this.unlimited,

    this.nextRegenerationAt,

    required this.asOf,
  });

  // minimum: 0
  // maximum: 5
  @JsonKey(name: r'balance', required: true, includeIfNull: false)
  final int balance;

  @JsonKey(name: r'maximum', required: true, includeIfNull: false)
  final EnergyResponseMaximumEnum maximum;

  @JsonKey(name: r'unlimited', required: true, includeIfNull: false)
  final bool unlimited;

  @JsonKey(name: r'nextRegenerationAt', required: false, includeIfNull: false)
  final DateTime? nextRegenerationAt;

  @JsonKey(name: r'asOf', required: true, includeIfNull: false)
  final DateTime asOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergyResponse &&
          other.balance == balance &&
          other.maximum == maximum &&
          other.unlimited == unlimited &&
          other.nextRegenerationAt == nextRegenerationAt &&
          other.asOf == asOf;

  @override
  int get hashCode =>
      balance.hashCode +
      maximum.hashCode +
      unlimited.hashCode +
      (nextRegenerationAt == null ? 0 : nextRegenerationAt.hashCode) +
      asOf.hashCode;

  factory EnergyResponse.fromJson(Map<String, dynamic> json) =>
      _$EnergyResponseFromJson(json);

  Map<String, dynamic> toJson() => _$EnergyResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum EnergyResponseMaximumEnum {
  @JsonValue(5)
  number5('5');

  const EnergyResponseMaximumEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
