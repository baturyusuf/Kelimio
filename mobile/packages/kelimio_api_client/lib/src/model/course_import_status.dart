//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

enum CourseImportStatus {
  @JsonValue(r'UPLOADING')
  UPLOADING(r'UPLOADING'),
  @JsonValue(r'QUEUED')
  QUEUED(r'QUEUED'),
  @JsonValue(r'PROCESSING')
  PROCESSING(r'PROCESSING'),
  @JsonValue(r'PREVIEW_READY')
  PREVIEW_READY(r'PREVIEW_READY'),
  @JsonValue(r'VALIDATION_FAILED')
  VALIDATION_FAILED(r'VALIDATION_FAILED'),
  @JsonValue(r'MALWARE_REJECTED')
  MALWARE_REJECTED(r'MALWARE_REJECTED'),
  @JsonValue(r'PROCESSING_FAILED')
  PROCESSING_FAILED(r'PROCESSING_FAILED'),
  @JsonValue(r'EXPIRED')
  EXPIRED(r'EXPIRED'),
  @JsonValue(r'APPROVED')
  APPROVED(r'APPROVED');

  const CourseImportStatus(this.value);

  final String value;

  @override
  String toString() => value;
}
