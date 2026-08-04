import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { setTimeout as delay } from "node:timers/promises";

const protectedRoutes = [
  "/support",
  "/account-deletion",
  "/privacy",
  "/terms",
  "/community-guidelines",
  "/teacher-terms",
];

const publicationEnvironment = [
  "KELIMIO_SUPPORT_APPROVED",
  "KELIMIO_SUPPORT_VERSION",
  "KELIMIO_SUPPORT_EMAIL",
  "KELIMIO_ACCOUNT_DELETION_APPROVED",
  "KELIMIO_ACCOUNT_DELETION_VERSION",
  "KELIMIO_ACCOUNT_DELETION_TEXT",
  "KELIMIO_PRIVACY_APPROVED",
  "KELIMIO_PRIVACY_VERSION",
  "KELIMIO_PRIVACY_TEXT",
  "KELIMIO_TERMS_APPROVED",
  "KELIMIO_TERMS_VERSION",
  "KELIMIO_TERMS_TEXT",
  "KELIMIO_COMMUNITY_GUIDELINES_APPROVED",
  "KELIMIO_COMMUNITY_GUIDELINES_VERSION",
  "KELIMIO_COMMUNITY_GUIDELINES_TEXT",
  "KELIMIO_TEACHER_TERMS_APPROVED",
  "KELIMIO_TEACHER_TERMS_VERSION",
  "KELIMIO_TEACHER_TERMS_TEXT",
];

async function availablePort() {
  const server = createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  assert(address && typeof address !== "string");
  await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
  return address.port;
}

async function waitUntilReady(baseUrl, processExited) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    if (processExited()) {
      throw new Error("The production server exited before becoming ready.");
    }
    try {
      const response = await fetch(baseUrl);
      if (response.ok) return;
    } catch {
      // The server is still starting.
    }
    await delay(250);
  }
  throw new Error("Timed out waiting for the production server.");
}

const port = await availablePort();
const baseUrl = `http://127.0.0.1:${port}`;
const environment = {
  ...process.env,
  NEXT_TELEMETRY_DISABLED: "1",
  NODE_ENV: "production",
};
for (const name of publicationEnvironment) {
  environment[name] = name.endsWith("_APPROVED") ? "false" : "";
}

let exitCode;
const server = spawn(
  process.execPath,
  ["node_modules/next/dist/bin/next", "start", "-H", "127.0.0.1", "-p", String(port)],
  { env: environment, stdio: ["ignore", "pipe", "pipe"] },
);
server.once("exit", (code) => {
  exitCode = code ?? 1;
});

try {
  await waitUntilReady(baseUrl, () => exitCode !== undefined);

  const home = await fetch(baseUrl);
  assert.equal(home.status, 200, "The public home page must remain available.");
  assert(home.headers.has("content-security-policy"), "Security headers must be present.");
  assert.equal(home.headers.has("x-powered-by"), false, "The framework header must stay disabled.");

  for (const route of protectedRoutes) {
    const response = await fetch(`${baseUrl}${route}`);
    const body = await response.text();
    assert.equal(response.status, 404, `${route} must fail closed without approval.`);
    assert.match(
      body,
      /name="robots" content="[^"]*noindex/,
      `${route} must be marked noindex while unpublished.`,
    );
  }

  process.stdout.write("Production publication gates verified.\n");
} finally {
  server.kill();
}
