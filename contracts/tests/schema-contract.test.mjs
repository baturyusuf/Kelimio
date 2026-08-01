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

console.log("Course and profile schemas accept valid fixtures and reject unsafe drift.");
