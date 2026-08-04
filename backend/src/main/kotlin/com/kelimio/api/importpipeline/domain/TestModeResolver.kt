package com.kelimio.api.importpipeline.domain

object TestModeResolver {
    fun resolve(
        rows: List<TestPlanningRow>,
        defaultMode: ResolvedTestMode,
        testNumber: Int? = null,
    ): ModeResolution {
        val explicitModes = rows.mapNotNull { row ->
            row.requestedMode?.let { directive -> row to directive.resolve(defaultMode) }
        }
        val distinctModes = explicitModes.map { it.second }.distinct()

        if (distinctModes.size <= 1) {
            return ModeResolution(
                mode = distinctModes.singleOrNull() ?: defaultMode,
                issues = emptyList(),
            )
        }

        val firstMode = explicitModes.first().second
        val conflictSource = explicitModes.first { it.second != firstMode }.first.source
        val sortedModes = distinctModes.sortedBy(ResolvedTestMode::ordinal)
        return ModeResolution(
            mode = null,
            issues = listOf(
                ImportValidationIssue(
                    severity = ImportIssueSeverity.ERROR,
                    code = ImportIssueCode.TEST_MODE_CONFLICT,
                    source = conflictSource,
                    path = rows.firstOrNull()?.path,
                    testNumber = testNumber,
                    message = "Test contains conflicting effective modes: ${sortedModes.joinToString { it.name }}",
                ),
            ),
        )
    }

    private fun WorkbookTestModeDirective.resolve(defaultMode: ResolvedTestMode): ResolvedTestMode = when (this) {
        WorkbookTestModeDirective.DEFAULT -> defaultMode
        WorkbookTestModeDirective.MIXED -> ResolvedTestMode.MIXED
        WorkbookTestModeDirective.WORD -> ResolvedTestMode.WORD
        WorkbookTestModeDirective.MATCHING -> ResolvedTestMode.MATCHING
        WorkbookTestModeDirective.MULTIPLE_CHOICE_CLOZE -> ResolvedTestMode.MULTIPLE_CHOICE_CLOZE
        WorkbookTestModeDirective.TYPED_CLOZE -> ResolvedTestMode.TYPED_CLOZE
    }
}
