//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum AttemptState {
  @JsonValue(r'IN_PROGRESS')
  IN_PROGRESS(r'IN_PROGRESS'),
  @JsonValue(r'COMPLETED_PASS')
  COMPLETED_PASS(r'COMPLETED_PASS'),
  @JsonValue(r'COMPLETED_FAIL')
  COMPLETED_FAIL(r'COMPLETED_FAIL'),
  @JsonValue(r'INTERRUPTED_ENERGY')
  INTERRUPTED_ENERGY(r'INTERRUPTED_ENERGY');

  const AttemptState(this.value);

  final String value;

  @override
  String toString() => value;
}
