-- A draft course has no learner-active release. Published/hidden/removed courses
-- continue to require one ACTIVE release, validated at the transaction boundary.
alter table course alter column active_release_id drop not null;

create or replace function validate_active_release_reference() returns trigger language plpgsql as $$
declare
    target_course_id uuid;
    current_publication_status varchar(24);
    current_active_release_id uuid;
    referenced_count integer;
begin
    if tg_table_name = 'course' then
        target_course_id := new.id;
    else
        target_course_id := new.course_id;
    end if;
    select publication_status, active_release_id
      into current_publication_status, current_active_release_id
      from course
     where id = target_course_id;

    if current_publication_status = 'DRAFT' then
        if current_active_release_id is not null then
            raise exception 'A DRAFT course cannot reference an active release' using errcode = '23514';
        end if;
    else
        if current_active_release_id is null then
            raise exception 'A non-draft course must reference an ACTIVE release' using errcode = '23514';
        end if;
        select count(*) into referenced_count
          from course_release
         where id = current_active_release_id
           and course_id = target_course_id
           and status = 'ACTIVE';
        if referenced_count <> 1 then
            raise exception 'course.active_release_id must reference an ACTIVE release' using errcode = '23514';
        end if;
    end if;

    if tg_table_name = 'course_release' then
        if new.status <> 'ACTIVE' and exists (
            select 1 from course
             where id = new.course_id and active_release_id = new.id
        ) then
            raise exception 'A referenced active course release cannot be retired' using errcode = '23514';
        end if;
    end if;
    return null;
end;
$$;

drop trigger tr_course_active_release_valid on course;
create constraint trigger tr_course_active_release_valid
    after insert or update of active_release_id, publication_status on course
    deferrable initially deferred
    for each row execute function validate_active_release_reference();

-- V9 did not retain normalized settings. Existing previews remain valid approval
-- evidence but are deliberately not reconstructed or made commit-eligible.
alter table course_import_preview
    add column content_schema_version varchar(32),
    add column settings_payload jsonb,
    add constraint ck_course_import_preview_content_payload check (
        (content_schema_version is null and settings_payload is null)
        or (
            content_schema_version = 'import-content-v1'
            and is_valid
            and jsonb_typeof(settings_payload) = 'object'
            and settings_payload ?& array[
                'courseName', 'targetLanguageCode', 'targetLanguageName',
                'supportLanguageCodes', 'defaultSupportLanguageCode',
                'defaultTestMode', 'visibility', 'targetTestSize',
                'minimumLastAutomaticTestSize', 'fillFixedTests',
                'completionThresholdPercent', 'pricingSource',
                'maximumTypedAlternativeAnswers', 'offlineMode'
            ]
            and settings_payload - array[
                'courseName', 'targetLanguageCode', 'targetLanguageName',
                'supportLanguageCodes', 'defaultSupportLanguageCode',
                'defaultTestMode', 'visibility', 'targetTestSize',
                'minimumLastAutomaticTestSize', 'fillFixedTests',
                'completionThresholdPercent', 'pricingSource',
                'maximumTypedAlternativeAnswers', 'offlineMode'
            ] = '{}'::jsonb
            and jsonb_typeof(settings_payload -> 'supportLanguageCodes') = 'array'
        )
    );

create table content_change_set (
    id uuid primary key,
    course_id uuid not null references course(id),
    owner_user_id uuid not null references app_user(id),
    base_release_id uuid,
    source_type varchar(32) not null,
    source_reference_id uuid not null,
    status varchar(24) not null,
    created_at timestamptz not null,
    committed_at timestamptz,
    correlation_id varchar(128) not null,
    constraint uq_content_change_set_identity unique (id, course_id),
    constraint uq_content_change_set_source unique (source_type, source_reference_id),
    constraint fk_content_change_set_base_release foreign key (base_release_id, course_id)
        references course_release(id, course_id),
    constraint ck_content_change_set_source check (source_type in ('EXCEL_IMPORT', 'MOBILE_AUTHORING')),
    constraint ck_content_change_set_status check (status in ('DRAFT', 'COMMITTED', 'ABANDONED')),
    constraint ck_content_change_set_time check (
        (status = 'DRAFT' and committed_at is null)
        or (status = 'COMMITTED' and committed_at is not null and committed_at >= created_at)
        or (status = 'ABANDONED' and committed_at is null)
    ),
    constraint ck_content_change_set_initial_import check (
        source_type <> 'EXCEL_IMPORT'
        or (base_release_id is null and status = 'COMMITTED' and committed_at is not null)
    ),
    constraint ck_content_change_set_correlation check (length(btrim(correlation_id)) > 0)
);

create table content_change_set_event (
    id uuid primary key,
    content_change_set_id uuid not null references content_change_set(id),
    event_type varchar(32) not null,
    actor_user_id uuid not null references app_user(id),
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint uq_content_change_set_event unique (content_change_set_id, event_type),
    constraint ck_content_change_set_event_type check (event_type in ('CREATED', 'COMMITTED', 'ABANDONED')),
    constraint ck_content_change_set_event_correlation check (length(btrim(correlation_id)) > 0)
);

create table content_level (
    id uuid primary key,
    course_id uuid not null references course(id),
    created_at timestamptz not null,
    constraint uq_content_level_identity unique (id, course_id)
);

create table content_unit (
    id uuid primary key,
    course_id uuid not null references course(id),
    created_at timestamptz not null,
    constraint uq_content_unit_identity unique (id, course_id)
);

create table content_topic (
    id uuid primary key,
    course_id uuid not null references course(id),
    created_at timestamptz not null,
    constraint uq_content_topic_identity unique (id, course_id)
);

create table content_level_revision (
    id uuid primary key,
    level_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    revision_number integer not null,
    title varchar(2000) not null,
    hidden boolean not null,
    created_at timestamptz not null,
    constraint fk_content_level_revision_level foreign key (level_id, course_id)
        references content_level(id, course_id),
    constraint fk_content_level_revision_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint uq_content_level_revision_number unique (level_id, revision_number),
    constraint uq_content_level_revision_identity unique (id, level_id, course_id),
    constraint uq_content_level_revision_course_identity unique (id, course_id),
    constraint ck_content_level_revision_number check (revision_number > 0),
    constraint ck_content_level_revision_title check (length(title) between 1 and 2000)
);

create table content_unit_revision (
    id uuid primary key,
    unit_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    revision_number integer not null,
    title varchar(2000) not null,
    hidden boolean not null,
    created_at timestamptz not null,
    constraint fk_content_unit_revision_unit foreign key (unit_id, course_id)
        references content_unit(id, course_id),
    constraint fk_content_unit_revision_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint uq_content_unit_revision_number unique (unit_id, revision_number),
    constraint uq_content_unit_revision_identity unique (id, unit_id, course_id),
    constraint uq_content_unit_revision_course_identity unique (id, course_id),
    constraint ck_content_unit_revision_number check (revision_number > 0),
    constraint ck_content_unit_revision_title check (length(title) between 1 and 2000)
);

create table content_topic_revision (
    id uuid primary key,
    topic_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    revision_number integer not null,
    title varchar(2000) not null,
    hidden boolean not null,
    created_at timestamptz not null,
    constraint fk_content_topic_revision_topic foreign key (topic_id, course_id)
        references content_topic(id, course_id),
    constraint fk_content_topic_revision_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint uq_content_topic_revision_number unique (topic_id, revision_number),
    constraint uq_content_topic_revision_identity unique (id, topic_id, course_id),
    constraint uq_content_topic_revision_course_identity unique (id, course_id),
    constraint ck_content_topic_revision_number check (revision_number > 0),
    constraint ck_content_topic_revision_title check (length(title) between 1 and 2000)
);

create table course_release_level_revision (
    course_release_id uuid not null,
    level_revision_id uuid not null,
    level_id uuid not null,
    course_id uuid not null,
    position integer not null,
    primary key (course_release_id, level_revision_id),
    constraint fk_release_level_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_release_level_revision foreign key (level_revision_id, level_id, course_id)
        references content_level_revision(id, level_id, course_id),
    constraint uq_release_level_stable unique (course_release_id, level_id),
    constraint uq_release_level_course_identity unique (course_release_id, level_revision_id, course_id),
    constraint uq_release_level_position unique (course_release_id, position),
    constraint ck_release_level_position check (position > 0)
);

create table course_release_unit_revision (
    course_release_id uuid not null,
    parent_level_revision_id uuid not null,
    unit_revision_id uuid not null,
    unit_id uuid not null,
    course_id uuid not null,
    position integer not null,
    primary key (course_release_id, unit_revision_id),
    constraint fk_release_unit_parent foreign key (
        course_release_id, parent_level_revision_id, course_id
    ) references course_release_level_revision(course_release_id, level_revision_id, course_id),
    constraint fk_release_unit_revision foreign key (unit_revision_id, unit_id, course_id)
        references content_unit_revision(id, unit_id, course_id),
    constraint uq_release_unit_stable unique (course_release_id, unit_id),
    constraint uq_release_unit_course_identity unique (course_release_id, unit_revision_id, course_id),
    constraint uq_release_unit_position unique (course_release_id, parent_level_revision_id, position),
    constraint ck_release_unit_position check (position > 0)
);

create table course_release_topic_revision (
    course_release_id uuid not null,
    parent_unit_revision_id uuid not null,
    topic_revision_id uuid not null,
    topic_id uuid not null,
    course_id uuid not null,
    position integer not null,
    primary key (course_release_id, topic_revision_id),
    constraint fk_release_topic_parent foreign key (
        course_release_id, parent_unit_revision_id, course_id
    ) references course_release_unit_revision(course_release_id, unit_revision_id, course_id),
    constraint fk_release_topic_revision foreign key (topic_revision_id, topic_id, course_id)
        references content_topic_revision(id, topic_id, course_id),
    constraint uq_release_topic_stable unique (course_release_id, topic_id),
    constraint uq_release_topic_course_identity unique (course_release_id, topic_revision_id, course_id),
    constraint uq_release_topic_position unique (course_release_id, parent_unit_revision_id, position),
    constraint ck_release_topic_position check (position > 0)
);

create table course_release_test_hierarchy (
    course_release_id uuid not null,
    parent_topic_revision_id uuid not null,
    test_revision_id uuid not null,
    test_id uuid not null,
    course_id uuid not null,
    position integer not null,
    primary key (course_release_id, test_revision_id),
    constraint fk_release_test_hierarchy_parent foreign key (
        course_release_id, parent_topic_revision_id, course_id
    ) references course_release_topic_revision(course_release_id, topic_revision_id, course_id),
    constraint fk_release_test_hierarchy_flat foreign key (
        course_release_id, test_revision_id, course_id
    ) references course_release_test_revision(course_release_id, test_revision_id, course_id),
    constraint uq_release_test_hierarchy_stable unique (course_release_id, test_id),
    constraint uq_release_test_hierarchy_position unique (
        course_release_id, parent_topic_revision_id, position
    ),
    constraint ck_release_test_hierarchy_position check (position > 0)
);

create function canonical_language_array(values_array varchar[]) returns boolean
immutable strict language plpgsql as $$
declare
    language_value varchar;
begin
    if cardinality(values_array) < 1 or cardinality(values_array) > 64 then
        return false;
    end if;
    foreach language_value in array values_array loop
        if language_value !~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$' then
            return false;
        end if;
    end loop;
    return cardinality(values_array) = cardinality(array(select distinct unnest(values_array)));
end;
$$;

create table course_import_draft_settings (
    course_id uuid primary key references course(id),
    content_change_set_id uuid not null unique,
    course_name varchar(160) not null,
    target_language_code varchar(35) not null,
    target_language_name varchar(160) not null,
    support_language_codes varchar(35)[] not null,
    default_support_language_code varchar(35) not null,
    default_test_mode varchar(32) not null,
    visibility varchar(16) not null,
    target_test_size integer not null,
    minimum_last_automatic_test_size integer not null,
    fill_fixed_tests boolean not null,
    completion_threshold_percent integer not null,
    pricing_source varchar(32) not null,
    maximum_typed_alternative_answers integer not null,
    offline_mode varchar(32) not null,
    created_at timestamptz not null,
    constraint fk_course_import_settings_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint ck_course_import_settings_name check (length(course_name) between 1 and 160),
    constraint ck_course_import_settings_target_name check (length(target_language_name) between 1 and 160),
    constraint ck_course_import_settings_languages check (
        canonical_language_array(support_language_codes)
        and target_language_code ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
        and default_support_language_code = any(support_language_codes)
        and not target_language_code = any(support_language_codes)
    ),
    constraint ck_course_import_settings_mode check (
        default_test_mode in ('MIXED', 'WORD', 'MATCHING', 'MULTIPLE_CHOICE_CLOZE', 'TYPED_CLOZE')
    ),
    constraint ck_course_import_settings_visibility check (visibility in ('PUBLIC', 'PRIVATE')),
    constraint ck_course_import_settings_allocation check (
        target_test_size > 0
        and minimum_last_automatic_test_size between 1 and target_test_size
    ),
    constraint ck_course_import_settings_completion check (completion_threshold_percent between 50 and 100),
    constraint ck_course_import_settings_fixed_values check (
        pricing_source = 'APPLICATION'
        and maximum_typed_alternative_answers = 1
        and offline_mode = 'SCORELESS_PRACTICE'
    )
);

create table test_revision_authoring (
    test_revision_id uuid primary key,
    test_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    source_test_number integer not null,
    allocation_kind varchar(16) not null,
    resolved_mode varchar(32) not null,
    hidden boolean not null,
    created_at timestamptz not null,
    constraint fk_test_authoring_revision foreign key (test_revision_id, test_id, course_id)
        references test_revision(id, test_id, course_id),
    constraint fk_test_authoring_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint ck_test_authoring_number check (source_test_number > 0),
    constraint ck_test_authoring_allocation check (allocation_kind in ('FIXED', 'AUTOMATIC')),
    constraint ck_test_authoring_mode check (
        resolved_mode in ('MIXED', 'WORD', 'MULTIPLE_CHOICE_CLOZE', 'TYPED_CLOZE')
    )
);

create table question_revision_authoring (
    question_revision_id uuid primary key,
    question_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    ordinal integer not null,
    source_sheet_ordinal integer not null,
    source_sheet_name varchar(31) not null,
    source_row_number integer not null,
    allocation_reason varchar(32) not null,
    record_type varchar(32) not null,
    target_text varchar(2000) not null,
    matching_group varchar(2000),
    hidden boolean not null,
    note varchar(2000),
    created_at timestamptz not null,
    constraint fk_question_authoring_revision foreign key (question_revision_id, question_id, course_id)
        references question_revision(id, question_id, course_id),
    constraint fk_question_authoring_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint uq_question_authoring_ordinal unique (content_change_set_id, ordinal),
    constraint uq_question_authoring_source unique (
        content_change_set_id, source_sheet_ordinal, source_row_number
    ),
    constraint ck_question_authoring_ordinal check (ordinal between 1 and 10000),
    constraint ck_question_authoring_source check (
        source_sheet_ordinal between 0 and 63
        and length(source_sheet_name) between 1 and 31
        and source_row_number between 1 and 1048576
    ),
    constraint ck_question_authoring_allocation check (
        allocation_reason in ('FIXED_DECLARATION', 'FIXED_TEST_FILL', 'AUTOMATIC')
    ),
    constraint ck_question_authoring_type check (
        record_type in ('WORD', 'MULTIPLE_CHOICE_CLOZE', 'TYPED_CLOZE')
    ),
    constraint ck_question_authoring_target check (length(target_text) between 1 and 2000),
    constraint ck_question_authoring_matching check (
        matching_group is null or length(matching_group) between 1 and 2000
    ),
    constraint ck_question_authoring_note check (note is null or length(note) between 1 and 2000)
);

create table question_revision_translation (
    question_revision_id uuid not null,
    course_id uuid not null,
    support_language varchar(35) not null,
    translation_text varchar(2000) not null,
    created_at timestamptz not null,
    primary key (question_revision_id, support_language),
    constraint fk_question_translation_revision foreign key (question_revision_id, course_id)
        references question_revision(id, course_id),
    constraint fk_question_translation_language foreign key (course_id, support_language)
        references course_support_language(course_id, language_code),
    constraint ck_question_translation_text check (length(translation_text) between 1 and 2000)
);

create table question_revision_authored_distractor (
    question_revision_id uuid not null,
    course_id uuid not null,
    language_code varchar(35) not null,
    position integer not null,
    distractor_text varchar(2000) not null,
    created_at timestamptz not null,
    primary key (question_revision_id, position),
    constraint fk_question_distractor_revision foreign key (question_revision_id, course_id)
        references question_revision(id, course_id),
    constraint ck_question_distractor_language check (
        language_code ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    ),
    constraint ck_question_distractor_position check (position between 1 and 3),
    constraint ck_question_distractor_text check (length(distractor_text) between 1 and 2000),
    constraint uq_question_distractor_text unique (question_revision_id, language_code, distractor_text)
);

create table course_import_commit (
    id uuid primary key,
    import_id uuid not null unique references course_import(id),
    owner_user_id uuid not null references app_user(id),
    approval_id uuid not null unique references course_import_approval(id),
    approval_binding_sha256 char(64) not null,
    content_schema_version varchar(32) not null,
    source_sha256 char(64) not null,
    allocation_sha256 char(64) not null,
    preview_sha256 char(64) not null,
    course_id uuid not null unique references course(id),
    content_change_set_id uuid not null unique references content_change_set(id),
    draft_release_id uuid not null unique references course_release(id),
    outbox_event_id uuid not null unique references outbox_event(id),
    row_count integer not null,
    level_count integer not null,
    unit_count integer not null,
    topic_count integer not null,
    test_count integer not null,
    committed_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint ck_course_import_commit_schema check (content_schema_version = 'import-content-v1'),
    constraint ck_course_import_commit_digests check (
        approval_binding_sha256 ~ '^[0-9a-f]{64}$'
        and source_sha256 ~ '^[0-9a-f]{64}$'
        and allocation_sha256 ~ '^[0-9a-f]{64}$'
        and preview_sha256 ~ '^[0-9a-f]{64}$'
    ),
    constraint ck_course_import_commit_counts check (
        row_count between 1 and 10000
        and level_count between 1 and 64
        and unit_count between 1 and 10000
        and topic_count between 1 and 10000
        and test_count between 1 and 10000
    ),
    constraint ck_course_import_commit_correlation check (length(btrim(correlation_id)) > 0)
);

-- New authored facts and manifests are immutable. The mutable change-set summary
-- has its own guarded lifecycle for later mobile authoring.
create trigger tr_content_change_set_event_append_only before update or delete on content_change_set_event
    for each row execute function reject_fact_mutation();
create trigger tr_content_level_append_only before update or delete on content_level
    for each row execute function reject_fact_mutation();
create trigger tr_content_unit_append_only before update or delete on content_unit
    for each row execute function reject_fact_mutation();
create trigger tr_content_topic_append_only before update or delete on content_topic
    for each row execute function reject_fact_mutation();
create trigger tr_content_level_revision_append_only before update or delete on content_level_revision
    for each row execute function reject_fact_mutation();
create trigger tr_content_unit_revision_append_only before update or delete on content_unit_revision
    for each row execute function reject_fact_mutation();
create trigger tr_content_topic_revision_append_only before update or delete on content_topic_revision
    for each row execute function reject_fact_mutation();
create trigger tr_release_level_revision_append_only before update or delete on course_release_level_revision
    for each row execute function reject_fact_mutation();
create trigger tr_release_unit_revision_append_only before update or delete on course_release_unit_revision
    for each row execute function reject_fact_mutation();
create trigger tr_release_topic_revision_append_only before update or delete on course_release_topic_revision
    for each row execute function reject_fact_mutation();
create trigger tr_release_test_hierarchy_append_only before update or delete on course_release_test_hierarchy
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_draft_settings_append_only before update or delete on course_import_draft_settings
    for each row execute function reject_fact_mutation();
create trigger tr_test_revision_authoring_append_only before update or delete on test_revision_authoring
    for each row execute function reject_fact_mutation();
create trigger tr_question_revision_authoring_append_only before update or delete on question_revision_authoring
    for each row execute function reject_fact_mutation();
create trigger tr_question_revision_translation_append_only before update or delete on question_revision_translation
    for each row execute function reject_fact_mutation();
create trigger tr_question_revision_distractor_append_only before update or delete on question_revision_authored_distractor
    for each row execute function reject_fact_mutation();
create trigger tr_course_import_commit_append_only before update or delete on course_import_commit
    for each row execute function reject_fact_mutation();

create function protect_content_change_set() returns trigger language plpgsql as $$
begin
    if tg_op = 'DELETE' then
        raise exception 'content_change_set cannot be deleted' using errcode = '55000';
    end if;
    if tg_op = 'UPDATE' then
        if row(
            new.id, new.course_id, new.owner_user_id, new.base_release_id,
            new.source_type, new.source_reference_id, new.created_at, new.correlation_id
        ) is distinct from row(
            old.id, old.course_id, old.owner_user_id, old.base_release_id,
            old.source_type, old.source_reference_id, old.created_at, old.correlation_id
        ) then
            raise exception 'content_change_set identity and source are immutable' using errcode = '55000';
        end if;
        if old.status <> 'DRAFT' or new.status not in ('COMMITTED', 'ABANDONED') then
            raise exception 'content_change_set has an invalid lifecycle transition' using errcode = '55000';
        end if;
    end if;
    return new;
end;
$$;

create trigger tr_content_change_set_lifecycle before update or delete on content_change_set
    for each row execute function protect_content_change_set();

create function require_draft_authoring_parent() returns trigger language plpgsql as $$
declare
    parent_status varchar(24);
begin
    if tg_table_name in (
        'course_release_level_revision', 'course_release_unit_revision',
        'course_release_topic_revision', 'course_release_test_hierarchy'
    ) then
        select status into parent_status from course_release where id = new.course_release_id;
    elsif tg_table_name = 'test_revision_authoring' then
        select status into parent_status from test_revision where id = new.test_revision_id;
    elsif tg_table_name in (
        'question_revision_authoring', 'question_revision_translation',
        'question_revision_authored_distractor'
    ) then
        select status into parent_status from question_revision where id = new.question_revision_id;
    end if;
    if parent_status is distinct from 'DRAFT' then
        raise exception 'Authoring content can be added only to a DRAFT parent' using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_release_level_requires_draft before insert on course_release_level_revision
    for each row execute function require_draft_authoring_parent();
create trigger tr_release_unit_requires_draft before insert on course_release_unit_revision
    for each row execute function require_draft_authoring_parent();
create trigger tr_release_topic_requires_draft before insert on course_release_topic_revision
    for each row execute function require_draft_authoring_parent();
create trigger tr_release_test_hierarchy_requires_draft before insert on course_release_test_hierarchy
    for each row execute function require_draft_authoring_parent();
create trigger tr_test_authoring_requires_draft before insert on test_revision_authoring
    for each row execute function require_draft_authoring_parent();
create trigger tr_question_authoring_requires_draft before insert on question_revision_authoring
    for each row execute function require_draft_authoring_parent();
create trigger tr_question_translation_requires_draft before insert on question_revision_translation
    for each row execute function require_draft_authoring_parent();
create trigger tr_question_distractor_requires_draft before insert on question_revision_authored_distractor
    for each row execute function require_draft_authoring_parent();

create function validate_question_authoring_shape() returns trigger language plpgsql as $$
declare
    target_revision_id uuid;
    authored_type varchar(32);
    stored_type varchar(8);
    target_course_id uuid;
    target_language varchar(35);
    default_support_language varchar(35);
    translation_count integer;
    expected_translation_count integer;
    missing_translation_count integer;
    distractor_count integer;
    wrong_language_count integer;
begin
    target_revision_id := case when tg_op = 'DELETE' then old.question_revision_id else new.question_revision_id end;
    select a.record_type, q.question_type, q.course_id, c.target_language, c.default_support_language
      into authored_type, stored_type, target_course_id, target_language, default_support_language
      from question_revision_authoring a
      join question_revision q on q.id = a.question_revision_id
      join course c on c.id = q.course_id
     where a.question_revision_id = target_revision_id;
    if authored_type is null then
        return null;
    end if;
    if stored_type <> (case authored_type
        when 'WORD' then 'A'
        when 'MULTIPLE_CHOICE_CLOZE' then 'B'
        when 'TYPED_CLOZE' then 'C'
    end) then
        raise exception 'Authoring record type does not match question revision type' using errcode = '23514';
    end if;

    select count(*) into translation_count
      from question_revision_translation where question_revision_id = target_revision_id;
    select count(*) into expected_translation_count
      from course_support_language where course_id = target_course_id;
    select count(*) into missing_translation_count
      from course_support_language l
     where l.course_id = target_course_id
       and not exists (
           select 1 from question_revision_translation t
            where t.question_revision_id = target_revision_id
              and t.support_language = l.language_code
       );
    select count(*), count(*) filter (
        where language_code <> case
            when authored_type = 'WORD' then default_support_language
            else target_language
        end
    ) into distractor_count, wrong_language_count
      from question_revision_authored_distractor
     where question_revision_id = target_revision_id;

    if authored_type = 'WORD' then
        if translation_count <> expected_translation_count or missing_translation_count <> 0 then
            raise exception 'A WORD revision requires every course support-language translation'
                using errcode = '23514';
        end if;
        if not (distractor_count between 0 and 3) or wrong_language_count <> 0 then
            raise exception 'A WORD revision has invalid authored distractors' using errcode = '23514';
        end if;
    elsif authored_type = 'MULTIPLE_CHOICE_CLOZE' then
        if translation_count <> 0 or distractor_count <> 3 or wrong_language_count <> 0 then
            raise exception 'A multiple-choice cloze revision requires exactly three target-language distractors'
                using errcode = '23514';
        end if;
    elsif translation_count <> 0 or distractor_count <> 0 then
        raise exception 'A typed cloze revision cannot contain translations or distractors'
            using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_question_authoring_shape_from_authoring
    after insert on question_revision_authoring
    deferrable initially deferred
    for each row execute function validate_question_authoring_shape();
create constraint trigger tr_question_authoring_shape_from_translation
    after insert on question_revision_translation
    deferrable initially deferred
    for each row execute function validate_question_authoring_shape();
create constraint trigger tr_question_authoring_shape_from_distractor
    after insert on question_revision_authored_distractor
    deferrable initially deferred
    for each row execute function validate_question_authoring_shape();

alter table course_import drop constraint ck_course_import_status;
alter table course_import add constraint ck_course_import_status check (status in (
    'UPLOADING', 'QUEUED', 'PROCESSING', 'PREVIEW_READY',
    'VALIDATION_FAILED', 'MALWARE_REJECTED', 'PROCESSING_FAILED',
    'EXPIRED', 'APPROVED', 'COMMITTED'
));

alter table course_import_event drop constraint ck_course_import_event_from_status;
alter table course_import_event drop constraint ck_course_import_event_to_status;
alter table course_import_event add constraint ck_course_import_event_from_status check (
    from_status is null or from_status in (
        'UPLOADING', 'QUEUED', 'PROCESSING', 'PREVIEW_READY', 'VALIDATION_FAILED',
        'MALWARE_REJECTED', 'PROCESSING_FAILED', 'EXPIRED', 'APPROVED', 'COMMITTED'
    )
);
alter table course_import_event add constraint ck_course_import_event_to_status check (to_status in (
    'UPLOADING', 'QUEUED', 'PROCESSING', 'PREVIEW_READY', 'VALIDATION_FAILED',
    'MALWARE_REJECTED', 'PROCESSING_FAILED', 'EXPIRED', 'APPROVED', 'COMMITTED'
));

create or replace function enforce_course_import_transition() returns trigger language plpgsql as $$
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
        or (old.status = 'APPROVED' and new.status = 'COMMITTED')
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

create or replace function require_course_import_state_event() returns trigger language plpgsql as $$
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
            when old.status = 'APPROVED' and new.status = 'COMMITTED' then 'import-committed'
            else null
        end;
        expected_actor_user_id := case
            when old.status = 'UPLOADING' and new.status = 'QUEUED' then new.owner_user_id
            when old.status = 'PREVIEW_READY' and new.status = 'APPROVED' then new.owner_user_id
            when old.status = 'APPROVED' and new.status = 'COMMITTED' then new.owner_user_id
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

create function require_course_import_commit_prerequisite() returns trigger language plpgsql as $$
declare
    preview_record record;
    approval_record record;
    course_record record;
    change_set_record record;
    release_record record;
    origin_record record;
    outbox_record record;
    actual_count integer;
begin
    select * into preview_record from course_import_preview where import_id = new.import_id;
    select * into approval_record from course_import_approval where id = new.approval_id;
    select * into course_record from course where id = new.course_id;
    select * into change_set_record from content_change_set where id = new.content_change_set_id;
    select * into release_record from course_release where id = new.draft_release_id;
    select * into origin_record from course_origin where course_id = new.course_id;
    select * into outbox_record from outbox_event where id = new.outbox_event_id;

    if preview_record.import_id is null or not preview_record.is_valid
        or preview_record.content_schema_version is distinct from new.content_schema_version
        or preview_record.settings_payload is null
        or preview_record.approval_binding_sha256 is distinct from new.approval_binding_sha256
        or preview_record.allocation_sha256 is distinct from new.allocation_sha256
        or preview_record.preview_sha256 is distinct from new.preview_sha256
        or row(
            preview_record.row_count, preview_record.level_count, preview_record.unit_count,
            preview_record.topic_count, preview_record.test_count
        ) is distinct from row(
            new.row_count, new.level_count, new.unit_count, new.topic_count, new.test_count
        ) then
        raise exception 'Import commit does not match the immutable commit-ready preview' using errcode = '23514';
    end if;
    if approval_record.id is null
        or approval_record.import_id <> new.import_id
        or approval_record.owner_user_id <> new.owner_user_id
        or approval_record.approval_binding_sha256 <> new.approval_binding_sha256
        or approval_record.source_sha256 <> new.source_sha256
        or approval_record.allocation_sha256 <> new.allocation_sha256
        or approval_record.preview_sha256 <> new.preview_sha256 then
        raise exception 'Import commit does not match the immutable approval' using errcode = '23514';
    end if;
    if course_record.id is null
        or course_record.owner_user_id <> new.owner_user_id
        or course_record.publication_status <> 'DRAFT'
        or course_record.active_release_id is not null
        or course_record.name <> preview_record.settings_payload ->> 'courseName'
        or course_record.target_language <> preview_record.settings_payload ->> 'targetLanguageCode'
        or course_record.default_support_language <> preview_record.settings_payload ->> 'defaultSupportLanguageCode'
        or course_record.visibility <> preview_record.settings_payload ->> 'visibility'
        or course_record.access_type <> 'FREE' then
        raise exception 'Import commit course is not the approved unpublished draft' using errcode = '23514';
    end if;
    if change_set_record.id is null
        or change_set_record.course_id <> new.course_id
        or change_set_record.owner_user_id <> new.owner_user_id
        or change_set_record.base_release_id is not null
        or change_set_record.source_type <> 'EXCEL_IMPORT'
        or change_set_record.source_reference_id <> new.import_id
        or change_set_record.status <> 'COMMITTED'
        or change_set_record.committed_at <> new.committed_at
        or change_set_record.correlation_id <> new.correlation_id then
        raise exception 'Import commit change set is invalid' using errcode = '23514';
    end if;
    if release_record.id is null
        or release_record.course_id <> new.course_id
        or release_record.revision_number <> 1
        or release_record.status <> 'DRAFT'
        or release_record.created_at <> new.committed_at then
        raise exception 'Import commit release is not an immutable draft release' using errcode = '23514';
    end if;
    if origin_record.course_id is null
        or origin_record.owner_user_id <> new.owner_user_id
        or origin_record.origin_type <> 'EXCEL_IMPORT'
        or origin_record.origin_key <> new.import_id::text
        or origin_record.source_sha256 <> new.source_sha256 then
        raise exception 'Import commit course origin is invalid' using errcode = '23514';
    end if;
    if outbox_record.id is null
        or outbox_record.aggregate_type <> 'course'
        or outbox_record.aggregate_id <> new.course_id
        or outbox_record.event_type <> 'course.draft-created-from-import.v1'
        or outbox_record.schema_version <> 1
        or outbox_record.correlation_id <> new.correlation_id
        or outbox_record.occurred_at <> new.committed_at
        or outbox_record.payload <> jsonb_build_object(
            'eventId', new.outbox_event_id,
            'importId', new.import_id,
            'courseId', new.course_id,
            'contentChangeSetId', new.content_change_set_id,
            'draftReleaseId', new.draft_release_id,
            'rowCount', new.row_count,
            'testCount', new.test_count
        )
        or not exists (
            select 1 from outbox_delivery d
             where d.event_id = new.outbox_event_id
               and d.attempt_count = 0 and d.published_at is null
        ) then
        raise exception 'Import commit requires the exact transactional draft-created outbox fact'
            using errcode = '23514';
    end if;
    if not exists (
        select 1 from course_import_draft_settings s
         where s.course_id = new.course_id
           and s.content_change_set_id = new.content_change_set_id
           and s.course_name = preview_record.settings_payload ->> 'courseName'
           and s.target_language_code = preview_record.settings_payload ->> 'targetLanguageCode'
           and s.target_language_name = preview_record.settings_payload ->> 'targetLanguageName'
           and s.default_support_language_code = preview_record.settings_payload ->> 'defaultSupportLanguageCode'
           and s.default_test_mode = preview_record.settings_payload ->> 'defaultTestMode'
           and s.visibility = preview_record.settings_payload ->> 'visibility'
           and s.target_test_size = (preview_record.settings_payload ->> 'targetTestSize')::integer
           and s.minimum_last_automatic_test_size =
               (preview_record.settings_payload ->> 'minimumLastAutomaticTestSize')::integer
           and s.fill_fixed_tests = (preview_record.settings_payload ->> 'fillFixedTests')::boolean
           and s.completion_threshold_percent =
               (preview_record.settings_payload ->> 'completionThresholdPercent')::integer
           and s.pricing_source = preview_record.settings_payload ->> 'pricingSource'
           and s.maximum_typed_alternative_answers =
               (preview_record.settings_payload ->> 'maximumTypedAlternativeAnswers')::integer
           and s.offline_mode = preview_record.settings_payload ->> 'offlineMode'
           and to_jsonb(s.support_language_codes) = preview_record.settings_payload -> 'supportLanguageCodes'
    ) then
        raise exception 'Import commit settings do not match the approved settings payload' using errcode = '23514';
    end if;

    select count(*) into actual_count from content_level_revision
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.level_count then
        raise exception 'Import commit level count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from content_unit_revision
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.unit_count then
        raise exception 'Import commit unit count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from content_topic_revision
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.topic_count then
        raise exception 'Import commit topic count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from test_revision_authoring
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.test_count then
        raise exception 'Import commit test count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from question_revision_authoring
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.row_count then
        raise exception 'Import commit question count is incomplete' using errcode = '23514';
    end if;
    if exists (
        select 1 from test_revision_authoring a join test_revision r on r.id = a.test_revision_id
         where a.content_change_set_id = new.content_change_set_id and r.status <> 'DRAFT'
    ) or exists (
        select 1 from question_revision_authoring a join question_revision r on r.id = a.question_revision_id
         where a.content_change_set_id = new.content_change_set_id and r.status <> 'DRAFT'
    ) or exists (
        select 1 from question_revision_option o
        join question_revision_authoring a on a.question_revision_id = o.question_revision_id
         where a.content_change_set_id = new.content_change_set_id
    ) then
        raise exception 'Import commit cannot activate or compile runtime questions' using errcode = '23514';
    end if;
    if not exists (
        select 1 from content_change_set_event
         where content_change_set_id = new.content_change_set_id
           and event_type = 'CREATED' and actor_user_id = new.owner_user_id
           and occurred_at = new.committed_at and correlation_id = new.correlation_id
    ) or not exists (
        select 1 from content_change_set_event
         where content_change_set_id = new.content_change_set_id
           and event_type = 'COMMITTED' and actor_user_id = new.owner_user_id
           and occurred_at = new.committed_at and correlation_id = new.correlation_id
    ) then
        raise exception 'Import commit requires immutable change-set lifecycle events' using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_import_commit_prerequisite
    after insert on course_import_commit
    deferrable initially deferred
    for each row execute function require_course_import_commit_prerequisite();

create function require_committed_import_fact() returns trigger language plpgsql as $$
begin
    if new.status = 'COMMITTED' and not exists (
        select 1 from course_import_commit c
         where c.import_id = new.id
           and c.owner_user_id = new.owner_user_id
           and c.committed_at = new.updated_at
    ) then
        raise exception 'COMMITTED requires an immutable import commit fact' using errcode = '55000';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_import_committed_prerequisite
    after update on course_import
    deferrable initially deferred
    for each row execute function require_committed_import_fact();
