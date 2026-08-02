create function course_import_file_name_is_safe(value text) returns boolean
immutable strict language plpgsql as $$
declare
    character_value text;
    code_point integer;
begin
    for character_value in select regexp_split_to_table(value, '') loop
        code_point := ascii(character_value);
        if code_point between 0 and 31 or code_point between 127 and 159
            or code_point in (47, 58, 92, 173, 847, 1564, 1757, 1807, 2274, 12644, 65279, 65440)
            or code_point between 1536 and 1541 or code_point between 2192 and 2193
            or code_point between 4447 and 4448 or code_point between 6068 and 6069
            or code_point between 6155 and 6159 or code_point between 8203 and 8207
            or code_point between 8234 and 8238 or code_point between 8288 and 8303
            or code_point between 65024 and 65039 or code_point between 65520 and 65531
            or code_point between 113824 and 113827 or code_point between 119155 and 119162
            or code_point = 69821 or code_point = 69837
            or code_point between 78896 and 78911
            or code_point = 917505 or code_point between 917536 and 917631
            or code_point between 917504 and 921599 then
            return false;
        end if;
    end loop;
    return true;
end;
$$;

create table course_import (
    id uuid primary key,
    owner_user_id uuid not null references app_user(id),
    status varchar(32) not null,
    state_version bigint not null default 0,
    rules_version varchar(32) not null,
    original_file_name varchar(255) not null,
    declared_media_type varchar(160) not null,
    file_size_bytes bigint not null,
    asserted_source_sha256 char(64) not null,
    quarantine_bucket varchar(255) not null,
    quarantine_object_key varchar(1024) not null,
    multipart_upload_id varchar(2048) not null,
    upload_expires_at timestamptz not null,
    accepted_version_id varchar(1024),
    accepted_etag varchar(256),
    accepted_size_bytes bigint,
    accepted_checksum_sha256 varchar(128),
    processing_attempts integer not null default 0,
    processing_lease_token uuid,
    processing_lease_expires_at timestamptz,
    failure_code varchar(80),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint uq_course_import_storage_key unique (quarantine_bucket, quarantine_object_key),
    constraint ck_course_import_status check (status in (
        'UPLOADING', 'QUEUED', 'PROCESSING', 'PREVIEW_READY',
        'VALIDATION_FAILED', 'MALWARE_REJECTED', 'PROCESSING_FAILED',
        'EXPIRED', 'APPROVED'
    )),
    constraint ck_course_import_state_version check (state_version >= 0),
    constraint ck_course_import_rules_version check (rules_version = 'xlsx-v1'),
    constraint ck_course_import_file_name check (
        length(original_file_name) between 6 and 255
        and course_import_file_name_is_safe(original_file_name)
        and original_file_name !~ '^[[:space:]]|[[:space:]]$'
        and original_file_name = normalize(original_file_name, NFC)
        and lower(right(original_file_name, 5)) = '.xlsx'
    ),
    constraint ck_course_import_media_type check (
        declared_media_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ),
    constraint ck_course_import_file_size check (file_size_bytes between 1 and 26214400),
    constraint ck_course_import_source_sha256 check (asserted_source_sha256 ~ '^[0-9a-f]{64}$'),
    constraint ck_course_import_storage_names check (
        length(btrim(quarantine_bucket)) > 0
        and length(btrim(quarantine_object_key)) > 0
        and length(btrim(multipart_upload_id)) > 0
    ),
    constraint ck_course_import_expiry check (upload_expires_at > created_at),
    constraint ck_course_import_accepted_object_shape check (
        (
            accepted_version_id is null
            and accepted_etag is null
            and accepted_size_bytes is null
            and accepted_checksum_sha256 is null
            and status in ('UPLOADING', 'EXPIRED')
        ) or (
            accepted_version_id is not null
            and length(btrim(accepted_version_id)) > 0
            and lower(btrim(accepted_version_id)) <> 'null'
            and accepted_etag is not null
            and accepted_etag ~ '^[!-~]{1,255}[!-~]?$'
            and accepted_size_bytes is not null
            and accepted_size_bytes = file_size_bytes
            and accepted_checksum_sha256 is not null
            and accepted_checksum_sha256 ~ '^[A-Za-z0-9+/]{43}=-[1-5]$'
            and status not in ('UPLOADING', 'EXPIRED')
        )
    ),
    constraint ck_course_import_attempts check (processing_attempts between 0 and 5),
    constraint ck_course_import_lease_shape check (
        (status = 'PROCESSING' and processing_lease_token is not null and processing_lease_expires_at is not null)
        or (status <> 'PROCESSING' and processing_lease_token is null and processing_lease_expires_at is null)
    ),
    constraint ck_course_import_failure_code check (
        failure_code is null or failure_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    )
);

create index ix_course_import_owner_created on course_import(owner_user_id, created_at desc, id);
create index ix_course_import_expiry on course_import(status, upload_expires_at)
    where status = 'UPLOADING';

create table course_import_part (
    import_id uuid not null references course_import(id),
    part_number integer not null,
    size_bytes bigint not null,
    sha256_base64 char(44) not null,
    primary key (import_id, part_number),
    constraint uq_course_import_part_checksum unique (import_id, part_number, sha256_base64),
    constraint ck_course_import_part_number check (part_number between 1 and 5),
    constraint ck_course_import_part_size check (size_bytes between 1 and 5242880),
    constraint ck_course_import_part_sha256 check (
        sha256_base64 ~ '^[A-Za-z0-9+/]{43}=$'
    )
);

create table course_import_completed_part (
    import_id uuid not null,
    part_number integer not null,
    etag varchar(256),
    sha256_base64 char(44) not null,
    evidence_source varchar(32) not null,
    completed_at timestamptz not null,
    primary key (import_id, part_number),
    constraint fk_course_import_completed_part foreign key (import_id, part_number, sha256_base64)
        references course_import_part(import_id, part_number, sha256_base64),
    constraint ck_course_import_completed_evidence check (
        (evidence_source = 'S3_VERIFIED' and etag is not null and etag ~ '^[!-~]{1,255}[!-~]?$')
        or (evidence_source = 'EXACT_OBJECT_RECOVERY' and etag is null)
    ),
    constraint ck_course_import_completed_sha256 check (
        sha256_base64 ~ '^[A-Za-z0-9+/]{43}=$'
    )
);

create table course_import_event (
    id uuid primary key,
    import_id uuid not null references course_import(id),
    state_version bigint not null,
    event_type varchar(80) not null,
    from_status varchar(32),
    to_status varchar(32) not null,
    actor_user_id uuid references app_user(id),
    stable_code varchar(80),
    correlation_id varchar(128) not null,
    occurred_at timestamptz not null,
    constraint uq_course_import_event_version unique (import_id, state_version),
    constraint ck_course_import_event_type check (length(btrim(event_type)) > 0),
    constraint ck_course_import_event_from_status check (
        from_status is null or from_status in (
            'UPLOADING', 'QUEUED', 'PROCESSING', 'PREVIEW_READY', 'VALIDATION_FAILED',
            'MALWARE_REJECTED', 'PROCESSING_FAILED', 'EXPIRED', 'APPROVED'
        )
    ),
    constraint ck_course_import_event_to_status check (to_status in (
        'UPLOADING', 'QUEUED', 'PROCESSING', 'PREVIEW_READY', 'VALIDATION_FAILED',
        'MALWARE_REJECTED', 'PROCESSING_FAILED', 'EXPIRED', 'APPROVED'
    )),
    constraint ck_course_import_event_code check (
        stable_code is null or stable_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    ),
    constraint ck_course_import_event_correlation check (length(btrim(correlation_id)) > 0)
);

create table course_import_artifact (
    id uuid primary key,
    import_id uuid not null references course_import(id),
    artifact_kind varchar(32) not null,
    bucket_name varchar(255) not null,
    object_key varchar(1024) not null,
    object_version_id varchar(1024) not null,
    etag varchar(256) not null,
    sha256 char(64) not null,
    size_bytes bigint not null,
    media_type varchar(160) not null,
    created_at timestamptz not null,
    constraint uq_course_import_artifact_kind unique (import_id, artifact_kind),
    constraint uq_course_import_artifact_object unique (bucket_name, object_key, object_version_id),
    constraint uq_course_import_artifact_identity unique (id, import_id, artifact_kind),
    constraint ck_course_import_artifact_kind check (artifact_kind in (
        'QUARANTINE_SOURCE', 'ARCHIVE_SOURCE', 'VALIDATION_REPORT'
    )),
    constraint ck_course_import_artifact_names check (
        length(btrim(bucket_name)) > 0
        and length(btrim(object_key)) > 0
        and length(btrim(object_version_id)) > 0
        and lower(btrim(object_version_id)) <> 'null'
        and etag ~ '^[!-~]{1,255}[!-~]?$'
    ),
    constraint ck_course_import_artifact_sha256 check (sha256 ~ '^[0-9a-f]{64}$'),
    constraint ck_course_import_artifact_size check (size_bytes >= 0),
    constraint ck_course_import_artifact_media_type check (length(btrim(media_type)) > 0)
);

create table course_import_processing_attempt (
    id uuid primary key,
    import_id uuid not null references course_import(id),
    attempt_number integer not null,
    lease_token uuid not null,
    outcome varchar(32) not null,
    stable_code varchar(80),
    started_at timestamptz not null,
    finished_at timestamptz not null,
    constraint uq_course_import_processing_attempt unique (import_id, attempt_number),
    constraint ck_course_import_processing_attempt_number check (attempt_number between 1 and 5),
    constraint ck_course_import_processing_outcome check (outcome in (
        'PREVIEW_READY', 'VALIDATION_FAILED', 'MALWARE_REJECTED', 'RETRYABLE_FAILURE', 'EXHAUSTED'
    )),
    constraint ck_course_import_processing_code check (
        (outcome in ('PREVIEW_READY', 'VALIDATION_FAILED') and stable_code is null)
        or (outcome in ('MALWARE_REJECTED', 'RETRYABLE_FAILURE', 'EXHAUSTED')
            and stable_code is not null and stable_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
    ),
    constraint ck_course_import_processing_time check (finished_at >= started_at)
);

create table course_import_scan (
    id uuid primary key,
    import_id uuid not null references course_import(id),
    attempt_number integer not null,
    quarantine_artifact_id uuid not null,
    quarantine_artifact_kind varchar(32)
        generated always as ('QUARANTINE_SOURCE') stored,
    verdict varchar(16) not null,
    stable_code varchar(80),
    source_sha256 char(64) not null,
    source_size_bytes bigint not null,
    scanner_engine_version varchar(128),
    scanner_signature_version varchar(128),
    scanned_at timestamptz not null,
    constraint uq_course_import_scan_attempt unique (import_id, attempt_number),
    constraint uq_course_import_scan_identity unique (id, import_id, verdict),
    constraint fk_course_import_scan_artifact foreign key (
        quarantine_artifact_id, import_id, quarantine_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint ck_course_import_scan_attempt check (attempt_number between 1 and 5),
    constraint ck_course_import_scan_verdict check (verdict in ('CLEAN', 'MALWARE', 'ERROR')),
    constraint ck_course_import_scan_code check (
        stable_code is null or stable_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
    ),
    constraint ck_course_import_scan_sha256 check (source_sha256 ~ '^[0-9a-f]{64}$'),
    constraint ck_course_import_scan_size check (source_size_bytes between 1 and 26214400),
    constraint ck_course_import_scan_identity check (
        (verdict = 'CLEAN'
            and stable_code is null
            and scanner_engine_version is not null
            and scanner_signature_version is not null
            and length(btrim(scanner_engine_version)) > 0
            and length(btrim(scanner_signature_version)) > 0)
        or (verdict = 'MALWARE'
            and stable_code = 'malware-detected'
            and scanner_engine_version is not null
            and scanner_signature_version is not null
            and length(btrim(scanner_engine_version)) > 0
            and length(btrim(scanner_signature_version)) > 0)
        or (verdict = 'ERROR'
            and stable_code is not null
            and scanner_engine_version is null
            and scanner_signature_version is null)
    )
);

create unique index uq_course_import_terminal_scan
    on course_import_scan(import_id)
    where verdict in ('CLEAN', 'MALWARE');

create table course_import_preview (
    import_id uuid primary key references course_import(id),
    quarantine_artifact_id uuid not null,
    quarantine_artifact_kind varchar(32)
        generated always as ('QUARANTINE_SOURCE') stored,
    archive_source_artifact_id uuid not null,
    archive_source_artifact_kind varchar(32)
        generated always as ('ARCHIVE_SOURCE') stored,
    report_artifact_id uuid not null,
    report_artifact_kind varchar(32)
        generated always as ('VALIDATION_REPORT') stored,
    clean_scan_id uuid not null,
    clean_scan_verdict varchar(16) generated always as ('CLEAN') stored,
    rules_version varchar(32) not null,
    parser_version varchar(160) not null,
    is_valid boolean not null,
    row_count integer not null,
    level_count integer not null,
    unit_count integer not null,
    topic_count integer not null,
    test_count integer not null,
    warning_count integer not null,
    error_count integer not null,
    validation_report_sha256 char(64) not null,
    allocation_sha256 char(64),
    preview_sha256 char(64),
    approval_binding_sha256 char(64),
    created_at timestamptz not null,
    constraint fk_course_import_preview_quarantine foreign key (
        quarantine_artifact_id, import_id, quarantine_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint fk_course_import_preview_archive foreign key (
        archive_source_artifact_id, import_id, archive_source_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint fk_course_import_preview_report foreign key (
        report_artifact_id, import_id, report_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint fk_course_import_preview_clean_scan foreign key (
        clean_scan_id, import_id, clean_scan_verdict
    ) references course_import_scan(id, import_id, verdict),
    constraint ck_course_import_preview_rules check (rules_version = 'xlsx-v1'),
    constraint ck_course_import_preview_parser check (length(btrim(parser_version)) > 0),
    constraint ck_course_import_preview_counts check (
        row_count between 0 and 10000
        and level_count between 0 and 64
        and unit_count between 0 and 10000
        and topic_count between 0 and 10000
        and test_count between 0 and 10000
        and warning_count between 0 and 2000
        and error_count between 0 and 2000
        and warning_count + error_count <= 2000
    ),
    constraint ck_course_import_preview_report_sha check (
        validation_report_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint ck_course_import_preview_digest_shape check (
        (is_valid
            and row_count > 0
            and allocation_sha256 is not null and allocation_sha256 ~ '^[0-9a-f]{64}$'
            and preview_sha256 is not null and preview_sha256 ~ '^[0-9a-f]{64}$'
            and approval_binding_sha256 is not null and approval_binding_sha256 ~ '^[0-9a-f]{64}$'
            and error_count = 0)
        or (not is_valid
            and allocation_sha256 is null
            and preview_sha256 is null
            and approval_binding_sha256 is null
            and error_count > 0)
    )
);

create table course_import_preview_row (
    import_id uuid not null references course_import_preview(import_id),
    ordinal integer not null,
    source_sheet_ordinal integer not null,
    source_sheet_name varchar(31) not null,
    source_row_number integer not null,
    payload jsonb not null,
    primary key (import_id, ordinal),
    constraint ck_course_import_preview_row_ordinal check (ordinal between 1 and 10000),
    constraint ck_course_import_preview_row_source check (
        source_sheet_ordinal between 0 and 63
        and length(source_sheet_name) between 1 and 31
        and source_row_number between 1 and 1048576
    ),
    constraint ck_course_import_preview_row_payload check (jsonb_typeof(payload) = 'object')
);

create table course_import_preview_issue (
    import_id uuid not null references course_import_preview(import_id),
    ordinal integer not null,
    severity varchar(16) not null,
    issue_code varchar(80) not null,
    source_sheet_ordinal integer,
    source_sheet_name varchar(31),
    source_row_number integer,
    source_column_number integer,
    source_reference varchar(16),
    message varchar(500) not null,
    primary key (import_id, ordinal),
    constraint ck_course_import_issue_ordinal check (ordinal between 1 and 2000),
    constraint ck_course_import_issue_severity check (severity in ('WARNING', 'ERROR')),
    constraint ck_course_import_issue_code check (issue_code ~ '^[A-Z][A-Z0-9_]*$'),
    constraint ck_course_import_issue_message check (length(message) between 1 and 500),
    constraint ck_course_import_issue_source check (
        (source_sheet_ordinal is null and source_sheet_name is null and source_row_number is null
            and source_column_number is null and source_reference is null)
        or (source_sheet_ordinal is not null and source_sheet_ordinal between 0 and 63
            and source_sheet_name is not null
            and length(source_sheet_name) between 1 and 31
            and source_row_number is not null
            and source_row_number between 1 and 1048576
            and (source_column_number is null or source_column_number between 1 and 64))
    )
);

create table course_import_approval (
    id uuid primary key,
    import_id uuid not null unique references course_import(id),
    owner_user_id uuid not null references app_user(id),
    approval_binding_sha256 char(64) not null,
    source_sha256 char(64) not null,
    source_size_bytes bigint not null,
    quarantine_artifact_id uuid not null,
    quarantine_artifact_kind varchar(32)
        generated always as ('QUARANTINE_SOURCE') stored,
    archive_source_artifact_id uuid not null,
    archive_source_artifact_kind varchar(32)
        generated always as ('ARCHIVE_SOURCE') stored,
    report_artifact_id uuid not null,
    report_artifact_kind varchar(32)
        generated always as ('VALIDATION_REPORT') stored,
    scan_id uuid not null,
    scan_verdict varchar(16) generated always as ('CLEAN') stored,
    scanner_engine_version varchar(128) not null,
    scanner_signature_version varchar(128) not null,
    rules_version varchar(32) not null,
    parser_version varchar(160) not null,
    allocation_sha256 char(64) not null,
    preview_sha256 char(64) not null,
    validation_report_sha256 char(64) not null,
    approved_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint fk_course_import_approval_quarantine foreign key (
        quarantine_artifact_id, import_id, quarantine_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint fk_course_import_approval_archive foreign key (
        archive_source_artifact_id, import_id, archive_source_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint fk_course_import_approval_report foreign key (
        report_artifact_id, import_id, report_artifact_kind
    ) references course_import_artifact(id, import_id, artifact_kind),
    constraint fk_course_import_approval_clean_scan foreign key (
        scan_id, import_id, scan_verdict
    ) references course_import_scan(id, import_id, verdict),
    constraint ck_course_import_approval_digests check (
        approval_binding_sha256 ~ '^[0-9a-f]{64}$'
        and source_sha256 ~ '^[0-9a-f]{64}$'
        and allocation_sha256 ~ '^[0-9a-f]{64}$'
        and preview_sha256 ~ '^[0-9a-f]{64}$'
        and validation_report_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint ck_course_import_approval_source_size check (source_size_bytes between 1 and 26214400),
    constraint ck_course_import_approval_versions check (
        length(btrim(scanner_engine_version)) > 0
        and length(btrim(scanner_signature_version)) > 0
        and rules_version = 'xlsx-v1'
        and length(btrim(parser_version)) > 0
        and length(btrim(correlation_id)) > 0
    )
);

create table course_import_dead_letter (
    import_id uuid primary key references course_import(id),
    event_id uuid not null unique references outbox_event(id),
    reason_code varchar(80) not null,
    provider_message_id varchar(256) not null,
    created_at timestamptz not null,
    constraint ck_course_import_dead_letter_reason check (reason_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    constraint ck_course_import_dead_letter_message check (length(btrim(provider_message_id)) > 0)
);

alter table outbox_delivery add column next_attempt_at timestamptz;

create table course_import_dispatch_alert (
    event_id uuid primary key references outbox_event(id),
    import_id uuid not null references course_import(id),
    attempt_count integer not null,
    stable_code varchar(80) not null,
    created_at timestamptz not null,
    constraint ck_course_import_dispatch_alert_attempt check (attempt_count >= 5),
    constraint ck_course_import_dispatch_alert_code check (stable_code ~ '^[a-z0-9]+(-[a-z0-9]+)*$')
);

create table course_import_recovery_alert (
    import_id uuid primary key references course_import(id),
    disposition varchar(32) not null,
    created_at timestamptz not null,
    constraint ck_course_import_recovery_alert_disposition check (
        disposition in ('MATCHING_COMPLETED_OBJECT', 'AMBIGUOUS_OBJECT_VERSIONS')
    )
);

create trigger tr_course_import_part_append_only before update or delete on course_import_part
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_completed_part_append_only before update or delete on course_import_completed_part
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_event_append_only before update or delete on course_import_event
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_artifact_append_only before update or delete on course_import_artifact
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_processing_attempt_append_only before update or delete on course_import_processing_attempt
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_scan_append_only before update or delete on course_import_scan
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_preview_append_only before update or delete on course_import_preview
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_preview_row_append_only before update or delete on course_import_preview_row
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_preview_issue_append_only before update or delete on course_import_preview_issue
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_approval_append_only before update or delete on course_import_approval
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_dead_letter_append_only before update or delete on course_import_dead_letter
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_dispatch_alert_append_only before update or delete on course_import_dispatch_alert
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_recovery_alert_append_only before update or delete on course_import_recovery_alert
    for each row execute function reject_fact_mutation();

create function require_course_import_part_manifest() returns trigger language plpgsql as $$
declare
    target_id uuid;
    expected_size bigint;
    part_count integer;
    minimum_part integer;
    maximum_part integer;
    total_size bigint;
begin
    if tg_table_name = 'course_import' then
        target_id := new.id;
    else
        target_id := new.import_id;
    end if;
    select file_size_bytes into strict expected_size from course_import where id = target_id;
    select count(*), min(part_number), max(part_number), coalesce(sum(size_bytes), 0)
      into part_count, minimum_part, maximum_part, total_size
      from course_import_part where import_id = target_id;
    if part_count not between 1 and 5 or minimum_part <> 1 or maximum_part <> part_count
        or total_size <> expected_size
        or exists (
            select 1 from course_import_part
             where import_id = target_id and part_number < maximum_part and size_bytes <> 5242880
        ) then
        raise exception 'course_import multipart declaration is inconsistent' using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_import_requires_part_manifest
    after insert on course_import
    deferrable initially deferred
    for each row execute function require_course_import_part_manifest();

create constraint trigger tr_course_import_part_requires_manifest
    after insert on course_import_part
    deferrable initially deferred
    for each row execute function require_course_import_part_manifest();

create function enforce_course_import_artifact_provenance() returns trigger language plpgsql as $$
declare
    import_fact course_import%rowtype;
    archive_bucket_name varchar(255);
begin
    select * into strict import_fact from course_import where id = new.import_id for update;
    if import_fact.status <> 'PROCESSING'
        or import_fact.processing_lease_token is null
        or import_fact.processing_lease_expires_at <= clock_timestamp()
        or new.created_at < import_fact.updated_at
        or new.created_at > import_fact.processing_lease_expires_at then
        raise exception 'course_import_artifact requires an active processing lease' using errcode = '55000';
    end if;

    if new.artifact_kind = 'QUARANTINE_SOURCE' and (
        new.bucket_name is distinct from import_fact.quarantine_bucket
        or new.object_key is distinct from import_fact.quarantine_object_key
        or new.object_version_id is distinct from import_fact.accepted_version_id
        or new.etag is distinct from import_fact.accepted_etag
        or new.sha256 is distinct from import_fact.asserted_source_sha256
        or new.size_bytes is distinct from import_fact.file_size_bytes
        or new.media_type is distinct from import_fact.declared_media_type
    ) then
        raise exception 'quarantine artifact provenance is inconsistent' using errcode = '23514';
    elsif new.artifact_kind = 'ARCHIVE_SOURCE' and (
        new.bucket_name = import_fact.quarantine_bucket
        or new.object_key is distinct from (
            'archive/' || import_fact.owner_user_id || '/' || new.import_id || '/source/' || new.sha256 || '.xlsx'
        )
        or new.sha256 is distinct from import_fact.asserted_source_sha256
        or new.size_bytes is distinct from import_fact.file_size_bytes
        or new.media_type is distinct from import_fact.declared_media_type
    ) then
        raise exception 'archive source provenance is inconsistent' using errcode = '23514';
    elsif new.artifact_kind = 'VALIDATION_REPORT' then
        select bucket_name into archive_bucket_name
          from course_import_artifact
         where import_id = new.import_id and artifact_kind = 'ARCHIVE_SOURCE';
        if archive_bucket_name is null
            or new.bucket_name is distinct from archive_bucket_name
            or new.object_key is distinct from (
                'archive/' || import_fact.owner_user_id || '/' || new.import_id || '/reports/' || new.sha256 || '.json'
            )
            or new.media_type <> 'application/json'
            or new.size_bytes not between 1 and 4194304 then
            raise exception 'validation report provenance is inconsistent' using errcode = '23514';
        end if;
    end if;
    return new;
end;
$$;

create trigger tr_course_import_artifact_provenance before insert on course_import_artifact
    for each row execute function enforce_course_import_artifact_provenance();

create function enforce_course_import_scan_provenance() returns trigger language plpgsql as $$
declare
    import_fact course_import%rowtype;
    quarantine_fact course_import_artifact%rowtype;
begin
    select * into strict import_fact from course_import where id = new.import_id for update;
    select * into strict quarantine_fact from course_import_artifact where id = new.quarantine_artifact_id;
    if import_fact.status <> 'PROCESSING'
        or import_fact.processing_lease_token is null
        or import_fact.processing_lease_expires_at <= clock_timestamp()
        or new.attempt_number is distinct from import_fact.processing_attempts
        or quarantine_fact.import_id is distinct from new.import_id
        or quarantine_fact.artifact_kind <> 'QUARANTINE_SOURCE'
        or quarantine_fact.bucket_name is distinct from import_fact.quarantine_bucket
        or quarantine_fact.object_key is distinct from import_fact.quarantine_object_key
        or quarantine_fact.object_version_id is distinct from import_fact.accepted_version_id
        or quarantine_fact.etag is distinct from import_fact.accepted_etag
        or quarantine_fact.sha256 is distinct from import_fact.asserted_source_sha256
        or quarantine_fact.size_bytes is distinct from import_fact.file_size_bytes
        or new.source_sha256 is distinct from quarantine_fact.sha256
        or new.source_size_bytes is distinct from quarantine_fact.size_bytes then
        raise exception 'course_import_scan provenance is inconsistent' using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_course_import_scan_provenance before insert on course_import_scan
    for each row execute function enforce_course_import_scan_provenance();

create function enforce_course_import_preview_provenance() returns trigger language plpgsql as $$
declare
    quarantine_fact course_import_artifact%rowtype;
    archive_fact course_import_artifact%rowtype;
    report_fact course_import_artifact%rowtype;
    scan_fact course_import_scan%rowtype;
    import_fact course_import%rowtype;
begin
    select * into strict import_fact from course_import where id = new.import_id for update;
    select * into strict quarantine_fact from course_import_artifact where id = new.quarantine_artifact_id;
    select * into strict archive_fact from course_import_artifact where id = new.archive_source_artifact_id;
    select * into strict report_fact from course_import_artifact where id = new.report_artifact_id;
    select * into strict scan_fact from course_import_scan where id = new.clean_scan_id;

    if import_fact.status <> 'PROCESSING'
        or import_fact.processing_lease_token is null
        or import_fact.processing_lease_expires_at <= clock_timestamp()
        or quarantine_fact.import_id is distinct from new.import_id or quarantine_fact.artifact_kind <> 'QUARANTINE_SOURCE'
        or archive_fact.import_id is distinct from new.import_id or archive_fact.artifact_kind <> 'ARCHIVE_SOURCE'
        or report_fact.import_id is distinct from new.import_id or report_fact.artifact_kind <> 'VALIDATION_REPORT'
        or scan_fact.import_id is distinct from new.import_id or scan_fact.verdict <> 'CLEAN'
        or scan_fact.quarantine_artifact_id is distinct from quarantine_fact.id
        or scan_fact.source_sha256 is distinct from quarantine_fact.sha256
        or scan_fact.source_size_bytes is distinct from quarantine_fact.size_bytes
        or quarantine_fact.sha256 is distinct from archive_fact.sha256
        or quarantine_fact.size_bytes is distinct from archive_fact.size_bytes
        or quarantine_fact.sha256 is distinct from import_fact.asserted_source_sha256
        or quarantine_fact.size_bytes is distinct from import_fact.file_size_bytes
        or quarantine_fact.bucket_name is distinct from import_fact.quarantine_bucket
        or quarantine_fact.object_key is distinct from import_fact.quarantine_object_key
        or quarantine_fact.object_version_id is distinct from import_fact.accepted_version_id
        or quarantine_fact.etag is distinct from import_fact.accepted_etag
        or report_fact.sha256 is distinct from new.validation_report_sha256
        or new.rules_version is distinct from import_fact.rules_version then
        raise exception 'course_import_preview provenance is inconsistent' using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_course_import_preview_provenance before insert on course_import_preview
    for each row execute function enforce_course_import_preview_provenance();

create function enforce_course_import_approval_provenance() returns trigger language plpgsql as $$
declare
    import_fact course_import%rowtype;
    preview_fact course_import_preview%rowtype;
    scan_fact course_import_scan%rowtype;
begin
    select * into strict import_fact from course_import where id = new.import_id;
    select * into strict preview_fact from course_import_preview where import_id = new.import_id;
    select * into strict scan_fact from course_import_scan where id = new.scan_id;

    if import_fact.status <> 'PREVIEW_READY'
        or not preview_fact.is_valid
        or new.owner_user_id is distinct from import_fact.owner_user_id
        or new.approval_binding_sha256 is distinct from preview_fact.approval_binding_sha256
        or new.quarantine_artifact_id is distinct from preview_fact.quarantine_artifact_id
        or new.archive_source_artifact_id is distinct from preview_fact.archive_source_artifact_id
        or new.report_artifact_id is distinct from preview_fact.report_artifact_id
        or new.scan_id is distinct from preview_fact.clean_scan_id
        or new.source_sha256 is distinct from scan_fact.source_sha256
        or new.source_size_bytes is distinct from scan_fact.source_size_bytes
        or new.scanner_engine_version is distinct from scan_fact.scanner_engine_version
        or new.scanner_signature_version is distinct from scan_fact.scanner_signature_version
        or new.rules_version is distinct from preview_fact.rules_version
        or new.parser_version is distinct from preview_fact.parser_version
        or new.allocation_sha256 is distinct from preview_fact.allocation_sha256
        or new.preview_sha256 is distinct from preview_fact.preview_sha256
        or new.validation_report_sha256 is distinct from preview_fact.validation_report_sha256 then
        raise exception 'course_import_approval provenance is inconsistent' using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_course_import_approval_provenance before insert on course_import_approval
    for each row execute function enforce_course_import_approval_provenance();

create function require_course_import_preview_children() returns trigger language plpgsql as $$
declare
    actual_rows integer;
    first_row_ordinal integer;
    last_row_ordinal integer;
    actual_warnings integer;
    actual_errors integer;
    actual_issues integer;
    first_issue_ordinal integer;
    last_issue_ordinal integer;
    expected_rows integer;
    expected_warnings integer;
    expected_errors integer;
    expected_terminal_status varchar(32);
    actual_import_status varchar(32);
begin
    select p.row_count, p.warning_count, p.error_count,
           case when p.is_valid then 'PREVIEW_READY' else 'VALIDATION_FAILED' end,
           i.status
      into strict expected_rows, expected_warnings, expected_errors,
                  expected_terminal_status, actual_import_status
      from course_import_preview p
      join course_import i on i.id = p.import_id
     where p.import_id = new.import_id;
    select count(*), min(ordinal), max(ordinal)
      into actual_rows, first_row_ordinal, last_row_ordinal
      from course_import_preview_row where import_id = new.import_id;
    select count(*) filter (where severity = 'WARNING'), count(*) filter (where severity = 'ERROR'),
           count(*), min(ordinal), max(ordinal)
      into actual_warnings, actual_errors, actual_issues, first_issue_ordinal, last_issue_ordinal
      from course_import_preview_issue where import_id = new.import_id;
    if actual_rows <> expected_rows
        or actual_warnings <> expected_warnings
        or actual_errors <> expected_errors
        or actual_import_status <> expected_terminal_status
        or (actual_rows > 0 and (first_row_ordinal <> 1 or last_row_ordinal <> actual_rows))
        or (actual_issues > 0 and (first_issue_ordinal <> 1 or last_issue_ordinal <> actual_issues)) then
        raise exception 'course_import_preview child counts are inconsistent' using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_import_preview_requires_children
    after insert on course_import_preview
    deferrable initially deferred
    for each row execute function require_course_import_preview_children();

create function require_active_import_preview_lease() returns trigger language plpgsql as $$
begin
    perform 1 from course_import i
     where i.id = new.import_id and i.status = 'PROCESSING'
       and i.processing_lease_token is not null
       and i.processing_lease_expires_at > clock_timestamp()
     for update;
    if not found then
        raise exception 'course import preview children require an active processing lease'
            using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_course_import_preview_row_active_lease before insert on course_import_preview_row
    for each row execute function require_active_import_preview_lease();

create trigger tr_course_import_preview_issue_active_lease before insert on course_import_preview_issue
    for each row execute function require_active_import_preview_lease();

create function enforce_course_import_initial_state() returns trigger language plpgsql as $$
begin
    if new.status <> 'UPLOADING'
        or new.state_version <> 0
        or new.processing_attempts <> 0
        or new.accepted_version_id is not null
        or new.accepted_etag is not null
        or new.accepted_size_bytes is not null
        or new.accepted_checksum_sha256 is not null
        or new.processing_lease_token is not null
        or new.processing_lease_expires_at is not null
        or new.failure_code is not null
        or new.updated_at is distinct from new.created_at then
        raise exception 'course_import must begin in the canonical UPLOADING state' using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_course_import_initial_state before insert on course_import
    for each row execute function enforce_course_import_initial_state();

create function enforce_course_import_transition() returns trigger language plpgsql as $$
begin
    if row(
        new.id, new.owner_user_id, new.rules_version, new.original_file_name,
        new.declared_media_type, new.file_size_bytes, new.asserted_source_sha256,
        new.quarantine_bucket, new.quarantine_object_key, new.multipart_upload_id,
        new.upload_expires_at, new.created_at
    ) is distinct from row(
        old.id, old.owner_user_id, old.rules_version, old.original_file_name,
        old.declared_media_type, old.file_size_bytes, old.asserted_source_sha256,
        old.quarantine_bucket, old.quarantine_object_key, old.multipart_upload_id,
        old.upload_expires_at, old.created_at
    ) then
        raise exception 'course_import immutable intake fields cannot change' using errcode = '55000';
    end if;
    if old.status <> 'UPLOADING' and row(
        new.accepted_version_id, new.accepted_etag, new.accepted_size_bytes, new.accepted_checksum_sha256
    ) is distinct from row(
        old.accepted_version_id, old.accepted_etag, old.accepted_size_bytes, old.accepted_checksum_sha256
    ) then
        raise exception 'course_import accepted object identity cannot change' using errcode = '55000';
    end if;
    if new.state_version <> old.state_version + 1 then
        raise exception 'course_import state_version must increase by exactly one' using errcode = '55000';
    end if;
    if (
        old.status = 'QUEUED' and new.status = 'PROCESSING'
        and new.processing_attempts <> old.processing_attempts + 1
    ) or (
        not (old.status = 'QUEUED' and new.status = 'PROCESSING')
        and new.processing_attempts <> old.processing_attempts
    ) then
        raise exception 'course_import processing_attempts change is inconsistent' using errcode = '55000';
    end if;
    if new.status = 'QUEUED' and new.processing_attempts >= 5 then
        raise exception 'course_import cannot return to QUEUED after exhausting five processing attempts'
            using errcode = '55000';
    end if;
    if old.status = 'QUEUED' and new.status = 'PROCESSING' and (
        new.processing_lease_expires_at <= new.updated_at
        or new.processing_lease_expires_at > new.updated_at + interval '7 minutes'
    ) then
        raise exception 'course_import processing lease must be positive and bounded to seven minutes'
            using errcode = '55000';
    end if;
    if (
        old.status = 'PROCESSING'
        and new.status in ('QUEUED', 'MALWARE_REJECTED', 'PROCESSING_FAILED')
        and new.failure_code is null
    ) or (
        not (old.status = 'PROCESSING' and new.status in ('QUEUED', 'MALWARE_REJECTED', 'PROCESSING_FAILED'))
        and new.failure_code is not null
    ) then
        raise exception 'course_import failure_code is inconsistent with the transition' using errcode = '55000';
    end if;
    if not (
        (old.status = 'UPLOADING' and new.status in ('QUEUED', 'EXPIRED'))
        or (old.status = 'QUEUED' and new.status = 'PROCESSING')
        or (old.status = 'PROCESSING' and new.status in (
            'QUEUED', 'PREVIEW_READY', 'VALIDATION_FAILED', 'MALWARE_REJECTED', 'PROCESSING_FAILED'
        ))
        or (old.status = 'PREVIEW_READY' and new.status = 'APPROVED')
    ) then
        raise exception 'course_import transition % -> % is not allowed', old.status, new.status
            using errcode = '55000';
    end if;
    if new.updated_at < old.updated_at then
        raise exception 'course_import updated_at cannot move backwards' using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_course_import_transition before update on course_import
    for each row execute function enforce_course_import_transition();

create function require_course_import_state_event() returns trigger language plpgsql as $$
declare
    expected_from_status varchar(32);
    expected_event_type varchar(80);
    expected_actor_user_id uuid;
    expected_stable_code varchar(80);
begin
    if tg_op = 'INSERT' then
        expected_from_status := null;
        expected_event_type := 'import-created';
        expected_actor_user_id := new.owner_user_id;
        expected_stable_code := null;
    else
        expected_from_status := old.status;
        expected_event_type := case
            when old.status = 'UPLOADING' and new.status = 'QUEUED' then 'upload-completed'
            when old.status = 'UPLOADING' and new.status = 'EXPIRED' then 'upload-expired'
            when old.status = 'QUEUED' and new.status = 'PROCESSING' then 'processing-started'
            when old.status = 'PROCESSING' and new.status = 'QUEUED' then 'processing-retry-scheduled'
            when old.status = 'PROCESSING' and new.status = 'PREVIEW_READY' then 'preview-ready'
            when old.status = 'PROCESSING' and new.status = 'VALIDATION_FAILED' then 'validation-failed'
            when old.status = 'PROCESSING' and new.status = 'MALWARE_REJECTED' then 'malware-rejected'
            when old.status = 'PROCESSING' and new.status = 'PROCESSING_FAILED' then 'processing-failed'
            when old.status = 'PREVIEW_READY' and new.status = 'APPROVED' then 'import-approved'
            else null
        end;
        expected_actor_user_id := case
            when old.status = 'UPLOADING' and new.status = 'QUEUED' then new.owner_user_id
            when old.status = 'PREVIEW_READY' and new.status = 'APPROVED' then new.owner_user_id
            else null
        end;
        expected_stable_code := case
            when old.status = 'UPLOADING' and new.status = 'EXPIRED' then 'upload-expired'
            when old.status = 'PROCESSING' then new.failure_code
            else null
        end;
    end if;
    if not exists (
        select 1
          from course_import_event e
         where e.import_id = new.id
           and e.state_version = new.state_version
           and e.from_status is not distinct from expected_from_status
           and e.to_status = new.status
           and e.event_type is not distinct from expected_event_type
           and e.actor_user_id is not distinct from expected_actor_user_id
           and e.stable_code is not distinct from expected_stable_code
           and e.occurred_at = new.updated_at
    ) then
        raise exception 'course_import state transition requires one matching append-only event'
            using errcode = '55000';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_import_requires_state_event
    after insert or update on course_import
    deferrable initially deferred
    for each row execute function require_course_import_state_event();

create function require_course_import_terminal_prerequisite() returns trigger language plpgsql as $$
declare
    expected_attempt_outcome varchar(32);
    lease_is_expired boolean;
    transition_records_expired_lease boolean;
    uses_expired_lease_code boolean;
begin
    if new.status = 'QUEUED' and (
        exists (
            select 1 from course_import_part p
             where p.import_id = new.id and not exists (
                 select 1 from course_import_completed_part c
                  where c.import_id = p.import_id and c.part_number = p.part_number
                    and c.sha256_base64 = p.sha256_base64
             )
        )
        or new.accepted_checksum_sha256 not like '%-' || (
            select count(*)::text from course_import_part where import_id = new.id
        )
    ) then
        raise exception 'QUEUED requires the exact completed multipart manifest' using errcode = '55000';
    end if;
    if old.status = 'UPLOADING' and new.status = 'QUEUED' and not exists (
        select 1
          from outbox_event o
          join outbox_delivery d on d.event_id = o.id
          join course_import_event e
            on e.import_id = new.id
           and e.state_version = new.state_version
           and e.from_status = 'UPLOADING'
           and e.to_status = 'QUEUED'
         where o.aggregate_type = 'course-import'
           and o.aggregate_id = new.id
           and o.event_type = 'import.processing-requested.v1'
           and o.schema_version = 1
           and o.payload = jsonb_build_object('eventId', o.id, 'importId', new.id)
           and o.correlation_id = e.correlation_id
           and o.occurred_at = new.updated_at
           and d.attempt_count = 0
           and d.published_at is null
    ) then
        raise exception 'UPLOADING to QUEUED requires a matching transactional outbox delivery'
            using errcode = '55000';
    end if;
    if old.status = 'PROCESSING' then
        lease_is_expired := old.processing_lease_expires_at <= clock_timestamp();
        transition_records_expired_lease := old.processing_lease_expires_at <= new.updated_at;
        uses_expired_lease_code := new.failure_code is not distinct from 'processing-lease-expired';
        expected_attempt_outcome := case new.status
            when 'QUEUED' then 'RETRYABLE_FAILURE'
            when 'PREVIEW_READY' then 'PREVIEW_READY'
            when 'VALIDATION_FAILED' then 'VALIDATION_FAILED'
            when 'MALWARE_REJECTED' then 'MALWARE_REJECTED'
            when 'PROCESSING_FAILED' then 'EXHAUSTED'
            else null
        end;
        if (
            lease_is_expired <> uses_expired_lease_code
            or transition_records_expired_lease <> uses_expired_lease_code
        ) or (
            uses_expired_lease_code
            and (
                (new.processing_attempts < 5 and new.status <> 'QUEUED')
                or (new.processing_attempts = 5 and new.status <> 'PROCESSING_FAILED')
            )
        ) or expected_attempt_outcome is null or not exists (
            select 1
              from course_import_processing_attempt a
             where a.import_id = new.id
               and a.attempt_number = new.processing_attempts
               and a.lease_token = old.processing_lease_token
               and a.outcome = expected_attempt_outcome
               and a.stable_code is not distinct from new.failure_code
               and a.started_at = old.updated_at
               and a.finished_at = new.updated_at
        ) then
            raise exception 'PROCESSING transition requires a matching immutable processing attempt'
                using errcode = '55000';
        end if;
    end if;
    if new.status = 'PREVIEW_READY' and not exists (
        select 1 from course_import_preview p where p.import_id = new.id and p.is_valid
    ) then
        raise exception 'PREVIEW_READY requires a valid immutable preview' using errcode = '55000';
    end if;
    if new.status = 'VALIDATION_FAILED' and not exists (
        select 1 from course_import_preview p where p.import_id = new.id and not p.is_valid
    ) then
        raise exception 'VALIDATION_FAILED requires an invalid immutable preview' using errcode = '55000';
    end if;
    if new.status = 'MALWARE_REJECTED' and not exists (
        select 1 from course_import_scan s where s.import_id = new.id and s.verdict = 'MALWARE'
    ) then
        raise exception 'MALWARE_REJECTED requires a malware scan fact' using errcode = '55000';
    end if;
    if new.status = 'APPROVED' and not exists (
        select 1 from course_import_approval a where a.import_id = new.id
    ) then
        raise exception 'APPROVED requires an immutable approval fact' using errcode = '55000';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_import_terminal_prerequisite
    after update on course_import
    deferrable initially deferred
    for each row execute function require_course_import_terminal_prerequisite();
