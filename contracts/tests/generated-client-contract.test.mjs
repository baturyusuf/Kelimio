import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const modelDirectory = fileURLToPath(
  new URL("../../admin-web/src/generated/api/src/models/", import.meta.url),
);
const modelFiles = readdirSync(modelDirectory)
  .filter((name) => name.endsWith(".ts"))
  .sort();

const unsafeRequiredNullableDate =
  /^\s*'[^']+': \(\(value\['[^']+'\] as any\)\.toISOString\(\)(?:\.substring\(0,10\))?\),$/mu;
const checked = [];
let checkedRequiredNullableReleaseId = false;

for (const name of modelFiles) {
  const source = readFileSync(`${modelDirectory}/${name}`, "utf8");
  assert.equal(
    unsafeRequiredNullableDate.test(source),
    false,
    `${name} must not call toISOString directly on a required-nullable date`,
  );

  for (const match of source.matchAll(/^\s*([A-Za-z_$][\w$]*): Date \| null;$/gmu)) {
    const property = match[1];
    const safePrefix = `'${property}': value['${property}'] == null ? null : (`;
    assert.equal(
      source.includes(safePrefix),
      true,
      `${name}.${property} must serialize null as JSON null`,
    );
    checked.push(`${name}.${property}`);
  }
  if (name === "ActivateCourseReleaseRequest.ts") {
    assert.match(source, /expectedActiveReleaseId: string \| null;/u);
    assert.match(source, /'expectedActiveReleaseId': value\['expectedActiveReleaseId'\],/u);
    checkedRequiredNullableReleaseId = true;
  }
}

assert.ok(
  checked.includes("CourseImportStatusResponse.ts.approvedAt"),
  "the import status approvedAt regression must remain covered",
);
assert.ok(
  checked.includes("CourseProgressResponse.ts.updatedAt"),
  "the existing progress updatedAt regression must remain covered",
);
assert.equal(
  checkedRequiredNullableReleaseId,
  true,
  "the activation client's required-nullable optimistic lock must serialize explicit JSON null",
);

console.log(`Generated TypeScript safely serializes ${checked.length} required-nullable dates.`);
