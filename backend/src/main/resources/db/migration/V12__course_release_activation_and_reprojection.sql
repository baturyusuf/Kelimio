create table course_release_source_change_set (
    course_release_id uuid primary key,
    course_id uuid not null,
    content_change_set_id uuid not null unique,
    created_at timestamptz not null,
    constraint fk_release_source_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_release_source_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id)
);

insert into course_release_source_change_set(
    course_release_id, course_id, content_change_set_id, created_at
)
select draft_release_id, course_id, content_change_set_id, committed_at
  from course_import_commit;

create trigger tr_release_source_append_only
    before update or delete on course_release_source_change_set
    for each row execute function reject_fact_mutation();

create function require_release_source_parent() returns trigger language plpgsql as $$
declare
    release_status varchar(16);
    change_set_status varchar(24);
begin
    select status into release_status
      from course_release
     where id = new.course_release_id and course_id = new.course_id;
    select status into change_set_status
      from content_change_set
     where id = new.content_change_set_id and course_id = new.course_id;
    if release_status is distinct from 'DRAFT' or change_set_status is distinct from 'COMMITTED' then
        raise exception 'A release source requires one DRAFT release and COMMITTED change set'
            using errcode = '23514';
    end if;
    if exists (
        select 1 from course_release_activation where target_release_id = new.course_release_id
    ) then
        raise exception 'An activated release cannot acquire new source provenance'
            using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_release_source_requires_draft
    before insert on course_release_source_change_set
    for each row execute function require_release_source_parent();

create table question_revision_option_translation (
    option_id uuid not null,
    question_revision_id uuid not null,
    course_id uuid not null,
    support_language varchar(35) not null,
    option_text varchar(500) not null,
    primary key (option_id, support_language),
    constraint fk_option_translation_option foreign key (question_revision_id, option_id)
        references question_revision_option(question_revision_id, id),
    constraint fk_option_translation_revision foreign key (question_revision_id, course_id)
        references question_revision(id, course_id),
    constraint fk_option_translation_support_language foreign key (course_id, support_language)
        references course_support_language(course_id, language_code),
    constraint ck_option_translation_text check (length(btrim(option_text)) > 0)
);

create index ix_option_translation_revision_language
    on question_revision_option_translation(question_revision_id, support_language, option_id);

create trigger tr_option_translation_append_only
    before update or delete on question_revision_option_translation
    for each row execute function reject_fact_mutation();

create function require_draft_word_option_translation() returns trigger language plpgsql as $$
declare
    parent_status varchar(16);
    parent_type varchar(8);
begin
    select status, question_type into parent_status, parent_type
      from question_revision
     where id = new.question_revision_id and course_id = new.course_id;
    if parent_status is distinct from 'DRAFT' or parent_type is distinct from 'A' then
        raise exception 'Localized options may be added only to DRAFT Type-A revisions'
            using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_option_translation_requires_draft_word
    before insert on question_revision_option_translation
    for each row execute function require_draft_word_option_translation();

-- V11 deliberately rejected runtime options while import ended at an
-- unpublished draft. V12 makes a committed draft publication-ready, so the
-- same prerequisite validator is retained with exact A/B option checks.
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
    ) then
        raise exception 'Import commit cannot activate runtime revisions' using errcode = '23514';
    end if;
    if exists (
        select 1
          from question_revision_authoring authoring
          join question_revision revision on revision.id = authoring.question_revision_id
         where authoring.content_change_set_id = new.content_change_set_id
           and revision.question_type in ('A', 'B')
           and (
                (select count(*) from question_revision_option option_row
                  where option_row.question_revision_id = revision.id) <> 4
                or (select count(*) from question_revision_option option_row
                     where option_row.question_revision_id = revision.id and option_row.is_correct) <> 1
           )
    ) or exists (
        select 1
          from question_revision_authoring authoring
          join question_revision revision on revision.id = authoring.question_revision_id
          join question_revision_option option_row on option_row.question_revision_id = revision.id
         where authoring.content_change_set_id = new.content_change_set_id
           and revision.question_type in ('C', 'D')
    ) or exists (
        select 1
          from question_revision_authoring authoring
          join question_revision revision on revision.id = authoring.question_revision_id
         where authoring.content_change_set_id = new.content_change_set_id
           and revision.question_type = 'A'
           and (
                (select count(*) from question_revision_option_translation translation
                  where translation.question_revision_id = revision.id) <>
                4 * (select count(*) from course_support_language support
                      where support.course_id = revision.course_id)
                or exists (
                    select 1
                      from question_revision_option option_row
                      join course course_row on course_row.id = revision.course_id
                      left join question_revision_option_translation translation
                        on translation.option_id = option_row.id
                       and translation.question_revision_id = option_row.question_revision_id
                       and translation.support_language = course_row.default_support_language
                     where option_row.question_revision_id = revision.id
                       and translation.option_text is distinct from option_row.option_text
                )
           )
    ) or exists (
        select 1
          from question_revision_authoring authoring
          join question_revision revision on revision.id = authoring.question_revision_id
          join question_revision_option_translation translation
            on translation.question_revision_id = revision.id
         where authoring.content_change_set_id = new.content_change_set_id
           and revision.question_type <> 'A'
    ) then
        raise exception 'Import commit runtime option materialization is incomplete' using errcode = '23514';
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

create function contiguous_positive_positions(values_array integer[]) returns boolean
immutable strict language sql as $$
    select cardinality(values_array) > 0
       and values_array = array(select generate_series(1, cardinality(values_array)));
$$;

create function validate_course_release_activation_shape() returns trigger language plpgsql as $$
declare
    flat_test_count integer;
    hierarchy_test_count integer;
    level_count integer;
begin
    if new.status <> 'ACTIVE' then
        return null;
    end if;

    select count(*) into flat_test_count
      from course_release_test_revision
     where course_release_id = new.id;
    if flat_test_count < 1 then
        raise exception 'An ACTIVE release requires at least one test revision' using errcode = '23514';
    end if;
    if not contiguous_positive_positions(
        (select array_agg(position order by position)
           from course_release_test_revision where course_release_id = new.id)
    ) then
        raise exception 'Release test positions must be contiguous' using errcode = '23514';
    end if;
    if exists (
        select 1
          from course_release_test_revision release_test
          join test_revision revision on revision.id = release_test.test_revision_id
         where release_test.course_release_id = new.id
           and (revision.course_id <> new.course_id or revision.status <> 'ACTIVE')
    ) then
        raise exception 'An ACTIVE release contains a non-active test revision' using errcode = '23514';
    end if;
    if exists (
        select 1
          from course_release_test_revision release_test
          left join test_revision_question question
            on question.test_revision_id = release_test.test_revision_id
         where release_test.course_release_id = new.id
         group by release_test.test_revision_id
        having count(question.question_revision_id) < 1
    ) then
        raise exception 'Every release test requires at least one question' using errcode = '23514';
    end if;
    if exists (
        select 1
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
          join question_revision revision on revision.id = test_question.question_revision_id
         where release_test.course_release_id = new.id
           and (revision.course_id <> new.course_id or revision.status <> 'ACTIVE')
    ) then
        raise exception 'An ACTIVE release contains a non-active question revision' using errcode = '23514';
    end if;
    if exists (
        select 1
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
         where release_test.course_release_id = new.id
         group by release_test.test_revision_id
        having not contiguous_positive_positions(array_agg(test_question.position order by test_question.position))
    ) then
        raise exception 'Release question positions must be contiguous per test' using errcode = '23514';
    end if;
    if exists (
        select 1
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
          join question_revision revision on revision.id = test_question.question_revision_id
         where release_test.course_release_id = new.id
         group by revision.question_id
        having count(distinct revision.id) <> 1
    ) then
        raise exception 'A release cannot contain conflicting revisions of one stable question'
            using errcode = '23514';
    end if;

    if exists (
        select 1 from course_release_source_change_set where course_release_id = new.id
    ) then
        select count(*) into level_count
          from course_release_level_revision
         where course_release_id = new.id;
        select count(*) into hierarchy_test_count
          from course_release_test_hierarchy
         where course_release_id = new.id;
        if level_count < 1 or hierarchy_test_count <> flat_test_count then
            raise exception 'A sourced release requires one complete content hierarchy'
                using errcode = '23514';
        end if;
        if exists (
            select 1
              from (
                    select distinct revision.id, revision.course_id
                      from course_release_test_revision release_test
                      join test_revision_question test_question
                        on test_question.test_revision_id = release_test.test_revision_id
                      join question_revision revision on revision.id = test_question.question_revision_id
                     where release_test.course_release_id = new.id
                       and revision.question_type = 'A'
              ) word_revision
             where (
                    select count(*)
                      from question_revision_option_translation translation
                     where translation.question_revision_id = word_revision.id
             ) <> 4 * (
                    select count(*) from course_support_language support
                     where support.course_id = word_revision.course_id
             )
                or exists (
                    select 1
                      from question_revision_option option_row
                      join course course_row on course_row.id = word_revision.course_id
                      left join question_revision_option_translation translation
                        on translation.option_id = option_row.id
                       and translation.question_revision_id = option_row.question_revision_id
                       and translation.support_language = course_row.default_support_language
                     where option_row.question_revision_id = word_revision.id
                       and translation.option_text is distinct from option_row.option_text
                )
        ) then
            raise exception 'A sourced active Type-A revision requires exact options in every support language'
                using errcode = '23514';
        end if;
        if not contiguous_positive_positions(
            (select array_agg(position order by position)
               from course_release_level_revision where course_release_id = new.id)
        ) then
            raise exception 'Release level positions must be contiguous' using errcode = '23514';
        end if;
        if exists (
            select 1
              from course_release_unit_revision
             where course_release_id = new.id
             group by parent_level_revision_id
            having not contiguous_positive_positions(array_agg(position order by position))
        ) or exists (
            select 1
              from course_release_topic_revision
             where course_release_id = new.id
             group by parent_unit_revision_id
            having not contiguous_positive_positions(array_agg(position order by position))
        ) or exists (
            select 1
              from course_release_test_hierarchy
             where course_release_id = new.id
             group by parent_topic_revision_id
            having not contiguous_positive_positions(array_agg(position order by position))
        ) then
            raise exception 'Release hierarchy positions must be contiguous within every parent'
                using errcode = '23514';
        end if;
    end if;
    return null;
end;
$$;

create constraint trigger tr_release_activation_shape_valid
    after update of status on course_release
    deferrable initially deferred
    for each row execute function validate_course_release_activation_shape();

create table course_release_activation (
    id uuid primary key,
    course_id uuid not null,
    target_release_id uuid not null,
    previous_release_id uuid,
    source_change_set_id uuid not null,
    actor_user_id uuid not null references app_user(id),
    operation_kind varchar(32) not null,
    expected_active_release_id uuid,
    impact_binding_sha256 char(64) not null,
    release_revision integer not null,
    question_count integer not null,
    required_client_capabilities varchar(64)[] not null,
    outbox_event_id uuid not null unique references outbox_event(id),
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint fk_activation_target_release foreign key (target_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_activation_previous_release foreign key (previous_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_activation_source_change_set foreign key (source_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint ck_activation_operation check (
        operation_kind in ('INITIAL_PUBLICATION', 'PUBLICATION', 'ROLLBACK')
    ),
    constraint ck_activation_release_relationship check (
        (
            operation_kind = 'INITIAL_PUBLICATION'
            and previous_release_id is null
            and expected_active_release_id is null
        ) or (
            operation_kind in ('PUBLICATION', 'ROLLBACK')
            and previous_release_id is not null
            and expected_active_release_id = previous_release_id
            and target_release_id <> previous_release_id
        )
    ),
    constraint ck_activation_digest check (impact_binding_sha256 ~ '^[0-9a-f]{64}$'),
    constraint ck_activation_counts check (release_revision > 0 and question_count between 1 and 10000),
    constraint ck_activation_capability_count check (cardinality(required_client_capabilities) <= 16),
    constraint ck_activation_correlation check (length(btrim(correlation_id)) > 0)
);

create unique index uq_release_initial_publication
    on course_release_activation(course_id)
    where operation_kind = 'INITIAL_PUBLICATION';
create unique index uq_release_publication_target
    on course_release_activation(target_release_id)
    where operation_kind in ('INITIAL_PUBLICATION', 'PUBLICATION');
create index ix_release_activation_course_time
    on course_release_activation(course_id, occurred_at, id);

create trigger tr_release_activation_append_only
    before update or delete on course_release_activation
    for each row execute function reject_fact_mutation();

create table course_release_reprojection_job (
    activation_id uuid primary key references course_release_activation(id),
    course_id uuid not null,
    target_release_id uuid not null,
    outbox_event_id uuid not null unique references outbox_event(id),
    enrollment_cutoff_at timestamptz not null,
    status varchar(16) not null,
    cursor_enrolled_at timestamptz,
    cursor_enrollment_id uuid,
    processed_count integer not null,
    attempt_count integer not null,
    last_error_type varchar(500),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    completed_at timestamptz,
    constraint fk_reprojection_target_release foreign key (target_release_id, course_id)
        references course_release(id, course_id),
    constraint ck_reprojection_status check (status in ('PENDING', 'FAILED', 'COMPLETED', 'DEAD')),
    constraint ck_reprojection_cursor check (
        (cursor_enrolled_at is null and cursor_enrollment_id is null)
        or (cursor_enrolled_at is not null and cursor_enrollment_id is not null)
    ),
    constraint ck_reprojection_counts check (processed_count >= 0 and attempt_count >= 0),
    constraint ck_reprojection_error check (
        (status in ('FAILED', 'DEAD') and last_error_type is not null)
        or (status not in ('FAILED', 'DEAD') and last_error_type is null)
    ),
    constraint ck_reprojection_completion check (
        (status = 'COMPLETED' and completed_at is not null)
        or (status <> 'COMPLETED' and completed_at is null)
    ),
    constraint ck_reprojection_time check (
        updated_at >= created_at and (completed_at is null or completed_at >= created_at)
    )
);

create index ix_release_reprojection_retry
    on course_release_reprojection_job(status, attempt_count, created_at, activation_id);

alter table learner_course_progress_projection
    add column course_release_id uuid;

update learner_course_progress_projection projection
   set course_release_id = course.active_release_id
  from course
 where course.id = projection.course_id;

alter table learner_course_progress_projection
    add constraint fk_progress_represented_release foreign key (course_release_id, course_id)
        references course_release(id, course_id);

create index ix_progress_represented_release
    on learner_course_progress_projection(course_id, course_release_id, user_id);

create function validate_course_release_activation_fact() returns trigger language plpgsql as $$
declare
    course_record record;
    target_record record;
    previous_record record;
    source_record record;
    outbox_record record;
    job_record record;
    actual_capabilities varchar(64)[];
    actual_question_count integer;
    expected_event_type varchar(120);
begin
    select * into course_record from course where id = new.course_id;
    select * into target_record from course_release where id = new.target_release_id;
    if new.previous_release_id is not null then
        select * into previous_record from course_release where id = new.previous_release_id;
    end if;
    select * into source_record
      from course_release_source_change_set
     where course_release_id = new.target_release_id;
    select * into outbox_record from outbox_event where id = new.outbox_event_id;
    select * into job_record from course_release_reprojection_job where activation_id = new.id;
    select coalesce(array_agg(capability order by capability), '{}'::varchar(64)[])
      into actual_capabilities
      from course_release_required_capability
     where course_release_id = new.target_release_id;
    select count(distinct revision.question_id) into actual_question_count
      from course_release_test_revision release_test
      join test_revision_question test_question
        on test_question.test_revision_id = release_test.test_revision_id
      join question_revision revision on revision.id = test_question.question_revision_id
     where release_test.course_release_id = new.target_release_id;
    expected_event_type := case
        when new.operation_kind = 'ROLLBACK' then 'content.release-rollback-activated.v1'
        else 'content.release-published.v1'
    end;

    if course_record.id is null
        or course_record.owner_user_id <> new.actor_user_id
        or course_record.active_release_id <> new.target_release_id
        or course_record.publication_status not in ('PUBLISHED', 'HIDDEN') then
        raise exception 'Release activation does not match final course state' using errcode = '23514';
    end if;
    if target_record.id is null
        or target_record.course_id <> new.course_id
        or target_record.status <> 'ACTIVE'
        or target_record.revision_number <> new.release_revision then
        raise exception 'Release activation target is invalid' using errcode = '23514';
    end if;
    if new.previous_release_id is not null then
        if previous_record.id is null
            or previous_record.course_id <> new.course_id
            or previous_record.status <> 'RETIRED' then
            raise exception 'Release activation previous release is not retired' using errcode = '23514';
        end if;
    end if;
    if source_record.course_release_id is null
        or source_record.course_id <> new.course_id
        or source_record.content_change_set_id <> new.source_change_set_id
        or not exists (
            select 1 from content_change_set change_set
             where change_set.id = new.source_change_set_id
               and change_set.course_id = new.course_id
               and change_set.status = 'COMMITTED'
        ) then
        raise exception 'Release activation source change set is invalid' using errcode = '23514';
    end if;
    if actual_question_count <> new.question_count
        or actual_capabilities is distinct from new.required_client_capabilities then
        raise exception 'Release activation manifest summary is inexact' using errcode = '23514';
    end if;
    if outbox_record.id is null
        or outbox_record.aggregate_type <> 'course'
        or outbox_record.aggregate_id <> new.course_id
        or outbox_record.event_type <> expected_event_type
        or outbox_record.schema_version <> 1
        or outbox_record.correlation_id <> new.correlation_id
        or outbox_record.occurred_at <> new.occurred_at then
        raise exception 'Release activation outbox envelope is invalid' using errcode = '23514';
    end if;
    if outbox_record.payload <> jsonb_strip_nulls(jsonb_build_object(
            'eventId', new.outbox_event_id,
            'activationId', new.id,
            'courseId', new.course_id,
            'releaseId', new.target_release_id,
            'previousReleaseId', new.previous_release_id,
            'contentChangeSetId', new.source_change_set_id,
            'releaseRevision', new.release_revision,
            'operation', new.operation_kind,
            'questionCount', new.question_count,
            'requiredClientCapabilities', to_jsonb(new.required_client_capabilities),
            'impactBindingSha256', new.impact_binding_sha256
        )) then
        raise exception 'Release activation outbox payload is invalid' using errcode = '23514';
    end if;
    if not exists (
        select 1 from outbox_delivery delivery
         where delivery.event_id = new.outbox_event_id
           and delivery.attempt_count = 0
           and delivery.published_at is null
    ) then
        raise exception 'Release activation outbox delivery is invalid' using errcode = '23514';
    end if;
    if job_record.activation_id is null
        or job_record.course_id <> new.course_id
        or job_record.target_release_id <> new.target_release_id
        or job_record.outbox_event_id <> new.outbox_event_id
        or job_record.enrollment_cutoff_at <> new.occurred_at
        or job_record.status <> 'PENDING'
        or job_record.cursor_enrolled_at is not null
        or job_record.cursor_enrollment_id is not null
        or job_record.processed_count <> 0
        or job_record.attempt_count <> 0
        or job_record.created_at <> new.occurred_at
        or job_record.updated_at <> new.occurred_at
        or job_record.completed_at is not null then
        raise exception 'Release activation reprojection job is invalid' using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_release_activation_fact_valid
    after insert on course_release_activation
    deferrable initially deferred
    for each row execute function validate_course_release_activation_fact();
