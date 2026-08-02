package com.kelimio.api.persistence

import org.jooq.JSONB
import org.jooq.impl.DSL.field
import org.jooq.impl.DSL.name
import org.jooq.impl.DSL.table
import java.math.BigDecimal
import java.time.LocalDate
import java.time.OffsetDateTime
import java.util.UUID

object Users {
    val TABLE = table(name("app_user"))
    val ID = field(name("app_user", "id"), UUID::class.java)
    val SUBJECT = field(name("app_user", "oidc_subject"), String::class.java)
    val EMAIL = field(name("app_user", "email"), String::class.java)
    val DISPLAY_NAME = field(name("app_user", "display_name"), String::class.java)
    val USERNAME = field(name("app_user", "username"), String::class.java)
    val APP_LOCALE = field(name("app_user", "app_locale"), String::class.java)
    val ACTIVE_TARGET_LANGUAGE = field(name("app_user", "active_target_language"), String::class.java)
    val PREFERRED_SUPPORT_LANGUAGE = field(name("app_user", "preferred_support_language"), String::class.java)
    val TIME_ZONE = field(name("app_user", "time_zone"), String::class.java)
    val PROFILE_SETUP_COMPLETED_AT = field(name("app_user", "profile_setup_completed_at"), OffsetDateTime::class.java)
    val PROFILE_VERSION = field(name("app_user", "profile_version"), Long::class.java)
    val CREATED_AT = field(name("app_user", "created_at"), OffsetDateTime::class.java)
    val UPDATED_AT = field(name("app_user", "updated_at"), OffsetDateTime::class.java)
}

object IdentityProfileEvents {
    val TABLE = table(name("identity_profile_event"))
    val ID = field(name("identity_profile_event", "id"), UUID::class.java)
    val USER_ID = field(name("identity_profile_event", "user_id"), UUID::class.java)
    val EVENT_TYPE = field(name("identity_profile_event", "event_type"), String::class.java)
    val PROFILE_VERSION = field(name("identity_profile_event", "profile_version"), Long::class.java)
    val CHANGED_FIELDS = field(name("identity_profile_event", "changed_fields"), Array<String>::class.java)
    val OCCURRED_AT = field(name("identity_profile_event", "occurred_at"), OffsetDateTime::class.java)
    val CORRELATION_ID = field(name("identity_profile_event", "correlation_id"), String::class.java)
}

object Courses {
    val TABLE = table(name("course"))
    val ID = field(name("course", "id"), UUID::class.java)
    val OWNER_ID = field(name("course", "owner_user_id"), UUID::class.java)
    val NAME = field(name("course", "name"), String::class.java)
    val DESCRIPTION = field(name("course", "description"), String::class.java)
    val TARGET_LANGUAGE = field(name("course", "target_language"), String::class.java)
    val DEFAULT_SUPPORT_LANGUAGE = field(name("course", "default_support_language"), String::class.java)
    val VISIBILITY = field(name("course", "visibility"), String::class.java)
    val STATUS = field(name("course", "publication_status"), String::class.java)
    val ACCESS_TYPE = field(name("course", "access_type"), String::class.java)
    val ACTIVE_RELEASE_ID = field(name("course", "active_release_id"), UUID::class.java)
    val CREATED_AT = field(name("course", "created_at"), OffsetDateTime::class.java)
}

object CourseReleases {
    val TABLE = table(name("course_release"))
    val ID = field(name("course_release", "id"), UUID::class.java)
    val COURSE_ID = field(name("course_release", "course_id"), UUID::class.java)
    val REVISION_NUMBER = field(name("course_release", "revision_number"), Int::class.java)
    val STATUS = field(name("course_release", "status"), String::class.java)
    val CREATED_AT = field(name("course_release", "created_at"), OffsetDateTime::class.java)
}

object CourseReleaseTestRevisions {
    val TABLE = table(name("course_release_test_revision"))
    val COURSE_RELEASE_ID = field(name("course_release_test_revision", "course_release_id"), UUID::class.java)
    val TEST_REVISION_ID = field(name("course_release_test_revision", "test_revision_id"), UUID::class.java)
    val TEST_ID = field(name("course_release_test_revision", "test_id"), UUID::class.java)
    val COURSE_ID = field(name("course_release_test_revision", "course_id"), UUID::class.java)
    val POSITION = field(name("course_release_test_revision", "position"), Int::class.java)
}

object CourseSupportLanguages {
    val TABLE = table(name("course_support_language"))
    val COURSE_ID = field(name("course_support_language", "course_id"), UUID::class.java)
    val LANGUAGE_CODE = field(name("course_support_language", "language_code"), String::class.java)
}

object Enrollments {
    val TABLE = table(name("enrollment"))
    val ID = field(name("enrollment", "id"), UUID::class.java)
    val COURSE_ID = field(name("enrollment", "course_id"), UUID::class.java)
    val USER_ID = field(name("enrollment", "user_id"), UUID::class.java)
    val SUPPORT_LANGUAGE = field(name("enrollment", "support_language"), String::class.java)
    val STATUS = field(name("enrollment", "status"), String::class.java)
    val ENROLLED_AT = field(name("enrollment", "enrolled_at"), OffsetDateTime::class.java)
}

object CourseTests {
    val TABLE = table(name("course_test"))
    val ID = field(name("course_test", "id"), UUID::class.java)
    val COURSE_ID = field(name("course_test", "course_id"), UUID::class.java)
}

object TestRevisions {
    val TABLE = table(name("test_revision"))
    val ID = field(name("test_revision", "id"), UUID::class.java)
    val TEST_ID = field(name("test_revision", "test_id"), UUID::class.java)
    val COURSE_ID = field(name("test_revision", "course_id"), UUID::class.java)
    val REVISION_NUMBER = field(name("test_revision", "revision_number"), Int::class.java)
    val TITLE = field(name("test_revision", "title"), String::class.java)
    val STATUS = field(name("test_revision", "status"), String::class.java)
    val PASS_THRESHOLD = field(name("test_revision", "pass_threshold"), BigDecimal::class.java)
}

object QuestionRevisions {
    val TABLE = table(name("question_revision"))
    val ID = field(name("question_revision", "id"), UUID::class.java)
    val QUESTION_ID = field(name("question_revision", "question_id"), UUID::class.java)
    val COURSE_ID = field(name("question_revision", "course_id"), UUID::class.java)
    val TYPE = field(name("question_revision", "question_type"), String::class.java)
    val PROMPT = field(name("question_revision", "prompt"), String::class.java)
    val CORRECT_ANSWER = field(name("question_revision", "correct_answer"), String::class.java)
    val ALTERNATIVE_CORRECT_ANSWER =
        field(name("question_revision", "alternative_correct_answer"), String::class.java)
    val ANSWER_MATCH_POLICY = field(name("question_revision", "answer_match_policy"), String::class.java)
    val ANSWER_MATCH_LANGUAGE = field(name("question_revision", "answer_match_language"), String::class.java)
    val CORRECT_ANSWER_MATCH_KEY = field(name("question_revision", "correct_answer_match_key"), String::class.java)
    val ALTERNATIVE_ANSWER_MATCH_KEY =
        field(name("question_revision", "alternative_answer_match_key"), String::class.java)
    val STATUS = field(name("question_revision", "status"), String::class.java)
}

object QuestionRevisionOptions {
    val TABLE = table(name("question_revision_option"))
    val ID = field(name("question_revision_option", "id"), UUID::class.java)
    val QUESTION_REVISION_ID = field(name("question_revision_option", "question_revision_id"), UUID::class.java)
    val TEXT = field(name("question_revision_option", "option_text"), String::class.java)
    val IS_CORRECT = field(name("question_revision_option", "is_correct"), Boolean::class.java)
    val POSITION = field(name("question_revision_option", "position"), Int::class.java)
}

object TestRevisionQuestions {
    val TABLE = table(name("test_revision_question"))
    val TEST_REVISION_ID = field(name("test_revision_question", "test_revision_id"), UUID::class.java)
    val QUESTION_REVISION_ID = field(name("test_revision_question", "question_revision_id"), UUID::class.java)
    val QUESTION_ID = field(name("test_revision_question", "question_id"), UUID::class.java)
    val COURSE_ID = field(name("test_revision_question", "course_id"), UUID::class.java)
    val POSITION = field(name("test_revision_question", "position"), Int::class.java)
}

object Attempts {
    val TABLE = table(name("test_attempt"))
    val ID = field(name("test_attempt", "id"), UUID::class.java)
    val USER_ID = field(name("test_attempt", "user_id"), UUID::class.java)
    val COURSE_ID = field(name("test_attempt", "course_id"), UUID::class.java)
    val COURSE_RELEASE_ID = field(name("test_attempt", "course_release_id"), UUID::class.java)
    val COURSE_ACCESS_TYPE = field(name("test_attempt", "course_access_type"), String::class.java)
    val TEST_REVISION_ID = field(name("test_attempt", "test_revision_id"), UUID::class.java)
    val STATUS = field(name("test_attempt", "status"), String::class.java)
    val SHUFFLE_SEED = field(name("test_attempt", "shuffle_seed"), Long::class.java)
    val TOTAL_QUESTIONS = field(name("test_attempt", "total_questions"), Int::class.java)
    val ANSWERED_COUNT = field(name("test_attempt", "answered_count"), Int::class.java)
    val CORRECT_COUNT = field(name("test_attempt", "correct_count"), Int::class.java)
    val STARTED_AT = field(name("test_attempt", "started_at"), OffsetDateTime::class.java)
    val FINISHED_AT = field(name("test_attempt", "finished_at"), OffsetDateTime::class.java)
    val VERSION = field(name("test_attempt", "version"), Long::class.java)
}

object AttemptManifest {
    val TABLE = table(name("attempt_question_manifest"))
    val ATTEMPT_ID = field(name("attempt_question_manifest", "attempt_id"), UUID::class.java)
    val TEST_REVISION_ID = field(name("attempt_question_manifest", "test_revision_id"), UUID::class.java)
    val COURSE_ID = field(name("attempt_question_manifest", "course_id"), UUID::class.java)
    val QUESTION_REVISION_ID = field(name("attempt_question_manifest", "question_revision_id"), UUID::class.java)
    val POSITION = field(name("attempt_question_manifest", "position"), Int::class.java)
}

object AnswerSubmissions {
    val TABLE = table(name("answer_submission"))
    val SUBMISSION_ID = field(name("answer_submission", "submission_id"), UUID::class.java)
    val ATTEMPT_ID = field(name("answer_submission", "attempt_id"), UUID::class.java)
    val USER_ID = field(name("answer_submission", "user_id"), UUID::class.java)
    val QUESTION_REVISION_ID = field(name("answer_submission", "question_revision_id"), UUID::class.java)
    val SELECTED_OPTION_ID = field(name("answer_submission", "selected_option_id"), UUID::class.java)
    val ANSWER_KIND = field(name("answer_submission", "answer_kind"), String::class.java)
    val TYPED_ANSWER_SALT = field(name("answer_submission", "typed_answer_salt"), ByteArray::class.java)
    val TYPED_ANSWER_DIGEST = field(name("answer_submission", "typed_answer_digest"), ByteArray::class.java)
    val TYPED_MATCH_ORDINAL = field(name("answer_submission", "typed_match_ordinal"), Short::class.java)
    val IS_CORRECT = field(name("answer_submission", "is_correct"), Boolean::class.java)
    val ACTIVE_DELTA = field(name("answer_submission", "active_score_delta"), Short::class.java)
    val LIFETIME_DELTA = field(name("answer_submission", "lifetime_score_delta"), Short::class.java)
    val ACTIVE_QUESTION_SCORE = field(name("answer_submission", "active_question_score"), Short::class.java)
    val LIFETIME_SCORE = field(name("answer_submission", "lifetime_score"), Long::class.java)
    val ENERGY_AFTER = field(name("answer_submission", "energy_balance_after"), Short::class.java)
    val ENERGY_UNLIMITED = field(name("answer_submission", "energy_unlimited"), Boolean::class.java)
    val ENERGY_NEXT_REGENERATION_AT =
        field(name("answer_submission", "energy_next_regeneration_at"), OffsetDateTime::class.java)
    val ATTEMPT_STATUS_AFTER = field(name("answer_submission", "attempt_status_after"), String::class.java)
    val SUBMITTED_AT = field(name("answer_submission", "submitted_at"), OffsetDateTime::class.java)
}

object AttemptEvents {
    val TABLE = table(name("attempt_event"))
    val ID = field(name("attempt_event", "id"), UUID::class.java)
    val ATTEMPT_ID = field(name("attempt_event", "attempt_id"), UUID::class.java)
    val SUBMISSION_ID = field(name("attempt_event", "submission_id"), UUID::class.java)
    val EVENT_TYPE = field(name("attempt_event", "event_type"), String::class.java)
    val PAYLOAD = field(name("attempt_event", "payload"), JSONB::class.java)
    val OCCURRED_AT = field(name("attempt_event", "occurred_at"), OffsetDateTime::class.java)
}

object QuestionMasteries {
    val TABLE = table(name("question_mastery"))
    val USER_ID = field(name("question_mastery", "user_id"), UUID::class.java)
    val QUESTION_REVISION_ID = field(name("question_mastery", "question_revision_id"), UUID::class.java)
    val ACTIVE_SCORE = field(name("question_mastery", "active_score"), Short::class.java)
    val ENCOUNTER_COUNT = field(name("question_mastery", "encounter_count"), Int::class.java)
    val CORRECT_COUNT = field(name("question_mastery", "correct_count"), Int::class.java)
    val VERSION = field(name("question_mastery", "version"), Long::class.java)
    val LAST_ANSWERED_AT = field(name("question_mastery", "last_answered_at"), OffsetDateTime::class.java)
}

object ScoreEvents {
    val TABLE = table(name("score_event"))
    val ID = field(name("score_event", "id"), UUID::class.java)
    val USER_ID = field(name("score_event", "user_id"), UUID::class.java)
    val ATTEMPT_ID = field(name("score_event", "attempt_id"), UUID::class.java)
    val SUBMISSION_ID = field(name("score_event", "submission_id"), UUID::class.java)
    val QUESTION_REVISION_ID = field(name("score_event", "question_revision_id"), UUID::class.java)
    val ACTIVE_DELTA = field(name("score_event", "active_delta"), Short::class.java)
    val LIFETIME_DELTA = field(name("score_event", "lifetime_delta"), Short::class.java)
    val OCCURRED_AT = field(name("score_event", "occurred_at"), OffsetDateTime::class.java)
}

object EnergyAccounts {
    val TABLE = table(name("energy_account"))
    val USER_ID = field(name("energy_account", "user_id"), UUID::class.java)
    val BALANCE = field(name("energy_account", "balance"), Short::class.java)
    val ANCHOR_AT = field(name("energy_account", "regeneration_anchor_at"), OffsetDateTime::class.java)
    val VERSION = field(name("energy_account", "version"), Long::class.java)
}

object EnergyEvents {
    val TABLE = table(name("energy_event"))
    val ID = field(name("energy_event", "id"), UUID::class.java)
    val USER_ID = field(name("energy_event", "user_id"), UUID::class.java)
    val ATTEMPT_ID = field(name("energy_event", "attempt_id"), UUID::class.java)
    val SUBMISSION_ID = field(name("energy_event", "submission_id"), UUID::class.java)
    val EVENT_TYPE = field(name("energy_event", "event_type"), String::class.java)
    val DELTA = field(name("energy_event", "delta"), Short::class.java)
    val BALANCE_BEFORE = field(name("energy_event", "balance_before"), Short::class.java)
    val BALANCE_AFTER = field(name("energy_event", "balance_after"), Short::class.java)
    val OCCURRED_AT = field(name("energy_event", "occurred_at"), OffsetDateTime::class.java)
}

object StreakDays {
    val TABLE = table(name("streak_day"))
    val USER_ID = field(name("streak_day", "user_id"), UUID::class.java)
    val LOCAL_DATE = field(name("streak_day", "local_date"), LocalDate::class.java)
    val TIME_ZONE = field(name("streak_day", "time_zone"), String::class.java)
    val ATTEMPT_ID = field(name("streak_day", "qualifying_attempt_id"), UUID::class.java)
    val CREATED_AT = field(name("streak_day", "created_at"), OffsetDateTime::class.java)
}

object OutboxEvents {
    val TABLE = table(name("outbox_event"))
    val ID = field(name("outbox_event", "id"), UUID::class.java)
    val AGGREGATE_TYPE = field(name("outbox_event", "aggregate_type"), String::class.java)
    val AGGREGATE_ID = field(name("outbox_event", "aggregate_id"), UUID::class.java)
    val EVENT_TYPE = field(name("outbox_event", "event_type"), String::class.java)
    val SCHEMA_VERSION = field(name("outbox_event", "schema_version"), Int::class.java)
    val PAYLOAD = field(name("outbox_event", "payload"), JSONB::class.java)
    val CORRELATION_ID = field(name("outbox_event", "correlation_id"), String::class.java)
    val OCCURRED_AT = field(name("outbox_event", "occurred_at"), OffsetDateTime::class.java)
}

object OutboxDeliveries {
    val TABLE = table(name("outbox_delivery"))
    val EVENT_ID = field(name("outbox_delivery", "event_id"), UUID::class.java)
    val ATTEMPT_COUNT = field(name("outbox_delivery", "attempt_count"), Int::class.java)
}

object CommandIdempotency {
    val TABLE = table(name("command_idempotency"))
    val USER_ID = field(name("command_idempotency", "user_id"), UUID::class.java)
    val OPERATION = field(name("command_idempotency", "operation"), String::class.java)
    val KEY = field(name("command_idempotency", "idempotency_key"), UUID::class.java)
    val FINGERPRINT = field(name("command_idempotency", "request_fingerprint"), String::class.java)
    val RESOURCE_ID = field(name("command_idempotency", "resource_id"), UUID::class.java)
    val CREATED_AT = field(name("command_idempotency", "created_at"), OffsetDateTime::class.java)
}
