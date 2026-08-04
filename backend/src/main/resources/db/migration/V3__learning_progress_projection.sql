create table outbox_consumer_delivery (
    event_id uuid not null references outbox_event(id),
    consumer_name varchar(120) not null,
    status varchar(16) not null,
    attempt_count integer not null default 0,
    processed_at timestamptz,
    last_error_type varchar(500),
    primary key (event_id, consumer_name),
    constraint ck_outbox_consumer_name_not_blank check (length(btrim(consumer_name)) > 0),
    constraint ck_outbox_consumer_status check (status in ('PENDING', 'PROCESSING', 'FAILED', 'PROCESSED', 'DEAD')),
    constraint ck_outbox_consumer_attempt_count check (attempt_count >= 0),
    constraint ck_outbox_consumer_processed_state check (
        (status = 'PROCESSED' and processed_at is not null)
        or (status <> 'PROCESSED' and processed_at is null)
    )
);

create index ix_outbox_consumer_retry
    on outbox_consumer_delivery(consumer_name, status, attempt_count);

create table learner_course_progress_projection (
    user_id uuid not null references app_user(id),
    course_id uuid not null references course(id),
    answered_questions integer not null,
    correct_answers integer not null,
    completed_attempts integer not null,
    passed_attempts integer not null,
    active_score bigint not null,
    lifetime_score bigint not null,
    projection_version bigint not null,
    last_event_id uuid not null references outbox_event(id),
    updated_at timestamptz not null,
    primary key (user_id, course_id),
    constraint ck_progress_answered_nonnegative check (answered_questions >= 0),
    constraint ck_progress_correct_range check (correct_answers between 0 and answered_questions),
    constraint ck_progress_completed_nonnegative check (completed_attempts >= 0),
    constraint ck_progress_passed_range check (passed_attempts between 0 and completed_attempts),
    constraint ck_progress_active_score_nonnegative check (active_score >= 0),
    constraint ck_progress_lifetime_score_nonnegative check (lifetime_score >= 0),
    constraint ck_progress_version_positive check (projection_version > 0)
);
