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
const submitAnswerSchema = contract.components.schemas.SubmitAnswerRequest;
const answerRecordedSchema = contract.components.schemas.AnswerRecordedResponse;
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
  submitAnswerOperation["x-kelimio-max-request-body-bytes"],
  8192,
  "answer submission bodies must remain bounded before JSON allocation",
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

console.log("Course, profile, question, and answer schemas accept valid fixtures and reject unsafe drift.");
