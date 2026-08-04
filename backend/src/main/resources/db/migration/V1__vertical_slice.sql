create table app_user (
    id uuid primary key,
    oidc_subject varchar(255) not null unique,
    email varchar(320),
    display_name varchar(80) not null,
    username varchar(40),
    app_locale varchar(35) not null,
    active_target_language varchar(35) not null,
    time_zone varchar(64) not null default 'UTC',
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint ck_app_user_subject_not_blank check (length(btrim(oidc_subject)) > 0),
    constraint ck_app_user_app_locale_canonical check (
        app_locale ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    ),
    constraint ck_app_user_target_language_canonical check (
        active_target_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    )
);

create table course (
    id uuid primary key,
    owner_user_id uuid not null references app_user(id),
    name varchar(160) not null,
    description varchar(2000),
    target_language varchar(35) not null,
    default_support_language varchar(35) not null,
    visibility varchar(16) not null,
    publication_status varchar(24) not null,
    access_type varchar(16) not null,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint ck_course_name_not_blank check (length(btrim(name)) > 0),
    constraint ck_course_visibility check (visibility in ('PUBLIC', 'PRIVATE')),
    constraint ck_course_publication_status check (publication_status in ('DRAFT', 'PUBLISHED', 'HIDDEN', 'REMOVED')),
    constraint ck_course_access_type check (access_type in ('FREE', 'PAID')),
    constraint ck_course_target_language_canonical check (
        target_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    ),
    constraint ck_course_default_support_language_canonical check (
        default_support_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    )
);

create table course_support_language (
    course_id uuid not null references course(id) on delete cascade,
    language_code varchar(35) not null,
    primary key (course_id, language_code),
    constraint ck_course_support_language_canonical check (
        language_code ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    )
);

create table course_release (
    id uuid primary key,
    course_id uuid not null references course(id) on delete cascade,
    revision_number integer not null,
    status varchar(16) not null,
    created_at timestamptz not null,
    constraint uq_course_release_identity unique (id, course_id),
    constraint uq_course_release_revision unique (course_id, revision_number),
    constraint ck_course_release_revision check (revision_number > 0),
    constraint ck_course_release_status check (status in ('DRAFT', 'ACTIVE', 'RETIRED'))
);

create unique index uq_course_release_active on course_release(course_id) where status = 'ACTIVE';

alter table course add column active_release_id uuid not null;
alter table course
    add constraint fk_course_active_release
    foreign key (active_release_id, id)
    references course_release(id, course_id)
    deferrable initially deferred;

alter table course
    add constraint fk_course_default_support_language
    foreign key (id, default_support_language)
    references course_support_language(course_id, language_code)
    deferrable initially deferred;

create table enrollment (
    id uuid primary key,
    course_id uuid not null references course(id),
    user_id uuid not null references app_user(id),
    support_language varchar(35) not null,
    status varchar(16) not null,
    enrolled_at timestamptz not null,
    constraint uq_enrollment_course_user unique (course_id, user_id),
    constraint fk_enrollment_support_language foreign key (course_id, support_language)
        references course_support_language(course_id, language_code),
    constraint ck_enrollment_status check (status in ('ACTIVE', 'ARCHIVED', 'REVOKED')),
    constraint ck_enrollment_support_language_canonical check (
        support_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    )
);

create table course_test (
    id uuid primary key,
    course_id uuid not null references course(id),
    created_at timestamptz not null,
    constraint uq_course_test_identity unique (id, course_id)
);

create table test_revision (
    id uuid primary key,
    test_id uuid not null,
    course_id uuid not null,
    revision_number integer not null,
    title varchar(160) not null,
    status varchar(16) not null,
    pass_threshold numeric(5,4) not null default 0.5000,
    created_at timestamptz not null,
    constraint fk_test_revision_test foreign key (test_id, course_id)
        references course_test(id, course_id),
    constraint uq_test_revision_number unique (test_id, revision_number),
    constraint uq_test_revision_identity unique (id, course_id),
    constraint uq_test_revision_stable_identity unique (id, test_id, course_id),
    constraint ck_test_revision_number check (revision_number > 0),
    constraint ck_test_revision_title_not_blank check (length(btrim(title)) > 0),
    constraint ck_test_revision_status check (status in ('DRAFT', 'ACTIVE', 'RETIRED')),
    constraint ck_test_revision_pass_threshold check (pass_threshold > 0 and pass_threshold <= 1)
);

create unique index uq_test_revision_active on test_revision(test_id) where status = 'ACTIVE';

create table course_release_test_revision (
    course_release_id uuid not null,
    test_revision_id uuid not null,
    test_id uuid not null,
    course_id uuid not null,
    position integer not null,
    primary key (course_release_id, test_revision_id),
    constraint fk_release_test_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_release_test_revision foreign key (test_revision_id, test_id, course_id)
        references test_revision(id, test_id, course_id),
    constraint uq_release_stable_test unique (course_release_id, test_id),
    constraint uq_release_test_course_identity unique (course_release_id, test_revision_id, course_id),
    constraint uq_release_test_position unique (course_release_id, position),
    constraint ck_release_test_position check (position > 0)
);

create table question (
    id uuid primary key,
    course_id uuid not null references course(id),
    created_at timestamptz not null,
    constraint uq_question_identity unique (id, course_id)
);

create table question_revision (
    id uuid primary key,
    question_id uuid not null,
    course_id uuid not null,
    revision_number integer not null,
    question_type varchar(8) not null,
    prompt varchar(1000) not null,
    correct_answer varchar(500) not null,
    status varchar(16) not null,
    created_at timestamptz not null,
    constraint fk_question_revision_question foreign key (question_id, course_id)
        references question(id, course_id),
    constraint uq_question_revision_number unique (question_id, revision_number),
    constraint uq_question_revision_identity unique (id, course_id),
    constraint uq_question_revision_stable_identity unique (id, question_id, course_id),
    constraint ck_question_revision_number check (revision_number > 0),
    constraint ck_question_revision_type check (question_type in ('A')),
    constraint ck_question_revision_prompt_not_blank check (length(btrim(prompt)) > 0),
    constraint ck_question_revision_answer_not_blank check (length(btrim(correct_answer)) > 0),
    constraint ck_question_revision_status check (status in ('DRAFT', 'ACTIVE', 'RETIRED'))
);

create table question_revision_option (
    id uuid primary key,
    question_revision_id uuid not null references question_revision(id) on delete cascade,
    option_text varchar(500) not null,
    is_correct boolean not null,
    position integer not null,
    constraint uq_question_option_identity unique (question_revision_id, id),
    constraint uq_question_option_position unique (question_revision_id, position),
    constraint ck_question_option_text_not_blank check (length(btrim(option_text)) > 0),
    constraint ck_question_option_position check (position between 1 and 4)
);

create table test_revision_question (
    test_revision_id uuid not null,
    question_revision_id uuid not null,
    question_id uuid not null,
    course_id uuid not null,
    position integer not null,
    primary key (test_revision_id, question_revision_id),
    constraint fk_test_question_test_revision foreign key (test_revision_id, course_id)
        references test_revision(id, course_id),
    constraint fk_test_question_question_revision foreign key (question_revision_id, question_id, course_id)
        references question_revision(id, question_id, course_id),
    constraint uq_test_revision_stable_question unique (test_revision_id, question_id),
    constraint uq_test_question_course_identity unique (test_revision_id, question_revision_id, course_id),
    constraint uq_test_revision_question_position unique (test_revision_id, position),
    constraint ck_test_revision_question_position check (position > 0)
);

create table test_attempt (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    course_id uuid not null references course(id),
    course_release_id uuid not null,
    course_access_type varchar(16) not null,
    test_revision_id uuid not null,
    status varchar(32) not null,
    shuffle_seed bigint not null,
    total_questions integer not null,
    answered_count integer not null default 0,
    correct_count integer not null default 0,
    started_at timestamptz not null,
    finished_at timestamptz,
    version bigint not null default 0,
    constraint fk_test_attempt_revision foreign key (test_revision_id, course_id)
        references test_revision(id, course_id),
    constraint fk_test_attempt_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_test_attempt_release_test foreign key (course_release_id, test_revision_id)
        references course_release_test_revision(course_release_id, test_revision_id),
    constraint uq_test_attempt_identity_user unique (id, user_id),
    constraint uq_test_attempt_manifest_identity unique (id, test_revision_id, course_id),
    constraint ck_test_attempt_access_type check (course_access_type in ('FREE', 'PAID')),
    constraint ck_test_attempt_status check (status in ('IN_PROGRESS', 'COMPLETED_PASS', 'COMPLETED_FAIL', 'INTERRUPTED_ENERGY')),
    constraint ck_test_attempt_total_questions check (total_questions > 0),
    constraint ck_test_attempt_answered_count check (answered_count >= 0 and answered_count <= total_questions),
    constraint ck_test_attempt_correct_count check (correct_count >= 0 and correct_count <= answered_count),
    constraint ck_test_attempt_finished_state check (
        (status = 'IN_PROGRESS' and finished_at is null)
        or (status <> 'IN_PROGRESS' and finished_at is not null)
    )
);

create table attempt_question_manifest (
    attempt_id uuid not null,
    test_revision_id uuid not null,
    course_id uuid not null,
    question_revision_id uuid not null,
    position integer not null,
    primary key (attempt_id, question_revision_id),
    constraint fk_attempt_manifest_attempt foreign key (attempt_id, test_revision_id, course_id)
        references test_attempt(id, test_revision_id, course_id),
    constraint fk_attempt_manifest_pinned_question foreign key (test_revision_id, question_revision_id, course_id)
        references test_revision_question(test_revision_id, question_revision_id, course_id),
    constraint uq_attempt_manifest_position unique (attempt_id, position),
    constraint ck_attempt_manifest_position check (position > 0)
);

create table answer_submission (
    submission_id uuid primary key,
    attempt_id uuid not null,
    user_id uuid not null,
    question_revision_id uuid not null,
    selected_option_id uuid not null,
    is_correct boolean not null,
    active_score_delta smallint not null,
    lifetime_score_delta smallint not null,
    active_question_score smallint not null,
    lifetime_score bigint not null,
    energy_balance_after smallint not null,
    energy_unlimited boolean not null,
    energy_next_regeneration_at timestamptz,
    attempt_status_after varchar(32) not null,
    submitted_at timestamptz not null,
    constraint fk_answer_attempt_user foreign key (attempt_id, user_id)
        references test_attempt(id, user_id),
    constraint fk_answer_manifest foreign key (attempt_id, question_revision_id)
        references attempt_question_manifest(attempt_id, question_revision_id),
    constraint fk_answer_selected_option foreign key (question_revision_id, selected_option_id)
        references question_revision_option(question_revision_id, id),
    constraint uq_answer_attempt_question unique (attempt_id, question_revision_id),
    constraint uq_answer_submission_attempt unique (submission_id, attempt_id),
    constraint uq_answer_submission_attempt_owner unique (submission_id, attempt_id, user_id),
    constraint uq_answer_submission_score_owner unique (submission_id, attempt_id, user_id, question_revision_id),
    constraint ck_answer_active_delta check (active_score_delta in (0, 20, 60)),
    constraint ck_answer_lifetime_delta check (lifetime_score_delta in (0, 12, 20, 60)),
    constraint ck_answer_active_question_score check (active_question_score between 0 and 60),
    constraint ck_answer_lifetime_score check (lifetime_score >= 0),
    constraint ck_answer_energy check (energy_balance_after between 0 and 5),
    constraint ck_answer_attempt_status check (attempt_status_after in ('IN_PROGRESS', 'INTERRUPTED_ENERGY'))
);

create table attempt_event (
    id uuid primary key,
    attempt_id uuid not null references test_attempt(id),
    submission_id uuid,
    event_type varchar(32) not null,
    payload jsonb not null default '{}'::jsonb,
    occurred_at timestamptz not null,
    constraint fk_attempt_event_answer foreign key (submission_id, attempt_id)
        references answer_submission(submission_id, attempt_id) deferrable initially deferred,
    constraint ck_attempt_event_type check (event_type in ('STARTED', 'ANSWER_RECORDED', 'INTERRUPTED_ENERGY', 'COMPLETED_PASS', 'COMPLETED_FAIL'))
);

create table question_mastery (
    user_id uuid not null references app_user(id),
    question_revision_id uuid not null references question_revision(id),
    active_score smallint not null,
    encounter_count integer not null,
    correct_count integer not null,
    version bigint not null default 0,
    last_answered_at timestamptz not null,
    primary key (user_id, question_revision_id),
    constraint ck_mastery_active_score check (active_score in (0, 20, 40, 60)),
    constraint ck_mastery_encounters check (encounter_count >= 0),
    constraint ck_mastery_correct_count check (correct_count >= 0 and correct_count <= encounter_count)
);

create table score_event (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    attempt_id uuid not null references test_attempt(id),
    submission_id uuid not null unique,
    question_revision_id uuid not null references question_revision(id),
    active_delta smallint not null,
    lifetime_delta smallint not null,
    occurred_at timestamptz not null,
    constraint fk_score_event_answer foreign key (submission_id, attempt_id, user_id, question_revision_id)
        references answer_submission(submission_id, attempt_id, user_id, question_revision_id),
    constraint ck_score_event_active_delta check (active_delta in (0, 20, 60)),
    constraint ck_score_event_lifetime_delta check (lifetime_delta in (0, 12, 20, 60))
);

create table energy_account (
    user_id uuid primary key references app_user(id),
    balance smallint not null,
    regeneration_anchor_at timestamptz not null,
    version bigint not null default 0,
    constraint ck_energy_account_balance check (balance between 0 and 5)
);

create table energy_event (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    attempt_id uuid references test_attempt(id),
    submission_id uuid references answer_submission(submission_id) deferrable initially deferred,
    event_type varchar(32) not null,
    delta smallint not null,
    balance_before smallint not null,
    balance_after smallint not null,
    occurred_at timestamptz not null,
    constraint fk_energy_event_answer foreign key (submission_id, attempt_id, user_id)
        references answer_submission(submission_id, attempt_id, user_id),
    constraint ck_energy_event_type check (event_type in ('ACCOUNT_INITIALIZED', 'LAZY_REGENERATED', 'WRONG_ANSWER_DEBIT')),
    constraint ck_energy_event_balance_before check (balance_before between 0 and 5),
    constraint ck_energy_event_balance_after check (balance_after between 0 and 5),
    constraint ck_energy_event_delta check (delta between -1 and 5),
    constraint ck_energy_event_math check (balance_after = balance_before + delta),
    constraint ck_energy_event_answer_context check (
        (submission_id is null and attempt_id is null)
        or (submission_id is not null and attempt_id is not null)
    ),
    constraint ck_energy_event_semantics check (
        (event_type = 'ACCOUNT_INITIALIZED'
            and submission_id is null and attempt_id is null
            and delta = 5 and balance_before = 0 and balance_after = 5)
        or (event_type = 'LAZY_REGENERATED'
            and submission_id is null and attempt_id is null
            and delta between 1 and 5)
        or (event_type = 'WRONG_ANSWER_DEBIT'
            and submission_id is not null and attempt_id is not null
            and delta = -1)
    )
);

create table streak_day (
    user_id uuid not null references app_user(id),
    local_date date not null,
    time_zone varchar(64) not null,
    qualifying_attempt_id uuid not null,
    created_at timestamptz not null,
    primary key (user_id, local_date),
    constraint fk_streak_day_attempt_owner foreign key (qualifying_attempt_id, user_id)
        references test_attempt(id, user_id)
);

create table outbox_event (
    id uuid primary key,
    aggregate_type varchar(80) not null,
    aggregate_id uuid not null,
    event_type varchar(120) not null,
    schema_version integer not null,
    payload jsonb not null,
    correlation_id varchar(128) not null,
    occurred_at timestamptz not null,
    constraint ck_outbox_aggregate_type_not_blank check (length(btrim(aggregate_type)) > 0),
    constraint ck_outbox_event_type_not_blank check (length(btrim(event_type)) > 0),
    constraint ck_outbox_schema_version check (schema_version > 0),
    constraint ck_outbox_correlation_not_blank check (length(btrim(correlation_id)) > 0)
);

create table outbox_delivery (
    event_id uuid primary key references outbox_event(id),
    attempt_count integer not null default 0,
    published_at timestamptz,
    last_error varchar(2000),
    constraint ck_outbox_delivery_attempt_count check (attempt_count >= 0)
);

create table command_idempotency (
    user_id uuid not null references app_user(id),
    operation varchar(80) not null,
    idempotency_key uuid not null,
    request_fingerprint char(64) not null,
    resource_id uuid not null,
    created_at timestamptz not null,
    primary key (user_id, operation, idempotency_key),
    constraint ck_command_operation_not_blank check (length(btrim(operation)) > 0),
    constraint ck_command_fingerprint check (request_fingerprint ~ '^[0-9a-f]{64}$')
);

create index ix_course_catalog on course(publication_status, visibility, id);
create index ix_enrollment_user on enrollment(user_id, status);
create index ix_attempt_user on test_attempt(user_id, started_at desc);
create index ix_attempt_manifest_attempt on attempt_question_manifest(attempt_id, position);
create index ix_score_event_user on score_event(user_id, occurred_at desc);
create index ix_outbox_event_occurred on outbox_event(occurred_at);

create function reject_fact_mutation() returns trigger language plpgsql as $$
begin
    raise exception '% is append-only', tg_table_name using errcode = '55000';
end;
$$;

create trigger tr_answer_submission_append_only before update or delete on answer_submission
    for each row execute function reject_fact_mutation();
create trigger tr_attempt_event_append_only before update or delete on attempt_event
    for each row execute function reject_fact_mutation();
create trigger tr_score_event_append_only before update or delete on score_event
    for each row execute function reject_fact_mutation();
create trigger tr_energy_event_append_only before update or delete on energy_event
    for each row execute function reject_fact_mutation();
create trigger tr_outbox_event_append_only before update or delete on outbox_event
    for each row execute function reject_fact_mutation();
create trigger tr_course_release_test_revision_append_only before update or delete on course_release_test_revision
    for each row execute function reject_fact_mutation();
create trigger tr_question_revision_option_append_only before update or delete on question_revision_option
    for each row execute function reject_fact_mutation();
create trigger tr_test_revision_question_append_only before update or delete on test_revision_question
    for each row execute function reject_fact_mutation();
create trigger tr_attempt_question_manifest_append_only before update or delete on attempt_question_manifest
    for each row execute function reject_fact_mutation();
create trigger tr_question_revision_no_delete before delete on question_revision
    for each row execute function reject_fact_mutation();
create trigger tr_test_revision_no_delete before delete on test_revision
    for each row execute function reject_fact_mutation();
create trigger tr_course_release_no_delete before delete on course_release
    for each row execute function reject_fact_mutation();
create trigger tr_course_test_append_only before update or delete on course_test
    for each row execute function reject_fact_mutation();
create trigger tr_question_append_only before update or delete on question
    for each row execute function reject_fact_mutation();

create function require_initial_draft_status() returns trigger language plpgsql as $$
begin
    if new.status <> 'DRAFT' then
        raise exception '% must be inserted as DRAFT', tg_table_name using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_course_release_starts_draft before insert on course_release
    for each row execute function require_initial_draft_status();
create trigger tr_test_revision_starts_draft before insert on test_revision
    for each row execute function require_initial_draft_status();
create trigger tr_question_revision_starts_draft before insert on question_revision
    for each row execute function require_initial_draft_status();

create function require_draft_parent_for_content() returns trigger language plpgsql as $$
declare
    parent_status varchar(16);
begin
    if tg_table_name = 'course_release_test_revision' then
        select status into parent_status from course_release where id = new.course_release_id;
    elsif tg_table_name = 'test_revision_question' then
        select status into parent_status from test_revision where id = new.test_revision_id;
    elsif tg_table_name = 'question_revision_option' then
        select status into parent_status from question_revision where id = new.question_revision_id;
    end if;
    if parent_status is distinct from 'DRAFT' then
        raise exception 'Cannot add content to non-draft parent for %', tg_table_name using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_release_test_requires_draft before insert on course_release_test_revision
    for each row execute function require_draft_parent_for_content();
create trigger tr_test_question_requires_draft before insert on test_revision_question
    for each row execute function require_draft_parent_for_content();
create trigger tr_question_option_requires_draft before insert on question_revision_option
    for each row execute function require_draft_parent_for_content();

create function protect_course_lifecycle() returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        if new.publication_status <> 'DRAFT' then
            raise exception 'course must be inserted as DRAFT' using errcode = '23514';
        end if;
        return new;
    end if;

    if old.publication_status <> 'DRAFT' and (
        new.owner_user_id <> old.owner_user_id
        or new.name <> old.name
        or new.description is distinct from old.description
        or new.target_language <> old.target_language
        or new.default_support_language <> old.default_support_language
        or new.visibility <> old.visibility
        or new.access_type <> old.access_type
        or new.created_at <> old.created_at
    ) then
        raise exception 'Published course metadata is frozen; create a new versioned release'
            using errcode = '55000';
    end if;

    if (old.publication_status = 'DRAFT' and new.publication_status not in ('DRAFT', 'PUBLISHED'))
        or (old.publication_status = 'PUBLISHED' and new.publication_status not in ('PUBLISHED', 'HIDDEN', 'REMOVED'))
        or (old.publication_status = 'HIDDEN' and new.publication_status not in ('HIDDEN', 'PUBLISHED', 'REMOVED'))
        or (old.publication_status = 'REMOVED' and new.publication_status <> 'REMOVED') then
        raise exception 'Invalid course publication transition % -> %', old.publication_status, new.publication_status
            using errcode = '23514';
    end if;
    if new.updated_at < old.updated_at then
        raise exception 'course.updated_at cannot move backwards' using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_course_lifecycle before insert or update on course
    for each row execute function protect_course_lifecycle();
create trigger tr_course_no_delete before delete on course
    for each row execute function reject_fact_mutation();

create function require_draft_course_for_support_language() returns trigger language plpgsql as $$
declare
    target_course_id uuid;
    parent_status varchar(24);
begin
    target_course_id := case when tg_op = 'DELETE' then old.course_id else new.course_id end;
    select publication_status into parent_status from course where id = target_course_id;
    if parent_status is distinct from 'DRAFT' then
        raise exception 'Course support languages are frozen after publication' using errcode = '55000';
    end if;
    return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger tr_course_support_language_requires_draft before insert or update or delete on course_support_language
    for each row execute function require_draft_course_for_support_language();

create function reject_revision_content_mutation() returns trigger language plpgsql as $$
declare
    child_count integer;
    inactive_child_count integer;
    correct_count integer;
    referenced_count integer;
begin
    if new.status = 'DRAFT' and old.status <> 'DRAFT' then
        raise exception '% cannot return to DRAFT', tg_table_name using errcode = '55000';
    end if;
    if tg_table_name = 'course_release' then
        if new.id <> old.id
            or new.course_id <> old.course_id
            or new.revision_number <> old.revision_number
            or new.created_at <> old.created_at then
            raise exception 'course_release content is immutable' using errcode = '55000';
        end if;
        if new.status = 'ACTIVE' and old.status <> 'ACTIVE' then
            select count(*), count(*) filter (where tr.status <> 'ACTIVE')
              into child_count, inactive_child_count
              from course_release_test_revision crtr
              join test_revision tr on tr.id = crtr.test_revision_id
             where crtr.course_release_id = new.id;
            if child_count = 0 or inactive_child_count <> 0 then
                raise exception 'An active course release must contain only ACTIVE test revisions'
                    using errcode = '23514';
            end if;
        end if;
    elsif tg_table_name = 'question_revision' then
        if new.id <> old.id
            or new.question_id <> old.question_id
            or new.course_id <> old.course_id
            or new.revision_number <> old.revision_number
            or new.question_type <> old.question_type
            or new.prompt <> old.prompt
            or new.correct_answer <> old.correct_answer
            or new.created_at <> old.created_at then
            raise exception 'question_revision content is immutable' using errcode = '55000';
        end if;
        if new.status = 'ACTIVE' and old.status <> 'ACTIVE' then
            select count(*), count(*) filter (where is_correct)
              into child_count, correct_count
              from question_revision_option
             where question_revision_id = new.id;
            if child_count <> 4 or correct_count <> 1 then
                raise exception 'An active A question revision must have four options and one correct option'
                    using errcode = '23514';
            end if;
        end if;
        if old.status = 'ACTIVE' and new.status <> 'ACTIVE' then
            select count(*) into referenced_count
              from test_revision_question trq
              join test_revision tr on tr.id = trq.test_revision_id
             where trq.question_revision_id = old.id
               and tr.status = 'ACTIVE';
            if referenced_count <> 0 then
                raise exception 'An ACTIVE test revision still references this question revision'
                    using errcode = '23514';
            end if;
        end if;
    elsif tg_table_name = 'test_revision' then
        if new.id <> old.id
            or new.test_id <> old.test_id
            or new.course_id <> old.course_id
            or new.revision_number <> old.revision_number
            or new.title <> old.title
            or new.pass_threshold <> old.pass_threshold
            or new.created_at <> old.created_at then
            raise exception 'test_revision content is immutable' using errcode = '55000';
        end if;
        if new.status = 'ACTIVE' and old.status <> 'ACTIVE' then
            select count(*), count(*) filter (where qr.status <> 'ACTIVE')
              into child_count, inactive_child_count
              from test_revision_question trq
              join question_revision qr on qr.id = trq.question_revision_id
             where trq.test_revision_id = new.id;
            if child_count = 0 or inactive_child_count <> 0 then
                raise exception 'An active test revision must contain only ACTIVE question revisions'
                    using errcode = '23514';
            end if;
        end if;
        if old.status = 'ACTIVE' and new.status <> 'ACTIVE' then
            select count(*) into referenced_count
              from course_release_test_revision crtr
              join course_release cr on cr.id = crtr.course_release_id
             where crtr.test_revision_id = old.id
               and cr.status = 'ACTIVE';
            if referenced_count <> 0 then
                raise exception 'An ACTIVE course release still references this test revision'
                    using errcode = '23514';
            end if;
        end if;
    end if;
    return new;
end;
$$;

create trigger tr_question_revision_content_immutable before update on question_revision
    for each row execute function reject_revision_content_mutation();
create trigger tr_test_revision_content_immutable before update on test_revision
    for each row execute function reject_revision_content_mutation();
create trigger tr_course_release_content_immutable before update on course_release
    for each row execute function reject_revision_content_mutation();

create function protect_attempt_snapshot() returns trigger language plpgsql as $$
declare
    required_threshold numeric(5,4);
    expected_completion_status varchar(32);
begin
    if new.id <> old.id
        or new.user_id <> old.user_id
        or new.course_id <> old.course_id
        or new.course_release_id <> old.course_release_id
        or new.course_access_type <> old.course_access_type
        or new.test_revision_id <> old.test_revision_id
        or new.shuffle_seed <> old.shuffle_seed
        or new.total_questions <> old.total_questions
        or new.started_at <> old.started_at then
        raise exception 'test_attempt snapshot identity is immutable' using errcode = '55000';
    end if;
    if old.status <> 'IN_PROGRESS' then
        raise exception 'A terminal test_attempt is immutable' using errcode = '55000';
    end if;
    if new.version <> old.version + 1
        or new.answered_count < old.answered_count
        or new.answered_count > old.answered_count + 1
        or new.correct_count < old.correct_count
        or new.correct_count > old.correct_count + (new.answered_count - old.answered_count) then
        raise exception 'Invalid test_attempt counter or version transition' using errcode = '23514';
    end if;
    if new.status in ('COMPLETED_PASS', 'COMPLETED_FAIL') and (
        new.answered_count <> old.answered_count or new.correct_count <> old.correct_count
    ) then
        raise exception 'Completing an attempt cannot rewrite answer counters' using errcode = '23514';
    end if;
    if new.status in ('COMPLETED_PASS', 'COMPLETED_FAIL') then
        if new.answered_count <> new.total_questions then
            raise exception 'Every pinned manifest question must be answered before completion'
                using errcode = '23514';
        end if;
        select pass_threshold into required_threshold from test_revision where id = new.test_revision_id;
        expected_completion_status := case
            when round(new.correct_count::numeric / new.total_questions::numeric, 4) >= required_threshold
                then 'COMPLETED_PASS'
            else 'COMPLETED_FAIL'
        end;
        if new.status <> expected_completion_status then
            raise exception 'Attempt completion status does not match the pinned pass threshold'
                using errcode = '23514';
        end if;
    end if;
    if new.status in ('IN_PROGRESS', 'INTERRUPTED_ENERGY')
        and new.answered_count <> old.answered_count + 1 then
        raise exception 'An answer transition must advance exactly one manifest position' using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_test_attempt_snapshot_immutable before update on test_attempt
    for each row execute function protect_attempt_snapshot();

create function validate_attempt_manifest_count() returns trigger language plpgsql as $$
declare
    target_attempt_id uuid;
    expected_count integer;
    actual_count integer;
    first_position integer;
    last_position integer;
begin
    if tg_table_name = 'test_attempt' then
        target_attempt_id := new.id;
    else
        target_attempt_id := new.attempt_id;
    end if;
    select total_questions into expected_count from test_attempt where id = target_attempt_id;
    if expected_count is null then
        return null;
    end if;
    select count(*), min(position), max(position)
      into actual_count, first_position, last_position
      from attempt_question_manifest
     where attempt_id = target_attempt_id;
    if actual_count <> expected_count or first_position <> 1 or last_position <> expected_count then
        raise exception 'Attempt manifest must contain contiguous positions 1 through %', expected_count
            using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_attempt_manifest_complete_from_attempt
    after insert on test_attempt deferrable initially deferred
    for each row execute function validate_attempt_manifest_count();
create constraint trigger tr_attempt_manifest_complete_from_manifest
    after insert on attempt_question_manifest deferrable initially deferred
    for each row execute function validate_attempt_manifest_count();

create function validate_answer_fact() returns trigger language plpgsql as $$
declare
    expected_correct boolean;
begin
    select is_correct into expected_correct
      from question_revision_option
     where question_revision_id = new.question_revision_id
       and id = new.selected_option_id;
    if expected_correct is null or new.is_correct is distinct from expected_correct then
        raise exception 'answer_submission correctness does not match the selected option'
            using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_answer_fact_correct before insert on answer_submission
    for each row execute function validate_answer_fact();

create function validate_score_fact() returns trigger language plpgsql as $$
declare
    expected_active_delta smallint;
    expected_lifetime_delta smallint;
begin
    select active_score_delta, lifetime_score_delta
      into expected_active_delta, expected_lifetime_delta
      from answer_submission
     where submission_id = new.submission_id;
    if new.active_delta is distinct from expected_active_delta
        or new.lifetime_delta is distinct from expected_lifetime_delta then
        raise exception 'score_event deltas do not match the authoritative answer fact'
            using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_score_fact_matches_answer before insert on score_event
    for each row execute function validate_score_fact();

create function validate_energy_fact() returns trigger language plpgsql as $$
declare
    answer_correct boolean;
    expected_balance smallint;
begin
    if new.event_type = 'WRONG_ANSWER_DEBIT' then
        select is_correct, energy_balance_after
          into answer_correct, expected_balance
          from answer_submission
         where submission_id = new.submission_id;
        if answer_correct is distinct from false or new.balance_after is distinct from expected_balance then
            raise exception 'Energy debit does not match the authoritative wrong-answer fact'
                using errcode = '23514';
        end if;
    end if;
    return new;
end;
$$;

create trigger tr_energy_fact_matches_answer before insert on energy_event
    for each row execute function validate_energy_fact();

create function validate_attempt_answer_counters() returns trigger language plpgsql as $$
declare
    target_attempt_id uuid;
    expected_answered integer;
    expected_correct integer;
    stored_answered integer;
    stored_correct integer;
begin
    if tg_table_name = 'test_attempt' then
        target_attempt_id := new.id;
    else
        target_attempt_id := new.attempt_id;
    end if;
    select answered_count, correct_count into stored_answered, stored_correct
      from test_attempt where id = target_attempt_id;
    select count(*), count(*) filter (where is_correct)
      into expected_answered, expected_correct
      from answer_submission where attempt_id = target_attempt_id;
    if stored_answered is distinct from expected_answered or stored_correct is distinct from expected_correct then
        raise exception 'Attempt counters do not match authoritative answer facts' using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_attempt_counters_from_attempt
    after insert or update of answered_count, correct_count on test_attempt
    deferrable initially deferred
    for each row execute function validate_attempt_answer_counters();
create constraint trigger tr_attempt_counters_from_answer
    after insert on answer_submission deferrable initially deferred
    for each row execute function validate_attempt_answer_counters();

create function validate_active_release_reference() returns trigger language plpgsql as $$
declare
    referenced_count integer;
begin
    if tg_table_name = 'course' then
        select count(*) into referenced_count
          from course_release
         where id = new.active_release_id
           and course_id = new.id
           and status = 'ACTIVE';
        if referenced_count <> 1 then
            raise exception 'course.active_release_id must reference an ACTIVE release' using errcode = '23514';
        end if;
    elsif tg_table_name = 'course_release' and new.status <> 'ACTIVE' then
        select count(*) into referenced_count
          from course
         where id = new.course_id
           and active_release_id = new.id;
        if referenced_count <> 0 then
            raise exception 'A referenced active course release cannot be retired' using errcode = '23514';
        end if;
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_active_release_valid
    after insert or update of active_release_id on course
    deferrable initially deferred
    for each row execute function validate_active_release_reference();
create constraint trigger tr_release_reference_valid
    after update of status on course_release
    deferrable initially deferred
    for each row execute function validate_active_release_reference();

create function validate_question_revision_options() returns trigger language plpgsql as $$
declare
    revision_id uuid;
    revision_status varchar(16);
    option_count integer;
    correct_count integer;
begin
    if tg_op = 'DELETE' then
        revision_id := old.question_revision_id;
    else
        revision_id := new.question_revision_id;
    end if;
    select status into revision_status from question_revision where id = revision_id;
    if revision_status = 'DRAFT' or revision_status is null then
        return null;
    end if;
    select count(*), count(*) filter (where is_correct)
      into option_count, correct_count
      from question_revision_option
     where question_revision_id = revision_id;
    if option_count <> 4 or correct_count <> 1 then
        raise exception 'Active A question revision % must have four unique-position options and exactly one correct option', revision_id
            using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_question_revision_options_valid
    after insert or update or delete on question_revision_option
    deferrable initially deferred
    for each row execute function validate_question_revision_options();
