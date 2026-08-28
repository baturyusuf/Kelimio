// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_release_abandonment_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseReleaseAbandonmentResponse _$CourseReleaseAbandonmentResponseFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('CourseReleaseAbandonmentResponse', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'abandonmentId',
          'courseId',
          'releaseId',
          'releaseRevision',
          'abandonedAt',
          'created',
        ],
      );
      final val = CourseReleaseAbandonmentResponse(
        abandonmentId: $checkedConvert('abandonmentId', (v) => v as String),
        courseId: $checkedConvert('courseId', (v) => v as String),
        releaseId: $checkedConvert('releaseId', (v) => v as String),
        releaseRevision: $checkedConvert(
          'releaseRevision',
          (v) => (v as num).toInt(),
        ),
        abandonedAt: $checkedConvert(
          'abandonedAt',
          (v) => DateTime.parse(v as String),
        ),
        created: $checkedConvert('created', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$CourseReleaseAbandonmentResponseToJson(
  CourseReleaseAbandonmentResponse instance,
) => <String, dynamic>{
  'abandonmentId': instance.abandonmentId,
  'courseId': instance.courseId,
  'releaseId': instance.releaseId,
  'releaseRevision': instance.releaseRevision,
  'abandonedAt': instance.abandonedAt.toIso8601String(),
  'created': instance.created,
};
