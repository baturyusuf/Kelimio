# ADR-006: Secure XLSX Ingestion Boundary

- Status: Accepted
- Date: 2026-08-01

## Context

The production requirements allow an Excel workbook to create a course exactly
once. The workbook is untrusted binary input and can contain compressed XML,
relationships, formulas, hidden content, macros, embedded objects, or malformed
package structures. Parsing it in the request-serving API process would expose
API availability and secrets to parser resource exhaustion or implementation
faults. The current course schema also represents only the initial Type-A
learning slice and cannot losslessly persist the supplied workbook's complete
level/unit/topic hierarchy, resolved test modes, translations, or Type B/C/D
records.

The master requirement permits either accepting a formula's safe cached value
or rejecting formula cells. A deterministic import cannot safely establish that
a client-supplied cached value corresponds to the visible formula or to a known
calculation engine version.

## Decision

### Processing boundary

- The public API will create upload sessions and report import state, but it will
  never parse an untrusted workbook in the request-serving process.
- A production import worker with isolated CPU, memory, temporary storage,
  network, and wall-clock limits will process an exact, versioned quarantine
  object only after a malware scanner records `CLEAN`. Timeout, scanner error,
  missing verdict, or unknown verdict remains fail-closed.
- The parser/planner core is an IO-independent library owned by
  `import-pipeline`. It may be built and tested in the current backend workspace,
  but it is not exposed as a controller, Spring bean, database writer, local
  fallback, or production success path until the worker and content-authoring
  application interfaces exist.
- Import commit remains unavailable until the content schema can represent the
  normalized preview without loss. It must not reuse or expand the local starter
  repository across module boundaries.

### Package and parser policy

- Accept only `.xlsx` whose extension, declared media type, OOXML package type,
  and ZIP signature agree. Reject legacy Excel, macro-enabled, binary, encrypted,
  or generic ZIP inputs.
- Preflight the ZIP before OOXML parsing. Reject duplicate or case-fold-colliding
  entry names; absolute, drive, UNC, backslash, NUL, or traversal paths; corrupt
  entries; DTD/entity declarations; external relationships or data connections;
  macros, ActiveX, embedded packages, and OLE objects.
- Use Apache Commons Compress for both the preflight name view and Apache POI's
  eventual package view. `xlsx-v1` rejects every ZIP extra field and entry
  comment, requires strict UTF-8 raw-name identity, and therefore cannot let an
  Info-ZIP Unicode-path field make preflight and POI assign different logical
  names to the same bytes.
- Require the transitional OOXML namespaces and exactly one expected document
  root for every security-significant core part. Relationship type URIs are
  case-sensitive exact allowlist members; relationship IDs and content-type
  mappings are unique within their scopes. Hybrid strict/transitional packages
  are rejected until the full POI event path is proven to interpret them
  consistently.
- Reject every formula cell, including one with a cached value. No formula
  evaluator runs. This selects the safer option allowed by the governing master
  requirement and removes calculation-engine and stale-cache ambiguity.
- Parse worksheets through Apache POI's SAX/event interface. Do not construct a
  full mutable workbook for production input.
- Before POI materializes shared strings or buffers worksheet values, preflight
  applies the per-cell and total-text ceilings, rejects malformed/nested shared
  string state, and proves every shared-string cell reference is a bounded
  nonnegative index into the scanned table. Parser exceptions crossing this
  boundary retain only a stable non-sensitive Kelimio rejection code.
- Reject hidden or very-hidden worksheets and hidden rows or columns instead of
  silently excluding their content from the preview.
- Normalize structural identifiers and language headers to Unicode NFC. Reject
  controls, bidi overrides/isolates, zero-width structural characters, and
  headers that collide after normalization/case folding. Natural-language cell
  content retains valid Arabic and other Unicode text; normalization is never a
  lossy transliteration.
- Language tags, blank test-mode inheritance, and deterministic test allocation
  follow ADR-000 and ADR-003. The backend-generated preview is authoritative;
  Flutter must not reimplement the planner.
- Every translatable word record must contain a nonblank value for every support
  language declared by the workbook. The initial import has no cross-language
  fallback and never substitutes an unrelated language. A future relaxed
  completeness or fallback policy requires a superseding ADR and must remain
  explicit in the release manifest and client response.

### Initial versioned limits

The initial rules version is `xlsx-v1`. One source of constants enforces:

- at most 25 MiB compressed upload;
- at most 1,000 ZIP entries, 100 MiB per inflated entry, 200 MiB total inflated
  bytes, and no entry exceeding a 100:1 inflation ratio after a 100 KiB
  inflated-size grace allowance;
- tighter pre-parse caps of 1 MiB per workbook/package metadata part, 8 MiB for
  styles, 2 MiB for a theme, and 64 MiB for shared strings before Apache POI
  may materialize those structures;
- at most 64 worksheets, 64 imported columns, 10,000 content rows, 2,000
  characters per cell, 20 million text characters in total, 10,000 style
  records, and at most `max rows × max columns` shared-string items;
- a six-minute worker wall-clock ceiling, with lower infrastructure CPU/memory
  limits verified by malicious and 10,000-row load fixtures.

The ZIP entry-count and inflation-grace limits intentionally do not relax
Apache POI 5.5.1's process-wide defaults. The independent preflight therefore
rejects them with stable Kelimio error codes before library parsing begins.

Changing these limits requires security/load evidence and a recorded amendment;
environment configuration may tighten but never relax them silently. Reader
construction enforces that every custom `xlsx-v1` cap, ratio grace, and deadline
is no greater than the accepted `xlsx-v1` boundary.

### Initial semantic subset

The `xlsx-v1` preview intentionally accepts less than the eventual authoring
model while unresolved semantics remain fail-closed:

- every level worksheet must contain at least one valid content row;
- `Karışık` may contain the supported word and cloze record types, while an
  explicit non-mixed mode must contain only its matching homogeneous record
  type;
- `Eşleştirme` mode is rejected until matching-group composition and scoring
  are fixed in the backend contract; the raw matching-group value on a word
  row remains preserved in the normalized preview;
- `Gizli mi? = Evet` is rejected until visibility, allocation, completion, and
  immutable-release effects can be represented losslessly;
- multiple-choice cloze rows require all three authored distractors. The
  importer does not generate distractors until scope and seed rules are
  versioned.

These restrictions describe parser-preview validity only. A valid `xlsx-v1`
preview is still not commit-ready while the content schema and worker/archive
workflow remain incomplete.

### Provenance and later workflow

The implemented side-effect-free preview emits an allocation digest over the
normalized rows and test plan plus a complete-preview digest that also binds all
course settings. The future approval additionally binds the source SHA-256, S3
object version, scanner identity/signature version, parser/rules version, and
validation report digest. Approval of one digest cannot authorize a different
object or parser result. The original workbook and report become immutable
archive artifacts before the single idempotent database commit. A second
workbook cannot update the resulting course.

## Consequences

- The first implementation milestone can prove the exact workbook grammar,
  malicious-package defenses, and planner determinism without creating a false
  production upload or persistence claim.
- Formula-driven templates, hidden data, external links, and active content are
  intentionally unsupported; authors receive explicit validation errors.
- S3 upload, ClamAV integration, state/audit migrations, ownership checks,
  preview approval, archive reconciliation, schema expansion, and commit remain
  explicit later milestones and release blockers.
- Apache POI and the directly used Commons Compress ZIP layer are pinned and
  dependency-locked; updates follow `docs/VERSIONS.md` and the normal
  compatibility/security procedure.
