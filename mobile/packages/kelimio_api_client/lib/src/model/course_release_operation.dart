//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum CourseReleaseOperation {
  @JsonValue(r'INITIAL_PUBLICATION')
  INITIAL_PUBLICATION(r'INITIAL_PUBLICATION'),
  @JsonValue(r'PUBLICATION')
  PUBLICATION(r'PUBLICATION'),
  @JsonValue(r'ROLLBACK')
  ROLLBACK(r'ROLLBACK');

  const CourseReleaseOperation(this.value);

  final String value;

  @override
  String toString() => value;
}
