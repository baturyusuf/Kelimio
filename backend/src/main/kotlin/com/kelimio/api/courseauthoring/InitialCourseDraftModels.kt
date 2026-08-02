package com.kelimio.api.courseauthoring

import java.time.OffsetDateTime
import java.util.UUID

interface InitialCourseDraftCreator {
    fun create(command: InitialCourseDraftCommand): InitialCourseDraftResult
}

data class InitialCourseDraftCommand(
    val ownerUserId: UUID,
    val sourceImportId: UUID,
    val sourceSha256: String,
    val correlationId: String,
    val committedAt: OffsetDateTime,
    val settings: InitialCourseDraftSettings,
    val rows: List<InitialCourseDraftRow>,
    val expectedLevelCount: Int,
    val expectedUnitCount: Int,
    val expectedTopicCount: Int,
    val expectedTestCount: Int,
)

data class InitialCourseDraftSettings(
    val courseName: String,
    val targetLanguageCode: String,
    val targetLanguageName: String,
    val supportLanguageCodes: List<String>,
    val defaultSupportLanguageCode: String,
    val defaultTestMode: InitialTestMode,
    val visibility: InitialCourseVisibility,
    val targetTestSize: Int,
    val minimumLastAutomaticTestSize: Int,
    val fillFixedTests: Boolean,
    val completionThresholdPercent: Int,
    val pricingSource: String,
    val maximumTypedAlternativeAnswers: Int,
    val offlineMode: String,
)

data class InitialCourseDraftRow(
    val ordinal: Int,
    val sourceSheetOrdinal: Int,
    val sourceSheetName: String,
    val sourceRowNumber: Int,
    val level: String,
    val unit: String,
    val topic: String,
    val testNumber: Int,
    val allocationKind: InitialAllocationKind,
    val allocationReason: InitialAllocationReason,
    val resolvedMode: InitialTestMode,
    val recordType: InitialRecordType,
    val targetText: String,
    val translations: Map<String, String>,
    val sentence: String?,
    val correctAnswer: String?,
    val alternativeCorrectAnswer: String?,
    val wrongAnswers: List<String>,
    val matchingGroup: String?,
    val hidden: Boolean,
    val note: String?,
)

enum class InitialCourseVisibility {
    PUBLIC,
    PRIVATE,
}

enum class InitialTestMode {
    MIXED,
    WORD,
    MATCHING,
    MULTIPLE_CHOICE_CLOZE,
    TYPED_CLOZE,
}

enum class InitialAllocationKind {
    FIXED,
    AUTOMATIC,
}

enum class InitialAllocationReason {
    FIXED_DECLARATION,
    FIXED_TEST_FILL,
    AUTOMATIC,
}

enum class InitialRecordType {
    WORD,
    MULTIPLE_CHOICE_CLOZE,
    TYPED_CLOZE,
}

data class InitialCourseDraftResult(
    val courseId: UUID,
    val contentChangeSetId: UUID,
    val draftReleaseId: UUID,
    val rowCount: Int,
    val levelCount: Int,
    val unitCount: Int,
    val topicCount: Int,
    val testCount: Int,
)

class InitialCourseDraftValidationException : IllegalArgumentException("The approved preview is not commit-ready.")
