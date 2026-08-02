import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import YAML from "yaml";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const contractPath = path.resolve(testDirectory, "../openapi/kelimio-api.yaml");
const fixturePath = path.resolve(testDirectory, "fixtures/course-detail.json");

const contract = YAML.parse(await readFile(contractPath, "utf8"));
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);

const submitAnswerOperation = contract.paths["/v1/attempts/{attemptId}/answers"].post;
const getRecordedAnswerOperation =
  contract.paths["/v1/attempts/{attemptId}/answers/{submissionId}"].get;
const submitAnswerSchema = contract.components.schemas.SubmitAnswerRequest;
const answerRecordedSchema = contract.components.schemas.AnswerRecordedResponse;
const matchingSelectionSchema = contract.components.schemas.MatchingSelection;
assert.equal(
  submitAnswerSchema["x-kelimio-redacted-to-string"],
  true,
  "typed answer request string forms must stay redacted",
);
assert.equal(
  submitAnswerSchema.properties.typedAnswer["x-kelimio-sensitive"],
  true,
  "typed learner answers must stay marked sensitive",
);
assert.equal(
  submitAnswerSchema.properties.matches["x-kelimio-sensitive"],
  true,
  "submitted matching edges must stay marked sensitive",
);
assert.equal(
  answerRecordedSchema["x-kelimio-redacted-to-string"],
  true,
  "post-commit answer feedback string forms must stay redacted",
);
assert.equal(
  answerRecordedSchema.properties.correctOptionId["x-kelimio-sensitive"],
  true,
  "option answer keys must stay marked sensitive",
);
assert.equal(
  answerRecordedSchema.properties.correctAnswerText["x-kelimio-sensitive"],
  true,
  "typed answer keys must stay marked sensitive",
);
assert.equal(
  answerRecordedSchema.properties.correctMatches["x-kelimio-sensitive"],
  true,
  "matching answer keys must stay marked sensitive",
);
assert.equal(
  matchingSelectionSchema["x-kelimio-redacted-to-string"],
  true,
  "nested matching selections must redact standalone diagnostics",
);
assert.equal(
  matchingSelectionSchema.properties.targetItemId["x-kelimio-sensitive"],
  true,
  "nested target item identifiers must stay marked sensitive",
);
assert.equal(
  matchingSelectionSchema.properties.supportItemId["x-kelimio-sensitive"],
  true,
  "nested support item identifiers must stay marked sensitive",
);
assert.equal(
  submitAnswerOperation["x-kelimio-max-request-body-bytes"],
  8192,
  "answer submission bodies must remain bounded before JSON allocation",
);
assert.equal(
  contract.components.headers.NoStore.schema.const,
  "no-store",
  "the shared answer-key cache policy must remain an exact no-store value",
);
assert.equal(
  submitAnswerOperation.responses["200"].headers["Cache-Control"].$ref,
  "#/components/headers/NoStore",
  "authoritative submit feedback must remain non-cacheable",
);
assert.equal(
  getRecordedAnswerOperation.responses["200"].headers["Cache-Control"].$ref,
  "#/components/headers/NoStore",
  "ownership-scoped reconciliation feedback must remain non-cacheable",
);
assert.equal(
  submitAnswerOperation.responses["413"].headers["Cache-Control"].$ref,
  "#/components/headers/NoStore",
  "oversized answer responses must remain non-cacheable",
);
assert.equal(
  submitAnswerOperation.responses["413"].content["application/problem+json"].schema.$ref,
  "#/components/schemas/Problem",
  "oversized answer responses must use the generic RFC Problem schema",
);

const validateCourseDetail = ajv.compile({
  $schema: "https://json-schema.org/draft/2020-12/schema",
  components: contract.components,
  $ref: "#/components/schemas/CourseDetail",
});

assert.equal(
  validateCourseDetail(fixture),
  true,
  `CourseDetail fixture must satisfy the response schema: ${ajv.errorsText(validateCourseDetail.errors)}`,
);

const missingRequiredField = structuredClone(fixture);
delete missingRequiredField.releaseId;
assert.equal(validateCourseDetail(missingRequiredField), false, "releaseId must remain required");

const unexpectedField = { ...fixture, leakedInternalState: true };
assert.equal(validateCourseDetail(unexpectedField), false, "unexpected response fields must remain closed");

const nonCanonicalLanguage = { ...fixture, targetLanguage: "PT-br" };
assert.equal(validateCourseDetail(nonCanonicalLanguage), false, "language tags must use canonical casing");

const compileSchema = (name) => ajv.compile({
  $schema: "https://json-schema.org/draft/2020-12/schema",
  components: contract.components,
  $ref: `#/components/schemas/${name}`,
});

const validateGenericId = compileSchema("Id");
assert.equal(
  validateGenericId("7c3fb0e8-0fb2-5b4e-8d41-f6bf5ebec2a9"),
  true,
  "the matching-only UUIDv4 constraint must not narrow generic API identifiers",
);

const validateMeResponse = compileSchema("MeResponse");
const provisionalProfile = {
  id: "00000000-0000-4000-8000-000000000901",
  displayName: "Profile User",
  appLocale: "tr",
  activeTargetLanguage: "en",
  preferredSupportLanguage: null,
  timeZone: "UTC",
  profileVersion: 0,
  profileSetupStatus: "REQUIRED",
};
assert.equal(
  validateMeResponse(provisionalProfile),
  true,
  `Provisional MeResponse must satisfy the response schema: ${ajv.errorsText(validateMeResponse.errors)}`,
);
assert.equal(
  validateMeResponse({
    ...provisionalProfile,
    preferredSupportLanguage: "ar",
    timeZone: "Europe/Istanbul",
    profileVersion: 1,
    profileSetupStatus: "COMPLETE",
  }),
  true,
  `Completed MeResponse must satisfy the response schema: ${ajv.errorsText(validateMeResponse.errors)}`,
);
const hasValidProfileState = (profile) =>
  (profile.profileSetupStatus === "REQUIRED" &&
    profile.profileVersion === 0 &&
    profile.preferredSupportLanguage == null) ||
  (profile.profileSetupStatus === "COMPLETE" &&
    profile.profileVersion >= 1 &&
    typeof profile.preferredSupportLanguage === "string");
assert.equal(hasValidProfileState(provisionalProfile), true);
assert.equal(
  hasValidProfileState({
    ...provisionalProfile,
    preferredSupportLanguage: "ar",
    profileVersion: 1,
    profileSetupStatus: "COMPLETE",
  }),
  true,
);
assert.equal(
  hasValidProfileState({ ...provisionalProfile, profileVersion: 1 }),
  false,
  "a setup-required profile cannot claim a committed profile version",
);
assert.equal(
  hasValidProfileState({
    ...provisionalProfile,
    profileSetupStatus: "COMPLETE",
    profileVersion: 1,
  }),
  false,
  "a completed profile must include a support language",
);
assert.equal(
  hasValidProfileState({
    ...provisionalProfile,
    preferredSupportLanguage: "en",
  }),
  false,
  "a setup-required profile cannot expose completed preferences",
);
assert.equal(
  validateMeResponse({ ...provisionalProfile, subject: "oidc-subject" }),
  false,
  "MeResponse must not expose the identity-provider subject",
);
assert.equal(
  validateMeResponse({ ...provisionalProfile, email: "private@example.invalid" }),
  false,
  "MeResponse must reject undeclared identity data",
);
assert.equal(
  validateMeResponse({ ...provisionalProfile, username: "provider-name" }),
  false,
  "MeResponse must not expose the identity-provider username",
);

const validateProfileSetupRequest = compileSchema("ProfileSetupRequest");
const profileSetupRequest = {
  displayName: "Profile User",
  appLocale: "ar",
  activeTargetLanguage: "tr",
  preferredSupportLanguage: "en",
  timeZone: "Europe/Istanbul",
};
assert.equal(
  validateProfileSetupRequest(profileSetupRequest),
  true,
  `ProfileSetupRequest must satisfy the request schema: ${ajv.errorsText(validateProfileSetupRequest.errors)}`,
);
assert.equal(
  validateProfileSetupRequest({ ...profileSetupRequest, appLocale: "fr" }),
  false,
  "unsupported application locales must be rejected",
);
assert.equal(
  validateProfileSetupRequest({ ...profileSetupRequest, userId: provisionalProfile.id }),
  false,
  "profile setup must reject client-asserted identity fields",
);

const option = (suffix, text) => ({
  id: `00000000-0000-4000-8000-0000000000${suffix}`,
  text,
});
const wordQuestion = {
  questionId: "00000000-0000-4000-8000-000000000101",
  questionRevisionId: "00000000-0000-4000-8000-000000000102",
  type: "WORD_MULTIPLE_CHOICE",
  position: 1,
  prompt: "Pencere",
  options: [
    option("11", "Door"),
    option("12", "Window"),
    option("13", "Table"),
    option("14", "Chair"),
  ],
  targetItems: [],
  supportItems: [],
};
const clozeQuestion = {
  ...wordQuestion,
  questionId: "00000000-0000-4000-8000-000000000201",
  questionRevisionId: "00000000-0000-4000-8000-000000000202",
  type: "MULTIPLE_CHOICE_CLOZE",
  prompt: "Ben her sabah çay ---.",
};
const typedClozeQuestion = {
  ...clozeQuestion,
  questionId: "00000000-0000-4000-8000-000000000301",
  questionRevisionId: "00000000-0000-4000-8000-000000000302",
  type: "TYPED_CLOZE",
  prompt: "Sabah kahvaltıda çay ---.",
  options: [],
};
const matchingItem = (id, text) => ({ id, text });
const matchingQuestion = {
  questionId: "00000000-0000-4000-8000-000000000501",
  questionRevisionId: "00000000-0000-4000-8000-000000000502",
  type: "MATCHING",
  position: 4,
  prompt: null,
  options: [],
  targetItems: [
    matchingItem("7c3fb0e8-0fb2-4b4e-8d41-f6bf5ebec2a9", "Pencere"),
    matchingItem("294d18f5-1115-499d-a51a-a97635004e91", "Kapı"),
    matchingItem("a0f8b1ca-07fd-451e-974d-98a776d2cf72", "Masa"),
    matchingItem("13ad8f73-2a53-4c19-b8e4-dc699a498e27", "Sandalye"),
  ],
  supportItems: [
    matchingItem("c27da0ae-6d47-47c1-bb78-2bc2a86bd394", "Table"),
    matchingItem("dca8ed80-fcab-42a1-acd8-ff69cda41534", "Window"),
    matchingItem("8d215d5a-e815-4bb7-97c1-3e2c87ff5b42", "Chair"),
    matchingItem("5e83bf52-1ed2-41ef-ae24-09f704621f16", "Door"),
  ],
};
const validateQuestionPayload = compileSchema("QuestionPayload");
assert.equal(
  validateQuestionPayload(wordQuestion),
  true,
  `Type-A question must remain valid: ${ajv.errorsText(validateQuestionPayload.errors)}`,
);
assert.equal(
  validateQuestionPayload(clozeQuestion),
  true,
  `Type-B question must be valid: ${ajv.errorsText(validateQuestionPayload.errors)}`,
);
assert.equal(
  validateQuestionPayload(typedClozeQuestion),
  true,
  `Type-C question must be valid: ${ajv.errorsText(validateQuestionPayload.errors)}`,
);
assert.equal(
  validateQuestionPayload(matchingQuestion),
  true,
  `Type-D question must be valid: ${ajv.errorsText(validateQuestionPayload.errors)}`,
);
for (const prompt of [
  "Ben her sabah çay içerim.",
  "--- Ben her sabah çay ---.",
  "Ben her sabah çay ----.",
  "Ben her sabah çay ------.",
]) {
  assert.equal(
    validateQuestionPayload({ ...clozeQuestion, prompt }),
    false,
    `Type-B prompt must contain exactly one overlapping-counted marker: ${prompt}`,
  );
  assert.equal(
    validateQuestionPayload({ ...typedClozeQuestion, prompt }),
    false,
    `Type-C prompt must contain exactly one overlapping-counted marker: ${prompt}`,
  );
}
assert.equal(
  validateQuestionPayload({ ...typedClozeQuestion, options: clozeQuestion.options }),
  false,
  "typed-cloze questions must not contain options",
);
assert.equal(
  validateQuestionPayload({ ...clozeQuestion, options: clozeQuestion.options.slice(0, 3) }),
  false,
  "multiple-choice questions must contain exactly four options",
);
assert.equal(
  validateQuestionPayload({ ...clozeQuestion, correctOptionId: clozeQuestion.options[1].id }),
  false,
  "pre-answer question payloads must reject an answer key",
);
assert.equal(
  validateQuestionPayload({ ...typedClozeQuestion, correctAnswerText: "içerim" }),
  false,
  "typed-cloze attempt payloads must reject an authored answer key",
);
assert.equal(
  validateQuestionPayload({ ...matchingQuestion, prompt: "Match the pairs" }),
  false,
  "matching questions must use a null legacy prompt",
);
const matchingWithoutPrompt = structuredClone(matchingQuestion);
delete matchingWithoutPrompt.prompt;
assert.equal(
  validateQuestionPayload(matchingWithoutPrompt),
  false,
  "matching questions must retain the required null prompt key",
);
assert.equal(
  validateQuestionPayload({ ...matchingQuestion, options: clozeQuestion.options }),
  false,
  "matching questions must not contain options",
);
assert.equal(
  validateQuestionPayload({
    ...matchingQuestion,
    targetItems: matchingQuestion.targetItems.slice(0, 1),
    supportItems: matchingQuestion.supportItems.slice(0, 1),
  }),
  false,
  "matching questions require at least two pairs",
);
assert.equal(
  validateQuestionPayload({
    ...matchingQuestion,
    supportItems: matchingQuestion.supportItems.slice(0, 3),
  }),
  false,
  "matching sides must have equal lengths",
);
const extraTargetItems = [
  matchingItem("53184dbf-a100-45ad-93bd-57b1c122fe07", "Tavan"),
  matchingItem("bc4996c9-c410-4fc5-a92b-f25b1182a858", "Duvar"),
];
const extraSupportItems = [
  matchingItem("f222c9dc-d9a4-4f75-bc49-37454a2b62cd", "Ceiling"),
  matchingItem("8a2d1ea7-3d79-4416-b514-7be383c91a22", "Wall"),
];
const targetItemPool = [...matchingQuestion.targetItems, ...extraTargetItems];
const supportItemPool = [...matchingQuestion.supportItems, ...extraSupportItems];
for (let size = 2; size <= 6; size += 1) {
  assert.equal(
    validateQuestionPayload({
      ...matchingQuestion,
      targetItems: targetItemPool.slice(0, size),
      supportItems: supportItemPool.slice(0, size),
    }),
    true,
    `matching questions must accept equal sides of size ${size}`,
  );
}
assert.equal(
  validateQuestionPayload({
    ...matchingQuestion,
    targetItems: [
      ...targetItemPool,
      matchingItem("6c02f4ea-3f74-481c-aaad-e842bda437e1", "Zemin"),
    ],
    supportItems: [
      ...supportItemPool,
      matchingItem("b8f4a21e-d895-4f3c-850f-373dd329cbe8", "Floor"),
    ],
  }),
  false,
  "matching questions must reject groups larger than six pairs",
);
assert.equal(
  validateQuestionPayload({
    ...wordQuestion,
    targetItems: matchingQuestion.targetItems,
  }),
  false,
  "non-matching questions must carry empty matching arrays",
);
assert.equal(
  validateQuestionPayload({ ...matchingQuestion, correctMatches: [] }),
  false,
  "pre-answer matching payloads must reject the correct mapping",
);
assert.equal(
  validateQuestionPayload({
    ...matchingQuestion,
    targetItems: [
      {
        ...matchingQuestion.targetItems[0],
        id: "7c3fb0e8-0fb2-5b4e-8d41-f6bf5ebec2a9",
      },
      ...matchingQuestion.targetItems.slice(1),
    ],
  }),
  false,
  "matching item IDs must be independently generated UUIDv4 values",
);
assert.equal(
  validateQuestionPayload({
    ...matchingQuestion,
    targetItems: [
      { ...matchingQuestion.targetItems[0], pairId: "private-pair-link" },
      ...matchingQuestion.targetItems.slice(1),
    ],
  }),
  false,
  "matching items must reject a shared pair identifier",
);

const hasSafeMatchingQuestionShape = (question) => {
  if (question.type !== "MATCHING") return true;
  const targetIds = question.targetItems.map((item) => item.id);
  const supportIds = question.supportItems.map((item) => item.id);
  return targetIds.length >= 2 &&
    targetIds.length <= 6 &&
    targetIds.length === supportIds.length &&
    new Set(targetIds).size === targetIds.length &&
    new Set(supportIds).size === supportIds.length &&
    targetIds.every((id) => !supportIds.includes(id));
};
assert.equal(hasSafeMatchingQuestionShape(matchingQuestion), true);
assert.equal(
  hasSafeMatchingQuestionShape({
    ...matchingQuestion,
    targetItems: [
      matchingQuestion.targetItems[0],
      { ...matchingQuestion.targetItems[1], id: matchingQuestion.targetItems[0].id },
      ...matchingQuestion.targetItems.slice(2),
    ],
  }),
  false,
  "runtime decoders must reject repeated item IDs even when object text differs",
);
assert.equal(
  hasSafeMatchingQuestionShape({
    ...matchingQuestion,
    supportItems: [
      { ...matchingQuestion.supportItems[0], id: matchingQuestion.targetItems[0].id },
      ...matchingQuestion.supportItems.slice(1),
    ],
  }),
  false,
  "runtime decoders must reject target/support ID intersection",
);

const validateAttemptResponse = compileSchema("AttemptResponse");
const attemptResponse = {
  id: "00000000-0000-4000-8000-000000000601",
  testId: "00000000-0000-4000-8000-000000000602",
  testRevisionId: "00000000-0000-4000-8000-000000000603",
  supportLanguage: "en",
  state: "IN_PROGRESS",
  questions: [matchingQuestion],
  startedAt: "2026-08-02T08:00:00Z",
};
assert.equal(
  validateAttemptResponse(attemptResponse),
  true,
  `Attempt response with pinned support language must be valid: ${ajv.errorsText(validateAttemptResponse.errors)}`,
);
assert.equal(
  validateAttemptResponse({ ...attemptResponse, supportLanguage: "EN" }),
  false,
  "attempt support language must use canonical casing",
);
const attemptWithoutSupportLanguage = structuredClone(attemptResponse);
delete attemptWithoutSupportLanguage.supportLanguage;
assert.equal(
  validateAttemptResponse(attemptWithoutSupportLanguage),
  false,
  "attempt support language must remain required",
);

const validateSubmitAnswerRequest = compileSchema("SubmitAnswerRequest");
const submissionBase = {
  submissionId: "00000000-0000-4000-8000-000000000401",
  questionRevisionId: typedClozeQuestion.questionRevisionId,
};
assert.equal(
  validateSubmitAnswerRequest({
    ...submissionBase,
    selectedOptionId: clozeQuestion.options[0].id,
  }),
  true,
  `Option submission must remain valid: ${ajv.errorsText(validateSubmitAnswerRequest.errors)}`,
);
assert.equal(
  validateSubmitAnswerRequest({ ...submissionBase, typedAnswer: "içerim" }),
  true,
  `Typed submission must be valid: ${ajv.errorsText(validateSubmitAnswerRequest.errors)}`,
);
const matchingSelections = [
  {
    targetItemId: matchingQuestion.targetItems[0].id,
    supportItemId: matchingQuestion.supportItems[1].id,
  },
  {
    targetItemId: matchingQuestion.targetItems[1].id,
    supportItemId: matchingQuestion.supportItems[3].id,
  },
  {
    targetItemId: matchingQuestion.targetItems[2].id,
    supportItemId: matchingQuestion.supportItems[0].id,
  },
  {
    targetItemId: matchingQuestion.targetItems[3].id,
    supportItemId: matchingQuestion.supportItems[2].id,
  },
];
assert.equal(
  validateSubmitAnswerRequest({ ...submissionBase, matches: matchingSelections }),
  true,
  `Matching submission must be valid: ${ajv.errorsText(validateSubmitAnswerRequest.errors)}`,
);
assert.equal(
  validateSubmitAnswerRequest(submissionBase),
  false,
  "an answer submission must contain one answer form",
);
assert.equal(
  validateSubmitAnswerRequest({
    ...submissionBase,
    selectedOptionId: clozeQuestion.options[0].id,
    typedAnswer: "içerim",
  }),
  false,
  "an answer submission must not contain both answer forms",
);
assert.equal(
  validateSubmitAnswerRequest({
    ...submissionBase,
    typedAnswer: "içerim",
    matches: matchingSelections,
  }),
  false,
  "an answer submission must not mix typed and matching forms",
);
assert.equal(
  validateSubmitAnswerRequest({
    ...submissionBase,
    selectedOptionId: clozeQuestion.options[0].id,
    matches: matchingSelections,
  }),
  false,
  "an answer submission must not mix option and matching forms",
);
assert.equal(
  validateSubmitAnswerRequest({ ...submissionBase, matches: matchingSelections.slice(0, 1) }),
  false,
  "matching submissions require at least two edges",
);
assert.equal(
  validateSubmitAnswerRequest({
    ...submissionBase,
    matches: matchingSelections.map((selection, index) => index === 0
      ? { ...selection, targetItemId: "7c3fb0e8-0fb2-5b4e-8d41-f6bf5ebec2a9" }
      : selection),
  }),
  false,
  "matching submissions must reject non-v4 matching item identifiers",
);
assert.equal(
  validateSubmitAnswerRequest({ ...submissionBase, typedAnswer: "" }),
  false,
  "typed answers must not be empty",
);
assert.equal(
  validateSubmitAnswerRequest({ ...submissionBase, typedAnswer: "a".repeat(501) }),
  false,
  "typed answers must remain bounded",
);
assert.equal(
  validateSubmitAnswerRequest({ ...submissionBase, typedAnswer: "içerim", correct: true }),
  false,
  "answer submissions must reject client-asserted correctness",
);

const isCompleteMatchingBijection = (selections, question) => {
  const targetIds = question.targetItems.map((item) => item.id);
  const supportIds = question.supportItems.map((item) => item.id);
  const submittedTargets = selections.map((selection) => selection.targetItemId);
  const submittedSupports = selections.map((selection) => selection.supportItemId);
  return selections.length === targetIds.length &&
    new Set(submittedTargets).size === targetIds.length &&
    new Set(submittedSupports).size === supportIds.length &&
    targetIds.every((id) => submittedTargets.includes(id)) &&
    supportIds.every((id) => submittedSupports.includes(id));
};
assert.equal(isCompleteMatchingBijection(matchingSelections, matchingQuestion), true);
assert.equal(
  isCompleteMatchingBijection([...matchingSelections, matchingSelections[0]], matchingQuestion),
  false,
  "runtime validation must reject repeated matching edges",
);
assert.equal(
  isCompleteMatchingBijection(
    matchingSelections.map((selection, index) => index === 1
      ? { ...selection, targetItemId: matchingSelections[0].targetItemId }
      : selection),
    matchingQuestion,
  ),
  false,
  "runtime validation must reject duplicate target IDs even with distinct edge objects",
);
assert.equal(
  isCompleteMatchingBijection(
    matchingSelections.map((selection, index) => index === 1
      ? { ...selection, supportItemId: "30000000-0000-4000-8000-000000000099" }
      : selection),
    matchingQuestion,
  ),
  false,
  "runtime validation must reject foreign support IDs",
);

const validateAnswerRecordedResponse = compileSchema("AnswerRecordedResponse");
const recordedBase = {
  submissionId: submissionBase.submissionId,
  correct: true,
  activeScoreDelta: 60,
  lifetimeScoreDelta: 60,
  activeQuestionScore: 60,
  lifetimeScore: 60,
  energy: {
    balance: 5,
    maximum: 5,
    unlimited: false,
    nextRegenerationAt: null,
    asOf: "2026-08-02T08:00:00Z",
  },
  attemptState: "IN_PROGRESS",
};
assert.equal(
  validateAnswerRecordedResponse({
    ...recordedBase,
    correctOptionId: clozeQuestion.options[0].id,
  }),
  true,
  `Option feedback must remain valid: ${ajv.errorsText(validateAnswerRecordedResponse.errors)}`,
);
assert.equal(
  validateAnswerRecordedResponse({ ...recordedBase, correctAnswerText: "içerim" }),
  true,
  `Typed feedback must be valid: ${ajv.errorsText(validateAnswerRecordedResponse.errors)}`,
);
assert.equal(
  validateAnswerRecordedResponse({ ...recordedBase, correctMatches: matchingSelections }),
  true,
  `Matching feedback must be valid: ${ajv.errorsText(validateAnswerRecordedResponse.errors)}`,
);
assert.equal(
  validateAnswerRecordedResponse(recordedBase),
  false,
  "post-commit feedback must contain exactly one answer-key form",
);
assert.equal(
  validateAnswerRecordedResponse({
    ...recordedBase,
    correctOptionId: clozeQuestion.options[0].id,
    correctAnswerText: "içerim",
  }),
  false,
  "post-commit feedback must not contain both answer-key forms",
);
assert.equal(
  validateAnswerRecordedResponse({
    ...recordedBase,
    correctAnswerText: "içerim",
    correctMatches: matchingSelections,
  }),
  false,
  "post-commit feedback must not mix typed and matching answer keys",
);
assert.equal(
  validateAnswerRecordedResponse({
    ...recordedBase,
    correctOptionId: clozeQuestion.options[0].id,
    correctMatches: matchingSelections,
  }),
  false,
  "post-commit feedback must not mix option and matching answer keys",
);
assert.equal(
  validateAnswerRecordedResponse({
    ...recordedBase,
    correctMatches: matchingSelections.slice(0, 1),
  }),
  false,
  "matching feedback requires at least two edges",
);
assert.equal(
  isCompleteMatchingBijection(matchingSelections, matchingQuestion),
  true,
  "runtime response validation must require exact issued-ID coverage",
);

const importPaths = [
  "/v1/courses/imports",
  "/v1/courses/imports/{importId}",
  "/v1/courses/imports/{importId}/complete",
  "/v1/courses/imports/{importId}/preview",
  "/v1/courses/imports/{importId}/issues",
  "/v1/courses/imports/{importId}/approve",
];
for (const importPath of importPaths) {
  assert.ok(contract.paths[importPath], `course-import contract path must exist: ${importPath}`);
  for (const operation of Object.values(contract.paths[importPath])) {
    for (const [status, responseOrReference] of Object.entries(operation.responses)) {
      const response = responseOrReference.$ref === "#/components/responses/Problem"
        ? contract.components.responses.Problem
        : responseOrReference;
      assert.equal(
        response.headers["Cache-Control"].$ref,
        "#/components/headers/NoStore",
        `${operation.operationId} response ${status} must remain non-cacheable`,
      );
    }
  }
}
for (const [path, method, statuses] of [
  ["/v1/courses/imports", "post",
    ["200", "201", "400", "401", "409", "413", "422", "429", "503", "default"]],
  ["/v1/courses/imports/{importId}", "get", ["200", "400", "401", "404", "default"]],
  ["/v1/courses/imports/{importId}/complete", "post",
    ["200", "202", "400", "401", "404", "409", "413", "422", "503", "default"]],
  ["/v1/courses/imports/{importId}/preview", "get", ["200", "400", "401", "404", "409", "default"]],
  ["/v1/courses/imports/{importId}/issues", "get", ["200", "400", "401", "404", "409", "default"]],
  ["/v1/courses/imports/{importId}/approve", "post",
    ["200", "201", "400", "401", "404", "409", "413", "422", "default"]],
]) {
  assert.deepEqual(
    Object.keys(contract.paths[path][method].responses).sort(),
    [...statuses].sort(),
    `${contract.paths[path][method].operationId} must retain its explicit HTTP outcome matrix`,
  );
}
for (const [path, method] of [
  ["/v1/courses/imports", "post"],
  ["/v1/courses/imports/{importId}/complete", "post"],
  ["/v1/courses/imports/{importId}/approve", "post"],
]) {
  assert.equal(
    contract.paths[path][method]["x-kelimio-max-request-body-bytes"],
    8192,
    `${contract.paths[path][method].operationId} must keep a pre-parser JSON body limit`,
  );
}
assert.equal(
  contract.paths["/v1/courses/imports/{importId}/commit"],
  undefined,
  "approval-only intake must not expose course import commit",
);

const validPartSha256 = `${"A".repeat(43)}=`;
const validSourceSha256 = "a".repeat(64);
const validCreateImport = {
  originalFileName: "course.xlsx",
  declaredMediaType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  fileSizeBytes: 5242881,
  sourceSha256: validSourceSha256,
  parts: [
    { partNumber: 1, sizeBytes: 5242880, sha256: validPartSha256 },
    { partNumber: 2, sizeBytes: 1, sha256: validPartSha256 },
  ],
};
const validateCreateCourseImport = compileSchema("CreateCourseImportRequest");
assert.equal(
  validateCreateCourseImport(validCreateImport),
  true,
  `valid multipart import create request must pass: ${ajv.errorsText(validateCreateCourseImport.errors)}`,
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: "../course.xlsx" }),
  false,
  "import filenames must reject path-derived object keys",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: "safe\u202Efdp.xlsx" }),
  false,
  "import filenames must reject bidi display spoofing",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: "safe\u0085name.xlsx" }),
  false,
  "import filenames must reject C1 controls",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: "safe\u0600name.xlsx" }),
  false,
  "import filenames must reject Unicode format controls outside the named spoofing ranges",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: "safe\u2065name.xlsx" }),
  false,
  "import filenames must reject unassigned default-ignorable code points",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: `safe${String.fromCodePoint(0x1bca0)}name.xlsx` }),
  false,
  "import filenames must reject supplementary default-ignorable shorthand controls",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, originalFileName: `safe${String.fromCodePoint(0xe0100)}name.xlsx` }),
  false,
  "import filenames must reject supplementary variation selectors",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, declaredMediaType: "application/zip" }),
  false,
  "generic ZIP uploads must be rejected",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, sourceSha256: "A".repeat(64) }),
  false,
  "whole-file SHA-256 must use canonical lowercase hex",
);
assert.equal(
  validateCreateCourseImport({ ...validCreateImport, fileSizeBytes: 26214401 }),
  false,
  "import uploads must remain capped at 25 MiB",
);
assert.equal(
  contract.components.schemas.CreateCourseImportRequest["x-kelimio-redacted-to-string"],
  true,
  "import create diagnostics must stay redacted",
);
assert.equal(
  contract.components.schemas.CreateCourseImportRequest["x-kelimio-redaction-test-course-import"],
  true,
  "generated Dart import redaction regression test must remain enabled",
);
assert.equal(
  contract.components.schemas.CreateCourseImportRequest.properties.originalFileName["x-kelimio-sensitive"],
  true,
  "owner filenames must remain marked sensitive",
);
assert.equal(
  contract.components.schemas.CreateCourseImportRequest.properties.originalFileName["x-kelimio-normalization"],
  "NFC",
  "owner filenames must retain canonical Unicode normalization",
);
assert.equal(
  contract.components.schemas.CreateCourseImportRequest.properties.originalFileName[
    "x-kelimio-reject-default-ignorable-code-points"
  ],
  true,
  "owner filenames must reject the complete default-ignorable deny-set",
);
assert.equal(
  contract.components.schemas.CourseImportPresignedPart.properties.url["x-kelimio-sensitive"],
  true,
  "presigned URLs must remain marked sensitive",
);
assert.equal(
  contract.components.schemas.CourseImportPreviewSummary.properties.warningCount.maximum,
  2000,
  "persisted import warnings must remain bounded",
);
assert.equal(
  contract.components.schemas.CourseImportPreviewSummary.properties.errorCount.maximum,
  2000,
  "persisted import errors must remain bounded",
);
assert.equal(
  contract.components.schemas.CourseImportValidationIssue.properties.ordinal.maximum,
  2000,
  "validation issue pagination must remain bounded by the persisted issue budget",
);
assert.match(
  contract.components.schemas.CourseImportUploadInstructions.properties.expiresAt.description,
  /Earliest exact expiry among the signed part-upload URLs.*no URL.*remains valid after this instant/s,
  "the response must expose a conservative exact not-after time for every signed part URL",
);
assert.equal(
  contract.components.schemas.CompletedCourseImportPart.properties.eTag.pattern,
  "^[!-~]{1,256}$",
  "multipart ETags must remain bounded printable ASCII opaque values",
);
assert.equal(
  contract.components.schemas.CourseImportPreviewRow.properties.translations.minProperties,
  undefined,
  "valid cloze preview rows must be able to expose their intentionally empty translation map",
);
assert.ok(
  contract.components.schemas.CourseImportPreviewRow["x-kelimio-cross-field-invariants"]
    .some((rule) => rule.includes("non-empty for WORD") && rule.includes("empty for MULTIPLE_CHOICE_CLOZE")),
  "record-type-specific translation cardinality must remain explicit",
);
assert.equal(
  contract.components.schemas.CourseImportPreviewRow["x-kelimio-redacted-to-string"],
  true,
  "workbook preview row diagnostics must stay redacted",
);
for (const field of ["level", "unit", "topic", "targetText", "translations", "sentence",
  "correctAnswer", "alternativeCorrectAnswer", "wrongAnswers", "matchingGroup", "note"]) {
  assert.equal(
    contract.components.schemas.CourseImportPreviewRow.properties[field]["x-kelimio-sensitive"],
    true,
    `workbook-authored preview field must remain sensitive: ${field}`,
  );
}
for (const [schemaName, sensitiveFields] of Object.entries({
  CreateCourseImportRequest: ["originalFileName", "sourceSha256", "parts"],
  CourseImportPartDeclaration: ["sha256"],
  CourseImportUploadSessionResponse: ["import", "upload"],
  CourseImportUploadInstructions: ["parts"],
  CourseImportPresignedPart: ["url", "requiredHeaders"],
  CourseImportPartHeaders: ["sha256"],
  CompleteCourseImportUploadRequest: ["sourceSha256", "parts"],
  CompletedCourseImportPart: ["eTag", "sha256"],
  CourseImportStatusResponse: ["originalFileName", "preview", "approvalBindingSha256"],
  CourseImportPreviewSummary: ["validationReportSha256", "allocationSha256", "previewSha256"],
  CourseImportPreviewPage: ["items", "nextCursor"],
  CourseImportPreviewRow: ["source", "level", "unit", "topic", "targetText", "translations",
    "sentence", "correctAnswer", "alternativeCorrectAnswer", "wrongAnswers", "matchingGroup", "note"],
  CourseImportSource: ["sheetName", "reference"],
  CourseImportIssuePage: ["items", "nextCursor"],
  CourseImportValidationIssue: ["source", "message"],
  ApproveCourseImportRequest: ["approvalBindingSha256"],
  CourseImportApprovalResponse: ["approvalBindingSha256"],
})) {
  const schema = contract.components.schemas[schemaName];
  assert.equal(schema["x-kelimio-redacted-to-string"], true, `${schemaName} must redact toString`);
  for (const field of sensitiveFields) {
    assert.equal(
      schema.properties[field]["x-kelimio-sensitive"],
      true,
      `${schemaName}.${field} must remain sensitive`,
    );
  }
  assert.deepEqual(
    [...schema["x-kelimio-redacted-field-names"]].sort(),
    [...sensitiveFields].sort(),
    `${schemaName} must give the Dart generator an explicit complete redaction list`,
  );
}

assert.ok(
  contract.components.schemas.CreateCourseImportRequest["x-kelimio-cross-field-invariants"].length >= 3,
  "multipart cross-field invariants must remain explicit for backend validator tests",
);
const hasDocumentedCanonicalMultipartShape = (request) => {
  if (request.parts.length < 1 || request.parts.length > 5) return false;
  let total = 0;
  for (let index = 0; index < request.parts.length; index += 1) {
    const part = request.parts[index];
    const finalPart = index === request.parts.length - 1;
    if (part.partNumber !== index + 1) return false;
    if (!finalPart && part.sizeBytes !== 5242880) return false;
    if (finalPart && (part.sizeBytes < 1 || part.sizeBytes > 5242880)) return false;
    total += part.sizeBytes;
  }
  return total === request.fileSizeBytes;
};
assert.equal(hasDocumentedCanonicalMultipartShape(validCreateImport), true);
assert.equal(
  hasDocumentedCanonicalMultipartShape({
    ...validCreateImport,
    parts: validCreateImport.parts.map((part, index) => index === 1
      ? { ...part, partNumber: 3 }
      : part),
  }),
  false,
  "the documented multipart invariant rejects non-consecutive import parts",
);
assert.equal(
  hasDocumentedCanonicalMultipartShape({ ...validCreateImport, fileSizeBytes: 5242882 }),
  false,
  "the documented multipart invariant requires exact byte totals",
);

const validateCompleteCourseImportUpload = compileSchema("CompleteCourseImportUploadRequest");
const validCompleteImport = {
  sourceSha256: validSourceSha256,
  parts: validCreateImport.parts.map((part) => ({
    partNumber: part.partNumber,
    eTag: `\"part-${part.partNumber}\"`,
    sha256: part.sha256,
  })),
};
assert.equal(
  validateCompleteCourseImportUpload(validCompleteImport),
  true,
  `valid multipart completion must pass: ${ajv.errorsText(validateCompleteCourseImportUpload.errors)}`,
);
assert.equal(
  validateCompleteCourseImportUpload({
    ...validCompleteImport,
    parts: validCompleteImport.parts.map((part, index) => index === 0
      ? { ...part, claimedClean: true }
      : part),
  }),
  false,
  "completion must reject client-asserted scanner verdicts",
);
assert.equal(
  validateCompleteCourseImportUpload({ ...validCompleteImport, objectVersion: "client-version" }),
  false,
  "completion must reject client-asserted storage versions",
);
const completionMatchesCreate = (created, completed) =>
  completed.sourceSha256 === created.sourceSha256 &&
  completed.parts.length === created.parts.length &&
  completed.parts.every((part, index) =>
    part.partNumber === created.parts[index].partNumber &&
    part.sha256 === created.parts[index].sha256);
assert.equal(completionMatchesCreate(validCreateImport, validCompleteImport), true);
assert.equal(
  completionMatchesCreate(validCreateImport, {
    ...validCompleteImport,
    sourceSha256: "b".repeat(64),
  }),
  false,
  "the documented completion invariant rejects a changed whole-file digest",
);
assert.equal(
  completionMatchesCreate(validCreateImport, {
    ...validCompleteImport,
    parts: validCompleteImport.parts.map((part, index) => index === 1
      ? { ...part, sha256: `${"B".repeat(43)}=` }
      : part),
  }),
  false,
  "the documented completion invariant rejects a changed part digest",
);

const validateCourseImportStatus = compileSchema("CourseImportStatusResponse");
const validImportStatus = {
  id: "00000000-0000-4000-8000-000000000990",
  status: "UPLOADING",
  originalFileName: "course.xlsx",
  declaredMediaType: validCreateImport.declaredMediaType,
  fileSizeBytes: validCreateImport.fileSizeBytes,
  rulesVersion: "xlsx-v1",
  processingAttempts: 0,
  createdAt: "2026-08-02T08:00:00Z",
  updatedAt: "2026-08-02T08:00:00Z",
  uploadExpiresAt: "2026-08-02T08:15:00Z",
  preview: null,
  approvalBindingSha256: null,
  approvedAt: null,
  failureCode: null,
};
assert.equal(
  validateCourseImportStatus(validImportStatus),
  true,
  `owner import status must satisfy the closed response schema: ${ajv.errorsText(validateCourseImportStatus.errors)}`,
);
assert.equal(
  validateCourseImportStatus({ ...validImportStatus, quarantineObjectKey: "secret/key" }),
  false,
  "status must not expose storage coordinates",
);
assert.equal(
  validateCourseImportStatus({ ...validImportStatus, scannerResponse: "stream: OK" }),
  false,
  "status must not expose raw scanner responses",
);

console.log("Course, profile, A/B/C/D answer, and approval-only import schemas reject unsafe drift.");
