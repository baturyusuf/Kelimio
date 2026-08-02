package com.kelimio.api.catalog

import com.kelimio.api.persistence.CourseSupportLanguages
import com.kelimio.api.persistence.CourseReleaseTestRevisions
import com.kelimio.api.persistence.CourseTests
import com.kelimio.api.persistence.Courses
import com.kelimio.api.persistence.Enrollments
import com.kelimio.api.persistence.QuestionRevisions
import com.kelimio.api.persistence.QuestionRevisionOptions
import com.kelimio.api.persistence.QuestionRevisionMatchingPairs
import com.kelimio.api.persistence.QuestionRevisionMatchingTranslations
import com.kelimio.api.persistence.TestRevisionQuestions
import com.kelimio.api.persistence.TestRevisions
import com.kelimio.api.persistence.Users
import org.jooq.DSLContext
import org.jooq.impl.DSL.count
import org.jooq.impl.DSL.noCondition
import org.jooq.impl.DSL.selectOne
import org.springframework.stereotype.Repository
import java.time.Clock
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.UUID

@Repository
class CatalogRepository(
    private val dsl: DSLContext,
    private val clock: Clock,
) {
    fun listPublicCourses(
        userId: UUID,
        cursor: UUID?,
        targetLanguage: String?,
        supportLanguage: String?,
        pageSize: Int,
    ): List<CourseSummary> {
        val cursorCondition = cursor?.let { Courses.ID.gt(it) } ?: noCondition()
        val targetCondition = targetLanguage?.let { Courses.TARGET_LANGUAGE.eq(it) } ?: noCondition()
        val supportCondition = supportLanguage?.let { language ->
            org.jooq.impl.DSL.exists(
                selectOne().from(CourseSupportLanguages.TABLE)
                    .where(CourseSupportLanguages.COURSE_ID.eq(Courses.ID))
                    .and(CourseSupportLanguages.LANGUAGE_CODE.eq(language)),
            )
        } ?: noCondition()
        return dsl.select(
            Courses.ID,
            Courses.NAME,
            Courses.DESCRIPTION,
            Courses.TARGET_LANGUAGE,
            Courses.DEFAULT_SUPPORT_LANGUAGE,
            Courses.ACCESS_TYPE,
            Courses.VISIBILITY,
            Courses.ACTIVE_RELEASE_ID,
            Users.DISPLAY_NAME,
        ).from(Courses.TABLE)
            .join(Users.TABLE)
            .on(Users.ID.eq(Courses.OWNER_ID))
            .where(Courses.STATUS.eq("PUBLISHED"))
            .and(Courses.VISIBILITY.eq("PUBLIC"))
            .and(cursorCondition)
            .and(targetCondition)
            .and(supportCondition)
            .orderBy(Courses.ID.asc())
            .limit(pageSize)
            .fetch { record ->
                mapCourse(
                    id = record.get(Courses.ID)!!,
                    name = record.get(Courses.NAME)!!,
                    description = record.get(Courses.DESCRIPTION),
                    targetLanguage = record.get(Courses.TARGET_LANGUAGE)!!,
                    defaultSupportLanguage = record.get(Courses.DEFAULT_SUPPORT_LANGUAGE)!!,
                    accessType = record.get(Courses.ACCESS_TYPE)!!,
                    visibility = record.get(Courses.VISIBILITY)!!,
                    ownerDisplayName = record.get(Users.DISPLAY_NAME)!!,
                    releaseId = record.get(Courses.ACTIVE_RELEASE_ID)!!,
                    enrolled = hasActiveEnrollment(record.get(Courses.ID)!!, userId),
                )
            }
    }

    fun findPublishedCourse(
        courseId: UUID,
        userId: UUID,
    ): CourseSummary? =
        dsl.select(
            Courses.ID,
            Courses.NAME,
            Courses.DESCRIPTION,
            Courses.TARGET_LANGUAGE,
            Courses.DEFAULT_SUPPORT_LANGUAGE,
            Courses.ACCESS_TYPE,
            Courses.VISIBILITY,
            Courses.ACTIVE_RELEASE_ID,
            Users.DISPLAY_NAME,
        ).from(Courses.TABLE)
            .join(Users.TABLE)
            .on(Users.ID.eq(Courses.OWNER_ID))
            .where(Courses.ID.eq(courseId))
            .and(Courses.STATUS.eq("PUBLISHED"))
            .fetchOne { record ->
                mapCourse(
                    id = record.get(Courses.ID)!!,
                    name = record.get(Courses.NAME)!!,
                    description = record.get(Courses.DESCRIPTION),
                    targetLanguage = record.get(Courses.TARGET_LANGUAGE)!!,
                    defaultSupportLanguage = record.get(Courses.DEFAULT_SUPPORT_LANGUAGE)!!,
                    accessType = record.get(Courses.ACCESS_TYPE)!!,
                    visibility = record.get(Courses.VISIBILITY)!!,
                    ownerDisplayName = record.get(Users.DISPLAY_NAME)!!,
                    releaseId = record.get(Courses.ACTIVE_RELEASE_ID)!!,
                    enrolled = hasActiveEnrollment(courseId, userId),
                )
            }

    fun findVisibility(courseId: UUID): String? =
        dsl.select(Courses.VISIBILITY)
            .from(Courses.TABLE)
            .where(Courses.ID.eq(courseId))
            .and(Courses.STATUS.eq("PUBLISHED"))
            .fetchOne(Courses.VISIBILITY)

    fun findActiveTests(courseId: UUID): List<CourseTestSummary> {
        val questionCount = count(TestRevisionQuestions.QUESTION_REVISION_ID)
        return dsl.select(
            CourseTests.ID,
            TestRevisions.ID,
            TestRevisions.TITLE,
            CourseReleaseTestRevisions.POSITION,
            questionCount,
        ).from(Courses.TABLE)
            .join(CourseReleaseTestRevisions.TABLE)
            .on(CourseReleaseTestRevisions.COURSE_RELEASE_ID.eq(Courses.ACTIVE_RELEASE_ID))
            .and(CourseReleaseTestRevisions.COURSE_ID.eq(Courses.ID))
            .join(TestRevisions.TABLE)
            .on(TestRevisions.ID.eq(CourseReleaseTestRevisions.TEST_REVISION_ID))
            .and(TestRevisions.TEST_ID.eq(CourseReleaseTestRevisions.TEST_ID))
            .and(TestRevisions.COURSE_ID.eq(CourseReleaseTestRevisions.COURSE_ID))
            .join(CourseTests.TABLE)
            .on(CourseTests.ID.eq(TestRevisions.TEST_ID))
            .and(CourseTests.COURSE_ID.eq(TestRevisions.COURSE_ID))
            .leftJoin(TestRevisionQuestions.TABLE)
            .on(TestRevisionQuestions.TEST_REVISION_ID.eq(TestRevisions.ID))
            .where(Courses.ID.eq(courseId))
            .and(Courses.STATUS.eq("PUBLISHED"))
            .and(TestRevisions.STATUS.eq("ACTIVE"))
            .groupBy(
                CourseTests.ID,
                TestRevisions.ID,
                TestRevisions.TITLE,
                CourseReleaseTestRevisions.POSITION,
            )
            .having(questionCount.gt(0))
            .orderBy(CourseReleaseTestRevisions.POSITION.asc())
            .fetch {
                CourseTestSummary(
                    id = it.get(CourseTests.ID)!!,
                    revisionId = it.get(TestRevisions.ID)!!,
                    title = it.get(TestRevisions.TITLE)!!,
                    position = it.get(CourseReleaseTestRevisions.POSITION)!!,
                    questionCount = it.get(questionCount),
                )
            }
    }

    fun supportsLanguage(
        courseId: UUID,
        languageCode: String,
    ): Boolean =
        dsl.fetchExists(
            selectOne().from(CourseSupportLanguages.TABLE)
                .where(CourseSupportLanguages.COURSE_ID.eq(courseId))
                .and(CourseSupportLanguages.LANGUAGE_CODE.eq(languageCode)),
        )

    fun createEnrollment(
        courseId: UUID,
        userId: UUID,
        supportLanguage: String,
    ): EnrollmentResult {
        val enrollmentId = UUID.randomUUID()
        val enrolledAt = OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)
        val inserted = dsl.insertInto(Enrollments.TABLE)
            .columns(
                Enrollments.ID,
                Enrollments.COURSE_ID,
                Enrollments.USER_ID,
                Enrollments.SUPPORT_LANGUAGE,
                Enrollments.STATUS,
                Enrollments.ENROLLED_AT,
            )
            .values(
                enrollmentId,
                courseId,
                userId,
                supportLanguage,
                "ACTIVE",
                enrolledAt,
            )
            .onConflict(Enrollments.COURSE_ID, Enrollments.USER_ID)
            .doNothing()
            .execute() == 1

        if (inserted) {
            return EnrollmentResult(enrollmentId, courseId, supportLanguage, "ACTIVE", true, enrolledAt)
        }

        return dsl.select(
            Enrollments.ID,
            Enrollments.SUPPORT_LANGUAGE,
            Enrollments.STATUS,
            Enrollments.ENROLLED_AT,
        )
            .from(Enrollments.TABLE)
            .where(Enrollments.COURSE_ID.eq(courseId))
            .and(Enrollments.USER_ID.eq(userId))
            .fetchOne {
                EnrollmentResult(
                    id = it.get(Enrollments.ID)!!,
                    courseId = courseId,
                    supportLanguage = it.get(Enrollments.SUPPORT_LANGUAGE)!!,
                    status = it.get(Enrollments.STATUS)!!,
                    created = false,
                    enrolledAt = it.get(Enrollments.ENROLLED_AT)!!,
                )
            } ?: error("Enrollment conflict completed without an existing row")
    }

    fun hasActiveEnrollment(
        courseId: UUID,
        userId: UUID,
    ): Boolean =
        dsl.fetchExists(
            selectOne().from(Enrollments.TABLE)
                .where(Enrollments.COURSE_ID.eq(courseId))
                .and(Enrollments.USER_ID.eq(userId))
                .and(Enrollments.STATUS.eq("ACTIVE")),
        )

    fun lockActiveEnrollmentSupportLanguage(
        courseId: UUID,
        userId: UUID,
    ): String? =
        dsl.select(Enrollments.SUPPORT_LANGUAGE)
            .from(Enrollments.TABLE)
            .where(Enrollments.COURSE_ID.eq(courseId))
            .and(Enrollments.USER_ID.eq(userId))
            .and(Enrollments.STATUS.eq("ACTIVE"))
            .forUpdate()
            .fetchOne(Enrollments.SUPPORT_LANGUAGE)

    fun findEnrollment(enrollmentId: UUID): EnrollmentResult? =
        dsl.select(
            Enrollments.ID,
            Enrollments.COURSE_ID,
            Enrollments.SUPPORT_LANGUAGE,
            Enrollments.STATUS,
            Enrollments.ENROLLED_AT,
        ).from(Enrollments.TABLE)
            .where(Enrollments.ID.eq(enrollmentId))
            .and(Enrollments.STATUS.eq("ACTIVE"))
            .fetchOne {
                EnrollmentResult(
                    id = it.get(Enrollments.ID)!!,
                    courseId = it.get(Enrollments.COURSE_ID)!!,
                    supportLanguage = it.get(Enrollments.SUPPORT_LANGUAGE)!!,
                    status = it.get(Enrollments.STATUS)!!,
                    created = false,
                    enrolledAt = it.get(Enrollments.ENROLLED_AT)!!,
                )
            }

    fun findActiveTest(testId: UUID): TestContext? =
        dsl.select(
            CourseTests.ID,
            TestRevisions.ID,
            CourseTests.COURSE_ID,
            Courses.ACTIVE_RELEASE_ID,
            Courses.ACCESS_TYPE,
            TestRevisions.PASS_THRESHOLD,
        ).from(Courses.TABLE)
            .join(CourseReleaseTestRevisions.TABLE)
            .on(CourseReleaseTestRevisions.COURSE_RELEASE_ID.eq(Courses.ACTIVE_RELEASE_ID))
            .and(CourseReleaseTestRevisions.COURSE_ID.eq(Courses.ID))
            .join(TestRevisions.TABLE)
            .on(TestRevisions.ID.eq(CourseReleaseTestRevisions.TEST_REVISION_ID))
            .and(TestRevisions.TEST_ID.eq(CourseReleaseTestRevisions.TEST_ID))
            .and(TestRevisions.COURSE_ID.eq(CourseReleaseTestRevisions.COURSE_ID))
            .join(CourseTests.TABLE)
            .on(CourseTests.ID.eq(TestRevisions.TEST_ID))
            .and(CourseTests.COURSE_ID.eq(TestRevisions.COURSE_ID))
            .where(CourseTests.ID.eq(testId))
            .and(Courses.STATUS.eq("PUBLISHED"))
            .and(TestRevisions.STATUS.eq("ACTIVE"))
            .fetchOne {
                TestContext(
                    testId = it.get(CourseTests.ID)!!,
                    testRevisionId = it.get(TestRevisions.ID)!!,
                    courseId = it.get(CourseTests.COURSE_ID)!!,
                    courseReleaseId = it.get(Courses.ACTIVE_RELEASE_ID)!!,
                    courseAccessType = it.get(Courses.ACCESS_TYPE)!!,
                    passThreshold = it.get(TestRevisions.PASS_THRESHOLD)!!,
                )
            }

    fun findAttemptQuestions(
        testRevisionId: UUID,
        supportLanguage: String,
    ): List<AttemptQuestionSource> =
        dsl.select(
            QuestionRevisions.QUESTION_ID,
            QuestionRevisions.ID,
            QuestionRevisions.TYPE,
            QuestionRevisions.PROMPT,
            QuestionRevisions.CORRECT_ANSWER,
            QuestionRevisions.ALTERNATIVE_CORRECT_ANSWER,
            QuestionRevisions.ANSWER_MATCH_POLICY,
            QuestionRevisions.ANSWER_MATCH_LANGUAGE,
            QuestionRevisions.CORRECT_ANSWER_MATCH_KEY,
            QuestionRevisions.ALTERNATIVE_ANSWER_MATCH_KEY,
            QuestionRevisions.MATCHING_POLICY,
            QuestionRevisions.MATCHING_LABEL_POLICY,
            QuestionRevisions.MATCHING_ORDER_POLICY,
            QuestionRevisions.MATCHING_TARGET_LANGUAGE,
            TestRevisionQuestions.POSITION,
        ).from(TestRevisionQuestions.TABLE)
            .join(QuestionRevisions.TABLE)
            .on(QuestionRevisions.ID.eq(TestRevisionQuestions.QUESTION_REVISION_ID))
            .and(QuestionRevisions.QUESTION_ID.eq(TestRevisionQuestions.QUESTION_ID))
            .where(TestRevisionQuestions.TEST_REVISION_ID.eq(testRevisionId))
            .and(QuestionRevisions.STATUS.eq("ACTIVE"))
            .orderBy(TestRevisionQuestions.POSITION.asc())
            .fetch {
                val type = LearningQuestionType.fromStorageCode(it.get(QuestionRevisions.TYPE)!!)
                AttemptQuestionSource(
                    questionId = it.get(QuestionRevisions.QUESTION_ID)!!,
                    questionRevisionId = it.get(QuestionRevisions.ID)!!,
                    type = type,
                    prompt = it.get(QuestionRevisions.PROMPT),
                    options = findQuestionOptions(it.get(QuestionRevisions.ID)!!),
                    typedAnswer = if (type == LearningQuestionType.TYPED_CLOZE) {
                        TypedAnswerSource(
                            primaryAnswerText = it.get(QuestionRevisions.CORRECT_ANSWER)!!,
                            alternativeAnswerText = it.get(QuestionRevisions.ALTERNATIVE_CORRECT_ANSWER),
                            policyVersion = it.get(QuestionRevisions.ANSWER_MATCH_POLICY)!!,
                            languageTag = it.get(QuestionRevisions.ANSWER_MATCH_LANGUAGE)!!,
                            primaryMatchKey = it.get(QuestionRevisions.CORRECT_ANSWER_MATCH_KEY)!!,
                            alternativeMatchKey = it.get(QuestionRevisions.ALTERNATIVE_ANSWER_MATCH_KEY),
                        )
                    } else {
                        null
                    },
                    matching = if (type == LearningQuestionType.MATCHING) {
                        MatchingQuestionSource(
                            policyVersion = it.get(QuestionRevisions.MATCHING_POLICY)!!,
                            labelPolicyVersion = it.get(QuestionRevisions.MATCHING_LABEL_POLICY)!!,
                            orderPolicyVersion = it.get(QuestionRevisions.MATCHING_ORDER_POLICY)!!,
                            targetLanguage = it.get(QuestionRevisions.MATCHING_TARGET_LANGUAGE)!!,
                            pairs = findMatchingPairs(it.get(QuestionRevisions.ID)!!, supportLanguage),
                        )
                    } else {
                        null
                    },
                    position = it.get(TestRevisionQuestions.POSITION)!!,
                )
            }

    private fun findMatchingPairs(
        questionRevisionId: UUID,
        supportLanguage: String,
    ): List<MatchingPairSource> =
        dsl.select(
            QuestionRevisionMatchingPairs.TARGET_ITEM_ID,
            QuestionRevisionMatchingPairs.TARGET_TEXT,
            QuestionRevisionMatchingTranslations.SUPPORT_ITEM_ID,
            QuestionRevisionMatchingTranslations.SUPPORT_TEXT,
            QuestionRevisionMatchingPairs.POSITION,
        ).from(QuestionRevisionMatchingPairs.TABLE)
            .join(QuestionRevisionMatchingTranslations.TABLE)
            .on(
                QuestionRevisionMatchingTranslations.QUESTION_REVISION_ID
                    .eq(QuestionRevisionMatchingPairs.QUESTION_REVISION_ID),
            )
            .and(
                QuestionRevisionMatchingTranslations.TARGET_ITEM_ID
                    .eq(QuestionRevisionMatchingPairs.TARGET_ITEM_ID),
            )
            .and(QuestionRevisionMatchingTranslations.COURSE_ID.eq(QuestionRevisionMatchingPairs.COURSE_ID))
            .where(QuestionRevisionMatchingPairs.QUESTION_REVISION_ID.eq(questionRevisionId))
            .and(QuestionRevisionMatchingTranslations.SUPPORT_LANGUAGE.eq(supportLanguage))
            .orderBy(QuestionRevisionMatchingPairs.POSITION.asc())
            .fetch {
                MatchingPairSource(
                    targetItemId = it.get(QuestionRevisionMatchingPairs.TARGET_ITEM_ID)!!,
                    targetText = it.get(QuestionRevisionMatchingPairs.TARGET_TEXT)!!,
                    supportItemId = it.get(QuestionRevisionMatchingTranslations.SUPPORT_ITEM_ID)!!,
                    supportText = it.get(QuestionRevisionMatchingTranslations.SUPPORT_TEXT)!!,
                    position = it.get(QuestionRevisionMatchingPairs.POSITION)!!,
                )
            }

    private fun findQuestionOptions(questionRevisionId: UUID): List<QuestionOptionSource> =
        dsl.select(
            QuestionRevisionOptions.ID,
            QuestionRevisionOptions.TEXT,
            QuestionRevisionOptions.IS_CORRECT,
            QuestionRevisionOptions.POSITION,
        ).from(QuestionRevisionOptions.TABLE)
            .where(QuestionRevisionOptions.QUESTION_REVISION_ID.eq(questionRevisionId))
            .orderBy(QuestionRevisionOptions.POSITION.asc())
            .fetch {
                QuestionOptionSource(
                    id = it.get(QuestionRevisionOptions.ID)!!,
                    text = it.get(QuestionRevisionOptions.TEXT)!!,
                    correct = it.get(QuestionRevisionOptions.IS_CORRECT)!!,
                    position = it.get(QuestionRevisionOptions.POSITION)!!,
                )
            }

    private fun mapCourse(
        id: UUID,
        name: String,
        description: String?,
        targetLanguage: String,
        defaultSupportLanguage: String,
        accessType: String,
        visibility: String,
        ownerDisplayName: String,
        releaseId: UUID,
        enrolled: Boolean,
    ): CourseSummary =
        CourseSummary(
            id = id,
            name = name,
            description = description,
            targetLanguage = targetLanguage,
            defaultSupportLanguage = defaultSupportLanguage,
            supportLanguages = dsl.select(CourseSupportLanguages.LANGUAGE_CODE)
                .from(CourseSupportLanguages.TABLE)
                .where(CourseSupportLanguages.COURSE_ID.eq(id))
                .orderBy(CourseSupportLanguages.LANGUAGE_CODE.asc())
                .fetch(CourseSupportLanguages.LANGUAGE_CODE),
            accessType = accessType,
            visibility = visibility,
            ownerDisplayName = ownerDisplayName,
            releaseId = releaseId,
            enrolled = enrolled,
        )
}
