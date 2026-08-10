-- Internal-testing MVP expansion: privacy-controlled public profiles,
-- opt-in leaderboards, verified rewarded-ad energy grants, production teacher
-- authorization, and full-tree mobile authoring provenance.
-- Public launch, commerce, payouts, moderation and iOS remain separate gates.

alter table app_user
    add column public_profile_enabled boolean not null default false,
    add column public_bio varchar(280),
    add column avatar_seed varchar(64),
    add column leaderboard_opt_in boolean not null default false,
    add column public_profile_updated_at timestamptz;

alter table app_user
    add constraint ck_app_user_public_bio check (
        public_bio is null or length(btrim(public_bio)) between 1 and 280
    ),
    add constraint ck_app_user_avatar_seed check (
        avatar_seed is null or avatar_seed ~ '^[A-Za-z0-9_-]{8,64}$'
    ),
    add constraint ck_app_user_public_profile_shape check (
        (not public_profile_enabled and not leaderboard_opt_in)
        or (
            public_profile_enabled
            and username is not null
            and username ~ '^[a-z][a-z0-9_]{2,23}$'
            and public_profile_updated_at is not null
        )
    );

create unique index uq_app_user_username_lower
    on app_user(lower(username))
    where username is not null and public_profile_enabled;

create table public_profile_event (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    event_type varchar(32) not null,
    profile_version bigint not null,
    changed_fields varchar(64)[] not null,
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint uq_public_profile_event_version unique (user_id, profile_version),
    constraint ck_public_profile_event_type check (event_type = 'PUBLIC_PROFILE_UPDATED'),
    constraint ck_public_profile_event_version check (profile_version > 0),
    constraint ck_public_profile_event_fields check (cardinality(changed_fields) between 1 and 8),
    constraint ck_public_profile_event_correlation check (length(btrim(correlation_id)) > 0)
);

create trigger tr_public_profile_event_append_only
    before update or delete on public_profile_event
    for each row execute function reject_fact_mutation();

alter table energy_event
    drop constraint ck_energy_event_type,
    drop constraint ck_energy_event_semantics;

alter table energy_event
    add constraint ck_energy_event_type check (
        event_type in (
            'ACCOUNT_INITIALIZED',
            'LAZY_REGENERATED',
            'WRONG_ANSWER_DEBIT',
            'REWARDED_AD_CREDIT'
        )
    ),
    add constraint ck_energy_event_semantics check (
        (event_type = 'ACCOUNT_INITIALIZED'
            and submission_id is null and attempt_id is null
            and delta = 5 and balance_before = 0 and balance_after = 5)
        or (event_type = 'LAZY_REGENERATED'
            and submission_id is null and attempt_id is null
            and delta between 1 and 5)
        or (event_type = 'WRONG_ANSWER_DEBIT'
            and submission_id is not null and attempt_id is not null
            and delta = -1)
        or (event_type = 'REWARDED_AD_CREDIT'
            and submission_id is null and attempt_id is null
            and delta between 0 and 5)
    );

create table rewarded_ad_session (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    idempotency_key uuid not null,
    custom_data varchar(128) not null unique,
    expected_ad_unit_id varchar(128) not null,
    expected_reward_item varchar(64) not null,
    expected_reward_amount integer not null,
    status varchar(24) not null,
    provider_transaction_id varchar(128),
    provider_key_id bigint,
    callback_query_sha256 char(64),
    granted_energy_delta smallint,
    created_at timestamptz not null,
    expires_at timestamptz not null,
    completed_at timestamptz,
    correlation_id varchar(128) not null,
    constraint uq_rewarded_ad_session_command unique (user_id, idempotency_key),
    constraint uq_rewarded_ad_provider_transaction unique (provider_transaction_id),
    constraint ck_rewarded_ad_custom_data check (custom_data ~ '^[A-Za-z0-9_-]{32,128}$'),
    constraint ck_rewarded_ad_expected_values check (
        length(btrim(expected_ad_unit_id)) > 0
        and length(btrim(expected_reward_item)) > 0
        and expected_reward_amount between 1 and 20
    ),
    constraint ck_rewarded_ad_session_status check (
        status in ('PENDING', 'GRANTED', 'REJECTED', 'EXPIRED')
    ),
    constraint ck_rewarded_ad_session_time check (expires_at > created_at),
    constraint ck_rewarded_ad_session_completion check (
        (status = 'PENDING'
            and provider_transaction_id is null
            and provider_key_id is null
            and callback_query_sha256 is null
            and granted_energy_delta is null
            and completed_at is null)
        or (status = 'GRANTED'
            and provider_transaction_id is not null
            and provider_key_id is not null
            and callback_query_sha256 is not null
            and granted_energy_delta between 0 and 20
            and completed_at is not null)
        or (status in ('REJECTED', 'EXPIRED') and completed_at is not null)
    ),
    constraint ck_rewarded_ad_session_correlation check (length(btrim(correlation_id)) > 0)
);

create index ix_rewarded_ad_session_user_created
    on rewarded_ad_session(user_id, created_at desc, id desc);
create index ix_rewarded_ad_session_pending_expiry
    on rewarded_ad_session(expires_at)
    where status = 'PENDING';

create table rewarded_ad_event (
    id uuid primary key,
    session_id uuid not null references rewarded_ad_session(id),
    user_id uuid not null references app_user(id),
    event_type varchar(32) not null,
    provider_transaction_id varchar(128),
    energy_delta smallint,
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint uq_rewarded_ad_event_type unique (session_id, event_type),
    constraint ck_rewarded_ad_event_type check (
        event_type in ('SESSION_CREATED', 'REWARD_GRANTED', 'REWARD_REJECTED', 'SESSION_EXPIRED')
    ),
    constraint ck_rewarded_ad_event_shape check (
        (event_type = 'SESSION_CREATED' and provider_transaction_id is null and energy_delta is null)
        or (event_type = 'REWARD_GRANTED' and provider_transaction_id is not null and energy_delta between 0 and 20)
        or (event_type in ('REWARD_REJECTED', 'SESSION_EXPIRED') and energy_delta is null)
    ),
    constraint ck_rewarded_ad_event_correlation check (length(btrim(correlation_id)) > 0)
);

create trigger tr_rewarded_ad_event_append_only
    before update or delete on rewarded_ad_event
    for each row execute function reject_fact_mutation();

create table teacher_authorization (
    user_id uuid primary key references app_user(id),
    status varchar(16) not null,
    accepted_terms_version varchar(64),
    accepted_at timestamptz,
    revoked_at timestamptz,
    updated_at timestamptz not null,
    constraint ck_teacher_authorization_status check (status in ('ACTIVE', 'REVOKED')),
    constraint ck_teacher_authorization_shape check (
        (status = 'ACTIVE'
            and accepted_terms_version is not null
            and length(btrim(accepted_terms_version)) between 1 and 64
            and accepted_at is not null
            and revoked_at is null)
        or (status = 'REVOKED' and revoked_at is not null)
    )
);

create table teacher_authorization_event (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    event_type varchar(32) not null,
    terms_version varchar(64),
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint ck_teacher_authorization_event_type check (
        event_type in ('TERMS_ACCEPTED', 'ACCESS_REVOKED')
    ),
    constraint ck_teacher_authorization_event_correlation check (length(btrim(correlation_id)) > 0)
);

create trigger tr_teacher_authorization_event_append_only
    before update or delete on teacher_authorization_event
    for each row execute function reject_fact_mutation();

create table course_release_metadata (
    course_release_id uuid primary key,
    course_id uuid not null,
    course_name varchar(160) not null,
    course_description varchar(2000),
    visibility varchar(16) not null,
    created_at timestamptz not null,
    constraint fk_course_release_metadata_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint ck_course_release_metadata_name check (length(btrim(course_name)) between 1 and 160),
    constraint ck_course_release_metadata_description check (
        course_description is null or length(btrim(course_description)) between 1 and 2000
    ),
    constraint ck_course_release_metadata_visibility check (visibility in ('PUBLIC', 'PRIVATE'))
);

insert into course_release_metadata(
    course_release_id, course_id, course_name, course_description, visibility, created_at
)
select release_row.id, release_row.course_id, course.name, course.description,
       course.visibility, release_row.created_at
  from course_release release_row
  join course on course.id = release_row.course_id;

create trigger tr_course_release_metadata_append_only
    before update or delete on course_release_metadata
    for each row execute function reject_fact_mutation();

create table full_course_authoring_commit (
    id uuid primary key,
    command_id uuid not null,
    course_id uuid not null references course(id),
    owner_user_id uuid not null references app_user(id),
    base_release_id uuid not null,
    content_change_set_id uuid not null unique,
    draft_release_id uuid not null unique,
    outbox_event_id uuid not null unique,
    document_sha256 char(64) not null,
    level_count integer not null,
    unit_count integer not null,
    topic_count integer not null,
    test_count integer not null,
    question_count integer not null,
    created_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint uq_full_course_authoring_command unique (owner_user_id, command_id),
    constraint fk_full_course_authoring_base foreign key (base_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_full_course_authoring_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint fk_full_course_authoring_draft foreign key (draft_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_full_course_authoring_outbox foreign key (outbox_event_id)
        references outbox_event(id) deferrable initially deferred,
    constraint ck_full_course_authoring_digest check (document_sha256 ~ '^[0-9a-f]{64}$'),
    constraint ck_full_course_authoring_counts check (
        level_count between 1 and 100
        and unit_count between 1 and 500
        and topic_count between 1 and 2000
        and test_count between 1 and 5000
        and question_count between 1 and 10000
    ),
    constraint ck_full_course_authoring_correlation check (length(btrim(correlation_id)) > 0)
);

create trigger tr_full_course_authoring_commit_append_only
    before update or delete on full_course_authoring_commit
    for each row execute function reject_fact_mutation();


create function validate_full_course_authoring_commit() returns trigger language plpgsql as $$
declare
    actual_count integer;
    actual_capabilities varchar(64)[];
    expected_capabilities varchar(64)[];
    course_record record;
    base_record record;
    draft_record record;
    change_set_record record;
    metadata_record record;
    outbox_record record;
begin
    select * into course_record from course where id = new.course_id;
    select * into base_record from course_release where id = new.base_release_id;
    select * into draft_record from course_release where id = new.draft_release_id;
    select * into change_set_record from content_change_set where id = new.content_change_set_id;
    select * into metadata_record from course_release_metadata where course_release_id = new.draft_release_id;
    select * into outbox_record from outbox_event where id = new.outbox_event_id;

    if course_record.id is null
        or course_record.owner_user_id <> new.owner_user_id
        or course_record.active_release_id <> new.base_release_id
        or course_record.publication_status not in ('PUBLISHED', 'HIDDEN') then
        raise exception 'Full editor commit does not match the owned active course' using errcode = '23514';
    end if;
    if base_record.id is null or base_record.course_id <> new.course_id or base_record.status <> 'ACTIVE' then
        raise exception 'Full editor base release is not active' using errcode = '23514';
    end if;
    if draft_record.id is null
        or draft_record.course_id <> new.course_id
        or draft_record.status <> 'DRAFT'
        or draft_record.revision_number <> (
            select coalesce(max(candidate.revision_number), 0) + 1
              from course_release candidate
             where candidate.course_id = new.course_id
               and candidate.id <> new.draft_release_id
        )
        or draft_record.created_at <> new.created_at then
        raise exception 'Full editor target is not the next immutable DRAFT release' using errcode = '23514';
    end if;
    if change_set_record.id is null
        or change_set_record.course_id <> new.course_id
        or change_set_record.owner_user_id <> new.owner_user_id
        or change_set_record.base_release_id <> new.base_release_id
        or change_set_record.source_type <> 'MOBILE_AUTHORING'
        or change_set_record.source_reference_id <> new.command_id
        or change_set_record.status <> 'COMMITTED'
        or change_set_record.created_at <> new.created_at
        or change_set_record.committed_at <> new.created_at
        or change_set_record.correlation_id <> new.correlation_id then
        raise exception 'Full editor change set is invalid' using errcode = '23514';
    end if;
    if not exists (
        select 1 from course_release_source_change_set source
         where source.course_release_id = new.draft_release_id
           and source.course_id = new.course_id
           and source.content_change_set_id = new.content_change_set_id
           and source.created_at = new.created_at
    ) then
        raise exception 'Full editor release source provenance is invalid' using errcode = '23514';
    end if;
    if metadata_record.course_release_id is null
        or metadata_record.course_id <> new.course_id
        or metadata_record.created_at <> new.created_at then
        raise exception 'Full editor release metadata is missing' using errcode = '23514';
    end if;
    if not exists (
        select 1 from content_change_set_event
         where content_change_set_id = new.content_change_set_id
           and event_type = 'CREATED'
           and actor_user_id = new.owner_user_id
           and occurred_at = new.created_at
           and correlation_id = new.correlation_id
    ) or not exists (
        select 1 from content_change_set_event
         where content_change_set_id = new.content_change_set_id
           and event_type = 'COMMITTED'
           and actor_user_id = new.owner_user_id
           and occurred_at = new.created_at
           and correlation_id = new.correlation_id
    ) then
        raise exception 'Full editor requires exact change-set lifecycle facts' using errcode = '23514';
    end if;

    select count(*) into actual_count from content_level_revision
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.level_count then
        raise exception 'Full editor level count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from content_unit_revision
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.unit_count then
        raise exception 'Full editor unit count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from content_topic_revision
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.topic_count then
        raise exception 'Full editor topic count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from test_revision_source_change_set
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.test_count then
        raise exception 'Full editor test count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from question_revision_source_change_set
     where content_change_set_id = new.content_change_set_id;
    if actual_count <> new.question_count then
        raise exception 'Full editor question count is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count from course_release_test_revision
     where course_release_id = new.draft_release_id;
    if actual_count <> new.test_count then
        raise exception 'Full editor release test manifest is incomplete' using errcode = '23514';
    end if;
    select count(*) into actual_count
      from course_release_test_revision release_test
      join test_revision_question question on question.test_revision_id = release_test.test_revision_id
     where release_test.course_release_id = new.draft_release_id;
    if actual_count <> new.question_count then
        raise exception 'Full editor release question manifest is incomplete' using errcode = '23514';
    end if;
    if exists (
        select 1 from test_revision_source_change_set source
        join test_revision revision on revision.id = source.test_revision_id
         where source.content_change_set_id = new.content_change_set_id and revision.status <> 'DRAFT'
    ) or exists (
        select 1 from question_revision_source_change_set source
        join question_revision revision on revision.id = source.question_revision_id
         where source.content_change_set_id = new.content_change_set_id and revision.status <> 'DRAFT'
    ) then
        raise exception 'Full editor cannot activate revisions while saving a draft' using errcode = '23514';
    end if;

    if exists (
        select 1 from question_revision_source_change_set source
        join question_revision revision on revision.id = source.question_revision_id
         where source.content_change_set_id = new.content_change_set_id
           and revision.question_type = 'D'
    ) then
        expected_capabilities := array['question.matching.v1']::varchar(64)[];
    else
        expected_capabilities := '{}'::varchar(64)[];
    end if;
    select coalesce(array_agg(capability order by capability), '{}'::varchar(64)[])
      into actual_capabilities
      from course_release_required_capability
     where course_release_id = new.draft_release_id;
    if actual_capabilities is distinct from expected_capabilities then
        raise exception 'Full editor release capabilities are incomplete' using errcode = '23514';
    end if;

    if outbox_record.id is null
        or outbox_record.aggregate_type <> 'course'
        or outbox_record.aggregate_id <> new.course_id
        or outbox_record.event_type <> 'content.full-course-draft-created.v1'
        or outbox_record.schema_version <> 1
        or outbox_record.correlation_id <> new.correlation_id
        or outbox_record.occurred_at <> new.created_at
        or outbox_record.payload <> jsonb_build_object(
            'eventId', new.outbox_event_id,
            'courseId', new.course_id,
            'baseReleaseId', new.base_release_id,
            'draftReleaseId', new.draft_release_id,
            'contentChangeSetId', new.content_change_set_id,
            'releaseRevision', draft_record.revision_number,
            'questionCount', new.question_count,
            'requiredClientCapabilities', to_jsonb(expected_capabilities),
            'documentSha256', new.document_sha256
        )
        or not exists (
            select 1 from outbox_delivery
             where event_id = new.outbox_event_id
               and attempt_count = 0
               and published_at is null
        ) then
        raise exception 'Full editor requires the exact transactional draft-created outbox fact' using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_full_course_authoring_commit_valid
    after insert on full_course_authoring_commit
    deferrable initially deferred
    for each row execute function validate_full_course_authoring_commit();
