package com.kelimio.api.importpipeline.application

import com.kelimio.api.importpipeline.domain.PlannedTest
import com.kelimio.api.importpipeline.domain.ResolvedTestMode
import com.kelimio.api.importpipeline.domain.WorkbookRecordType
import com.kelimio.api.importpipeline.domain.WorkbookRowSource
import com.kelimio.api.language.InvalidMatchingLabelException
import com.kelimio.api.language.MatchingLabelPolicy
import java.text.Normalizer
import java.util.Locale

internal object WorkbookQuestionComposer {
    const val MATCHING_CAPABILITY = "question.matching.v1"

    fun compose(
        rulesVersion: String,
        settings: CourseImportSettings,
        rows: List<NormalizedWorkbookRow>,
        tests: List<PlannedTest>,
        checkpoint: () -> Unit,
    ): WorkbookQuestionCompositionResult {
        val issues = mutableListOf<WorkbookImportIssue>()
        val bySource = rows.associateBy(NormalizedWorkbookRow::source)
        if (rulesVersion == XLSX_V1) {
            return WorkbookQuestionCompositionResult(
                composition = rowComposition(tests, bySource, checkpoint),
                issues = emptyList(),
            )
        }
        if (rulesVersion != XLSX_V2) {
            return WorkbookQuestionCompositionResult(null, emptyList())
        }

        val selectedGroups = linkedMapOf<ScopedGroupKey, MutableList<GroupMember>>()
        tests.forEach { test ->
            checkpoint()
            test.rows.forEach { planned ->
                checkpoint()
                val row = checkNotNull(bySource[planned.row.source])
                if (test.resolvedMode == ResolvedTestMode.MATCHING) {
                    if (row.recordType != WorkbookRecordType.WORD || row.matchingGroup == null) {
                        issues += issue(
                            WorkbookImportIssueCode.MATCHING_GROUP_REQUIRED,
                            row.source,
                            "A matching test requires every row to be a grouped word row",
                        )
                        return@forEach
                    }
                }
                if (
                    row.recordType == WorkbookRecordType.WORD &&
                    row.matchingGroup != null &&
                    test.resolvedMode in setOf(ResolvedTestMode.MIXED, ResolvedTestMode.MATCHING)
                ) {
                    val key = ScopedGroupKey(
                        row.path.level,
                        row.path.unit,
                        row.path.topic,
                        row.matchingGroup.groupCollisionKey(),
                    )
                    selectedGroups.getOrPut(key, ::mutableListOf) += GroupMember(test, planned.row.source, row)
                }
            }
        }

        selectedGroups.values.forEach { members ->
            checkpoint()
            val testIdentities = members.map { it.test.path to it.test.number }.distinct()
            if (testIdentities.size != 1) {
                issues += issue(
                    WorkbookImportIssueCode.MATCHING_GROUP_CROSSES_TEST,
                    members.first().row.source,
                    "A composed matching group must remain inside one resolved test",
                )
            }
            if (members.size !in 2..6) {
                issues += issue(
                    WorkbookImportIssueCode.INVALID_MATCHING_GROUP_SIZE,
                    members.first().row.source,
                    "A composed matching group requires two through six word rows",
                )
            }
            validateLabels(settings, members, issues, checkpoint)
        }
        if (issues.isNotEmpty()) return WorkbookQuestionCompositionResult(null, issues)

        val memberBySource = selectedGroups
            .flatMap { (key, members) -> members.mapIndexed { index, member -> member.source to (key to (index + 1)) } }
            .toMap()
        val projections = linkedMapOf<WorkbookRowSource, ProjectedWorkbookRow>()
        val groupOrdinals = mutableMapOf<ScopedGroupKey, Int>()
        var questionOrdinal = 0
        var matchingQuestionCount = 0
        tests.forEach { test ->
            checkpoint()
            test.rows.forEach { planned ->
                checkpoint()
                val row = checkNotNull(bySource[planned.row.source])
                val membership = memberBySource[row.source]
                if (membership == null) {
                    questionOrdinal += 1
                    projections[row.source] = ProjectedWorkbookRow(
                        source = row.source,
                        questionOrdinal = questionOrdinal,
                        questionType = row.recordType.projectedType(),
                        compositionKind = WorkbookCompositionKind.ROW,
                        groupPosition = null,
                    )
                } else {
                    val (groupKey, groupPosition) = membership
                    val ordinal = groupOrdinals.getOrPut(groupKey) {
                        questionOrdinal += 1
                        matchingQuestionCount += 1
                        questionOrdinal
                    }
                    projections[row.source] = ProjectedWorkbookRow(
                        source = row.source,
                        questionOrdinal = ordinal,
                        questionType = ProjectedQuestionType.D,
                        compositionKind = WorkbookCompositionKind.MATCHING_GROUP,
                        groupPosition = groupPosition,
                    )
                }
            }
        }
        return WorkbookQuestionCompositionResult(
            WorkbookQuestionComposition(
                rows = projections.values,
                questionCount = questionOrdinal,
                matchingQuestionCount = matchingQuestionCount,
                requiredClientCapabilities = if (matchingQuestionCount == 0) emptyList() else listOf(MATCHING_CAPABILITY),
            ),
            emptyList(),
        )
    }

    private fun rowComposition(
        tests: List<PlannedTest>,
        bySource: Map<WorkbookRowSource, NormalizedWorkbookRow>,
        checkpoint: () -> Unit,
    ): WorkbookQuestionComposition {
        var ordinal = 0
        val projections = tests.flatMap { test ->
            test.rows.map { planned ->
                checkpoint()
                val row = checkNotNull(bySource[planned.row.source])
                ordinal += 1
                ProjectedWorkbookRow(
                    source = row.source,
                    questionOrdinal = ordinal,
                    questionType = row.recordType.projectedType(),
                    compositionKind = WorkbookCompositionKind.ROW,
                    groupPosition = null,
                )
            }
        }
        return WorkbookQuestionComposition(projections, ordinal, 0, emptyList())
    }

    private fun validateLabels(
        settings: CourseImportSettings,
        members: List<GroupMember>,
        issues: MutableList<WorkbookImportIssue>,
        checkpoint: () -> Unit,
    ) {
        fun uniqueLabels(language: String, values: List<Pair<WorkbookRowSource, String>>) {
            val seen = mutableSetOf<String>()
            values.forEach { (source, value) ->
                checkpoint()
                val key = try {
                    MatchingLabelPolicy.canonicalize(value, language)
                } catch (_: InvalidMatchingLabelException) {
                    issues += issue(
                        WorkbookImportIssueCode.INVALID_MATCHING_LABEL,
                        source,
                        "A matching label is outside matching-label-v1",
                    )
                    return@forEach
                }
                if (!seen.add(key)) {
                    issues += issue(
                        WorkbookImportIssueCode.DUPLICATE_MATCHING_LABEL,
                        source,
                        "A matching group contains an ambiguous duplicate label",
                    )
                }
            }
        }
        uniqueLabels(settings.targetLanguageCode, members.map { it.row.source to it.row.targetText })
        settings.supportLanguageCodes.forEach { language ->
            uniqueLabels(language, members.map { it.row.source to checkNotNull(it.row.translations[language]) })
        }
    }

    private fun WorkbookRecordType.projectedType(): ProjectedQuestionType = when (this) {
        WorkbookRecordType.WORD -> ProjectedQuestionType.A
        WorkbookRecordType.MULTIPLE_CHOICE_CLOZE -> ProjectedQuestionType.B
        WorkbookRecordType.TYPED_CLOZE -> ProjectedQuestionType.C
    }

    private fun String.groupCollisionKey(): String =
        Normalizer.normalize(uppercase(Locale.ROOT).lowercase(Locale.ROOT), Normalizer.Form.NFC)

    private fun issue(
        code: WorkbookImportIssueCode,
        source: WorkbookRowSource,
        message: String,
    ) = WorkbookImportIssue(
        severity = WorkbookImportIssueSeverity.ERROR,
        code = code,
        source = WorkbookCellSource(source.sheetOrdinal, source.sheetName, source.rowNumber),
        message = message,
    )

    private data class ScopedGroupKey(
        val level: String,
        val unit: String,
        val topic: String,
        val groupKey: String,
    )

    private data class GroupMember(
        val test: PlannedTest,
        val source: WorkbookRowSource,
        val row: NormalizedWorkbookRow,
    )

    private const val XLSX_V1 = "xlsx-v1"
    private const val XLSX_V2 = "xlsx-v2"
}

internal data class WorkbookQuestionCompositionResult(
    val composition: WorkbookQuestionComposition?,
    val issues: List<WorkbookImportIssue>,
)

class WorkbookQuestionComposition internal constructor(
    rows: Collection<ProjectedWorkbookRow>,
    val questionCount: Int,
    val matchingQuestionCount: Int,
    requiredClientCapabilities: Collection<String>,
) {
    val rows: List<ProjectedWorkbookRow> = immutableList(rows)
    val requiredClientCapabilities: List<String> = immutableList(requiredClientCapabilities)
    private val bySource = this.rows.associateBy(ProjectedWorkbookRow::source)

    fun row(source: WorkbookRowSource): ProjectedWorkbookRow = checkNotNull(bySource[source])
}

data class ProjectedWorkbookRow(
    val source: WorkbookRowSource,
    val questionOrdinal: Int,
    val questionType: ProjectedQuestionType,
    val compositionKind: WorkbookCompositionKind,
    val groupPosition: Int?,
)

enum class ProjectedQuestionType { A, B, C, D }

enum class WorkbookCompositionKind { ROW, MATCHING_GROUP }
