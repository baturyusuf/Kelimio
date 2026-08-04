-- Workbook rules v2 composes selected word groups into matching questions while
-- retaining an immutable link to every approved source row. Releases carry the
-- capabilities that a client must understand before it may consume the content.

alter table course_import drop constraint ck_course_import_rules_version;
alter table course_import add constraint ck_course_import_rules_version
    check (rules_version in ('xlsx-v1', 'xlsx-v2'));

alter table course_import_approval drop constraint ck_course_import_approval_versions;
alter table course_import_approval add constraint ck_course_import_approval_versions check (
    length(btrim(scanner_engine_version)) > 0
    and length(btrim(scanner_signature_version)) > 0
    and rules_version in ('xlsx-v1', 'xlsx-v2')
    and length(btrim(parser_version)) > 0
    and length(btrim(correlation_id)) > 0
);

alter table course_import_preview drop constraint ck_course_import_preview_rules;
alter table course_import_preview add constraint ck_course_import_preview_rules
    check (rules_version in ('xlsx-v1', 'xlsx-v2'));

alter table course_import_preview drop constraint ck_course_import_preview_content_payload;
alter table course_import_preview
    add column question_count integer,
    add column matching_question_count integer,
    add column required_client_capabilities varchar(64)[];

update course_import_preview
   set question_count = row_count,
       matching_question_count = 0,
       required_client_capabilities = '{}'::varchar(64)[]
 where is_valid and content_schema_version = 'import-content-v1';

alter table course_import_preview
    add constraint ck_course_import_preview_content_payload check (
        (content_schema_version is null and settings_payload is null
            and question_count is null and matching_question_count is null
            and required_client_capabilities is null)
        or (
            content_schema_version in ('import-content-v1', 'import-content-v2')
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
            and question_count between 1 and row_count
            and matching_question_count between 0 and question_count
            and required_client_capabilities is not null
            and cardinality(required_client_capabilities) between 0 and 1
            and required_client_capabilities <@ array['question.matching.v1']::varchar(64)[]
            and (
                (matching_question_count = 0 and cardinality(required_client_capabilities) = 0)
                or (
                    matching_question_count > 0
                    and required_client_capabilities = array['question.matching.v1']::varchar(64)[]
                )
            )
            and (
                content_schema_version <> 'import-content-v1'
                or (
                    question_count = row_count
                    and matching_question_count = 0
                    and cardinality(required_client_capabilities) = 0
                )
            )
        )
    );

alter table test_revision_authoring drop constraint ck_test_authoring_mode;
alter table test_revision_authoring add constraint ck_test_authoring_mode check (
    resolved_mode in ('MIXED', 'WORD', 'MATCHING', 'MULTIPLE_CHOICE_CLOZE', 'TYPED_CLOZE')
);

alter table question_revision_authoring drop constraint ck_question_authoring_type;
alter table question_revision_authoring add constraint ck_question_authoring_type check (
    record_type in ('WORD', 'MULTIPLE_CHOICE_CLOZE', 'TYPED_CLOZE', 'MATCHING_GROUP')
);

create table question_revision_import_composition (
    question_revision_id uuid primary key,
    course_id uuid not null,
    content_change_set_id uuid not null,
    import_id uuid not null,
    composition_kind varchar(32) not null,
    source_row_count smallint not null,
    first_source_ordinal integer not null,
    created_at timestamptz not null,
    constraint uq_import_composition_identity unique (question_revision_id, course_id, import_id),
    constraint uq_import_composition_question_ordinal unique (import_id, first_source_ordinal),
    constraint fk_import_composition_revision foreign key (question_revision_id, course_id)
        references question_revision(id, course_id),
    constraint fk_import_composition_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint fk_import_composition_import foreign key (import_id) references course_import(id),
    constraint ck_import_composition_kind check (composition_kind in ('ROW', 'MATCHING_GROUP')),
    constraint ck_import_composition_count check (
        (composition_kind = 'ROW' and source_row_count = 1)
        or (composition_kind = 'MATCHING_GROUP' and source_row_count between 2 and 6)
    ),
    constraint ck_import_composition_first_ordinal check (first_source_ordinal between 1 and 10000)
);

create table question_revision_import_source (
    question_revision_id uuid not null,
    course_id uuid not null,
    import_id uuid not null,
    source_ordinal integer not null,
    position smallint not null,
    primary key (question_revision_id, source_ordinal),
    constraint uq_import_source_once unique (import_id, source_ordinal),
    constraint uq_import_source_position unique (question_revision_id, position),
    constraint fk_import_source_composition foreign key (question_revision_id, course_id, import_id)
        references question_revision_import_composition(question_revision_id, course_id, import_id),
    constraint fk_import_source_preview_row foreign key (import_id, source_ordinal)
        references course_import_preview_row(import_id, ordinal),
    constraint ck_import_source_ordinal check (source_ordinal between 1 and 10000),
    constraint ck_import_source_position check (position between 1 and 6)
);

insert into question_revision_import_composition(
    question_revision_id, course_id, content_change_set_id, import_id,
    composition_kind, source_row_count, first_source_ordinal, created_at
)
select a.question_revision_id, a.course_id, a.content_change_set_id,
       s.source_reference_id, 'ROW', 1, a.ordinal, a.created_at
  from question_revision_authoring a
  join content_change_set s on s.id = a.content_change_set_id
 where s.source_type = 'EXCEL_IMPORT';

insert into question_revision_import_source(
    question_revision_id, course_id, import_id, source_ordinal, position
)
select question_revision_id, course_id, import_id, first_source_ordinal, 1
  from question_revision_import_composition;

create table course_release_required_capability (
    course_release_id uuid not null,
    course_id uuid not null,
    capability varchar(64) not null,
    created_at timestamptz not null,
    primary key (course_release_id, capability),
    constraint fk_release_capability_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint ck_release_capability_known check (capability = 'question.matching.v1')
);

insert into course_release_required_capability(course_release_id, course_id, capability, created_at)
select distinct release.id, release.course_id, 'question.matching.v1', release.created_at
  from course_release release
  join course_release_test_revision release_test on release_test.course_release_id = release.id
  join test_revision_question test_question on test_question.test_revision_id = release_test.test_revision_id
  join question_revision revision on revision.id = test_question.question_revision_id
 where revision.question_type = 'D';

create trigger tr_import_composition_append_only
    before update or delete on question_revision_import_composition
    for each row execute function reject_fact_mutation();
create trigger tr_import_source_append_only
    before update or delete on question_revision_import_source
    for each row execute function reject_fact_mutation();
create trigger tr_release_capability_append_only
    before update or delete on course_release_required_capability
    for each row execute function reject_fact_mutation();

create function require_import_composition_parent() returns trigger language plpgsql as $$
declare
    revision_status varchar(16);
    expected_import_id uuid;
begin
    select status into revision_status from question_revision where id = new.question_revision_id;
    if revision_status is distinct from 'DRAFT' then
        raise exception 'Import composition can be added only to a DRAFT question revision'
            using errcode = '55000';
    end if;
    select source_reference_id into expected_import_id
      from content_change_set
     where id = new.content_change_set_id and course_id = new.course_id
       and source_type = 'EXCEL_IMPORT';
    if expected_import_id is distinct from new.import_id then
        raise exception 'Import composition must match its Excel import change set'
            using errcode = '23514';
    end if;
    if exists (select 1 from course_import_commit where import_id = new.import_id) then
        raise exception 'Import composition cannot change after the import commit'
            using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_import_composition_requires_draft
    before insert on question_revision_import_composition
    for each row execute function require_import_composition_parent();

create function require_import_source_parent() returns trigger language plpgsql as $$
declare
    revision_status varchar(16);
begin
    select status into revision_status from question_revision where id = new.question_revision_id;
    if revision_status is distinct from 'DRAFT' then
        raise exception 'Import source lineage can be added only to a DRAFT question revision'
            using errcode = '55000';
    end if;
    if exists (select 1 from course_import_commit where import_id = new.import_id) then
        raise exception 'Import source lineage cannot change after the import commit'
            using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_import_source_requires_draft
    before insert on question_revision_import_source
    for each row execute function require_import_source_parent();

create function require_release_capability_parent() returns trigger language plpgsql as $$
declare
    release_status varchar(16);
begin
    select status into release_status from course_release where id = new.course_release_id;
    if release_status is distinct from 'DRAFT' then
        raise exception 'Release capabilities can be added only to a DRAFT release'
            using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_release_capability_requires_draft
    before insert on course_release_required_capability
    for each row execute function require_release_capability_parent();

create function derive_matching_release_capability() returns trigger language plpgsql as $$
begin
    if tg_table_name = 'course_release_test_revision' then
        insert into course_release_required_capability(course_release_id, course_id, capability, created_at)
        select new.course_release_id, new.course_id, 'question.matching.v1', release.created_at
          from course_release release
         where release.id = new.course_release_id
           and exists (
               select 1
                 from test_revision_question test_question
                 join question_revision revision on revision.id = test_question.question_revision_id
                where test_question.test_revision_id = new.test_revision_id
                  and revision.question_type = 'D'
           )
        on conflict do nothing;
    else
        insert into course_release_required_capability(course_release_id, course_id, capability, created_at)
        select release_test.course_release_id, release_test.course_id,
               'question.matching.v1', release.created_at
          from course_release_test_revision release_test
          join course_release release on release.id = release_test.course_release_id
          join question_revision revision on revision.id = new.question_revision_id
         where release_test.test_revision_id = new.test_revision_id
           and revision.question_type = 'D'
        on conflict do nothing;
    end if;
    return null;
end;
$$;

create trigger tr_release_test_derives_matching_capability
    after insert on course_release_test_revision
    for each row execute function derive_matching_release_capability();
create trigger tr_test_question_derives_matching_capability
    after insert on test_revision_question
    for each row execute function derive_matching_release_capability();

create function validate_release_capability_manifest() returns trigger language plpgsql as $$
declare
    target_release_id uuid;
    has_matching boolean;
    has_matching_capability boolean;
begin
    target_release_id := case
        when tg_table_name = 'course_release_required_capability' then new.course_release_id
        else new.course_release_id
    end;
    select exists (
        select 1
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
          join question_revision revision on revision.id = test_question.question_revision_id
         where release_test.course_release_id = target_release_id
           and revision.question_type = 'D'
    ) into has_matching;
    select exists (
        select 1 from course_release_required_capability
         where course_release_id = target_release_id and capability = 'question.matching.v1'
    ) into has_matching_capability;
    if has_matching is distinct from has_matching_capability then
        raise exception 'Release capability manifest does not match release question types'
            using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_release_capability_manifest_from_capability
    after insert on course_release_required_capability
    deferrable initially deferred
    for each row execute function validate_release_capability_manifest();
create constraint trigger tr_release_capability_manifest_from_release_test
    after insert on course_release_test_revision
    deferrable initially deferred
    for each row execute function validate_release_capability_manifest();

create or replace function validate_question_authoring_shape() returns trigger language plpgsql as $$
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
        when 'MATCHING_GROUP' then 'D'
    end) then
        raise exception 'Authoring record type does not match question revision type' using errcode = '23514';
    end if;

    select count(*) into translation_count
      from question_revision_translation where question_revision_id = target_revision_id;
    select count(*) into expected_translation_count
      from course_support_language where course_id = target_course_id;
    select count(*) into missing_translation_count
      from course_support_language language
     where language.course_id = target_course_id
       and not exists (
           select 1 from question_revision_translation translation
            where translation.question_revision_id = target_revision_id
              and translation.support_language = language.language_code
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
    elsif authored_type = 'TYPED_CLOZE' then
        if translation_count <> 0 or distractor_count <> 0 then
            raise exception 'A typed cloze revision cannot contain translations or distractors'
                using errcode = '23514';
        end if;
    else
        if translation_count <> 0 or distractor_count <> 0 then
            raise exception 'A matching revision cannot contain row translations or distractors'
                using errcode = '23514';
        end if;
        perform assert_matching_revision_complete(target_revision_id, true);
    end if;
    return null;
end;
$$;

alter table course_import_commit drop constraint ck_course_import_commit_schema;
alter table course_import_commit drop constraint ck_course_import_commit_counts;
alter table course_import_commit
    add column question_count integer,
    add column matching_question_count integer,
    add column required_client_capabilities varchar(64)[];

update course_import_commit
   set question_count = row_count,
       matching_question_count = 0,
       required_client_capabilities = '{}'::varchar(64)[];

alter table course_import_commit
    alter column question_count set not null,
    alter column matching_question_count set not null,
    alter column required_client_capabilities set not null,
    add constraint ck_course_import_commit_schema check (
        content_schema_version in ('import-content-v1', 'import-content-v2')
    ),
    add constraint ck_course_import_commit_counts check (
        row_count between 1 and 10000
        and question_count between 1 and row_count
        and matching_question_count between 0 and question_count
        and level_count between 1 and 64
        and unit_count between 1 and 10000
        and topic_count between 1 and 10000
        and test_count between 1 and 10000
        and required_client_capabilities <@ array['question.matching.v1']::varchar(64)[]
        and (
            (matching_question_count = 0 and cardinality(required_client_capabilities) = 0)
            or (
                matching_question_count > 0
                and required_client_capabilities = array['question.matching.v1']::varchar(64)[]
            )
        )
        and (
            content_schema_version <> 'import-content-v1'
            or (
                question_count = row_count
                and matching_question_count = 0
                and cardinality(required_client_capabilities) = 0
            )
        )
    );

create or replace function require_course_import_commit_prerequisite() returns trigger language plpgsql as $$
declare
    preview_record record;
    approval_record record;
    course_record record;
    change_set_record record;
    release_record record;
    origin_record record;
    outbox_record record;
    actual_count integer;
    actual_capabilities varchar(64)[];
    expected_event_type varchar(80);
    expected_schema_version integer;
    expected_payload jsonb;
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
            preview_record.row_count, preview_record.question_count,
            preview_record.matching_question_count, preview_record.required_client_capabilities,
            preview_record.level_count, preview_record.unit_count,
            preview_record.topic_count, preview_record.test_count
        ) is distinct from row(
            new.row_count, new.question_count, new.matching_question_count,
            new.required_client_capabilities, new.level_count, new.unit_count,
            new.topic_count, new.test_count
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

    if new.content_schema_version = 'import-content-v2' then
        expected_event_type := 'course.draft-created-from-import.v2';
        expected_schema_version := 2;
        expected_payload := jsonb_build_object(
            'eventId', new.outbox_event_id,
            'importId', new.import_id,
            'courseId', new.course_id,
            'contentChangeSetId', new.content_change_set_id,
            'draftReleaseId', new.draft_release_id,
            'sourceRowCount', new.row_count,
            'questionCount', new.question_count,
            'matchingQuestionCount', new.matching_question_count,
            'testCount', new.test_count,
            'requiredClientCapabilities', to_jsonb(new.required_client_capabilities)
        );
    else
        expected_event_type := 'course.draft-created-from-import.v1';
        expected_schema_version := 1;
        expected_payload := jsonb_build_object(
            'eventId', new.outbox_event_id,
            'importId', new.import_id,
            'courseId', new.course_id,
            'contentChangeSetId', new.content_change_set_id,
            'draftReleaseId', new.draft_release_id,
            'rowCount', new.row_count,
            'testCount', new.test_count
        );
    end if;
    if outbox_record.id is null
        or outbox_record.aggregate_type <> 'course'
        or outbox_record.aggregate_id <> new.course_id
        or outbox_record.event_type <> expected_event_type
        or outbox_record.schema_version <> expected_schema_version
        or outbox_record.correlation_id <> new.correlation_id
        or outbox_record.occurred_at <> new.committed_at
        or outbox_record.payload <> expected_payload
        or not exists (
            select 1 from outbox_delivery delivery
             where delivery.event_id = new.outbox_event_id
               and delivery.attempt_count = 0 and delivery.published_at is null
        ) then
        raise exception 'Import commit requires the exact transactional draft-created outbox fact'
            using errcode = '23514';
    end if;
    if not exists (
        select 1 from course_import_draft_settings settings
         where settings.course_id = new.course_id
           and settings.content_change_set_id = new.content_change_set_id
           and settings.course_name = preview_record.settings_payload ->> 'courseName'
           and settings.target_language_code = preview_record.settings_payload ->> 'targetLanguageCode'
           and settings.target_language_name = preview_record.settings_payload ->> 'targetLanguageName'
           and settings.default_support_language_code = preview_record.settings_payload ->> 'defaultSupportLanguageCode'
           and settings.default_test_mode = preview_record.settings_payload ->> 'defaultTestMode'
           and settings.visibility = preview_record.settings_payload ->> 'visibility'
           and settings.target_test_size = (preview_record.settings_payload ->> 'targetTestSize')::integer
           and settings.minimum_last_automatic_test_size =
               (preview_record.settings_payload ->> 'minimumLastAutomaticTestSize')::integer
           and settings.fill_fixed_tests = (preview_record.settings_payload ->> 'fillFixedTests')::boolean
           and settings.completion_threshold_percent =
               (preview_record.settings_payload ->> 'completionThresholdPercent')::integer
           and settings.pricing_source = preview_record.settings_payload ->> 'pricingSource'
           and settings.maximum_typed_alternative_answers =
               (preview_record.settings_payload ->> 'maximumTypedAlternativeAnswers')::integer
           and settings.offline_mode = preview_record.settings_payload ->> 'offlineMode'
           and to_jsonb(settings.support_language_codes) =
               preview_record.settings_payload -> 'supportLanguageCodes'
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
    if actual_count <> new.question_count then
        raise exception 'Import commit question count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from question_revision_authoring
     where content_change_set_id = new.content_change_set_id and record_type = 'MATCHING_GROUP';
    if actual_count <> new.matching_question_count then
        raise exception 'Import commit matching question count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from question_revision_import_composition
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.question_count then
        raise exception 'Import commit composition count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from question_revision_import_source
     where import_id = new.import_id;
    if actual_count <> new.row_count then
        raise exception 'Import commit source-row lineage is incomplete' using errcode = '23514';
    end if;
    if exists (
        select 1 from question_revision_import_composition composition
         where composition.content_change_set_id = new.content_change_set_id
           and composition.source_row_count <> (
               select count(*) from question_revision_import_source source
                where source.question_revision_id = composition.question_revision_id
           )
    ) then
        raise exception 'Import commit composition source counts are inconsistent' using errcode = '23514';
    end if;
    select coalesce(array_agg(capability order by capability), '{}'::varchar(64)[])
      into actual_capabilities
      from course_release_required_capability
     where course_release_id = new.draft_release_id;
    if actual_capabilities is distinct from new.required_client_capabilities then
        raise exception 'Import commit release capabilities are incomplete' using errcode = '23514';
    end if;
    if exists (
        select 1 from test_revision_authoring authoring
        join test_revision revision on revision.id = authoring.test_revision_id
         where authoring.content_change_set_id = new.content_change_set_id and revision.status <> 'DRAFT'
    ) or exists (
        select 1 from question_revision_authoring authoring
        join question_revision revision on revision.id = authoring.question_revision_id
         where authoring.content_change_set_id = new.content_change_set_id and revision.status <> 'DRAFT'
    ) or exists (
        select 1 from question_revision_option option
        join question_revision_authoring authoring
          on authoring.question_revision_id = option.question_revision_id
         where authoring.content_change_set_id = new.content_change_set_id
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
