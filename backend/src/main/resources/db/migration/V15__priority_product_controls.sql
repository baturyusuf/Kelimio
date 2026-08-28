create table notification_preference (
    user_id uuid primary key references app_user(id),
    learning_reminders boolean not null default true,
    course_updates boolean not null default true,
    product_announcements boolean not null default false,
    push_enabled boolean not null default false,
    email_enabled boolean not null default false,
    quiet_hours_start time,
    quiet_hours_end time,
    version bigint not null default 1,
    updated_at timestamptz not null,
    constraint ck_notification_quiet_hours_pair check (
        (quiet_hours_start is null) = (quiet_hours_end is null)
    ),
    constraint ck_notification_version check (version > 0)
);

create table notification_preference_event (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    version bigint not null,
    changed_fields jsonb not null,
    correlation_id varchar(160) not null,
    occurred_at timestamptz not null,
    constraint uq_notification_preference_event_version unique (user_id, version),
    constraint ck_notification_changed_fields_array check (jsonb_typeof(changed_fields) = 'array')
);

create table account_deletion_request (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    status varchar(24) not null,
    requested_at timestamptz not null,
    scheduled_for timestamptz not null,
    cancelled_at timestamptz,
    completed_at timestamptz,
    correlation_id varchar(160) not null,
    constraint ck_account_deletion_status check (status in ('PENDING', 'CANCELLED', 'COMPLETED')),
    constraint ck_account_deletion_schedule check (scheduled_for >= requested_at)
);

create unique index uq_account_deletion_pending_user
    on account_deletion_request(user_id) where status = 'PENDING';

create table legal_consent_fact (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    document_id varchar(80) not null,
    document_version varchar(80) not null,
    action varchar(16) not null,
    occurred_at timestamptz not null,
    correlation_id varchar(160) not null,
    constraint ck_legal_consent_action check (action in ('ACCEPTED', 'WITHDRAWN')),
    constraint ck_legal_consent_document check (
        length(btrim(document_id)) > 0 and length(btrim(document_version)) > 0
    )
);

create index ix_legal_consent_user_document
    on legal_consent_fact(user_id, document_id, occurred_at desc);

create table course_invitation (
    id uuid primary key,
    course_id uuid not null references course(id),
    created_by_user_id uuid not null references app_user(id),
    token_sha256 char(64) not null unique,
    max_uses integer not null default 1,
    used_count integer not null default 0,
    expires_at timestamptz not null,
    revoked_at timestamptz,
    created_at timestamptz not null,
    constraint ck_course_invitation_uses check (max_uses > 0 and used_count between 0 and max_uses),
    constraint ck_course_invitation_expiry check (expires_at > created_at),
    constraint ck_course_invitation_hash check (token_sha256 ~ '^[0-9a-f]{64}$')
);

create table course_invitation_acceptance (
    invitation_id uuid not null references course_invitation(id),
    user_id uuid not null references app_user(id),
    enrollment_id uuid not null references enrollment(id),
    accepted_at timestamptz not null,
    correlation_id varchar(160) not null,
    primary key (invitation_id, user_id),
    unique (enrollment_id)
);

create index ix_course_invitation_course on course_invitation(course_id, created_at desc);
