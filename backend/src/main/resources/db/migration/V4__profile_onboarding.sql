alter table app_user
    add column preferred_support_language varchar(35),
    add column profile_setup_completed_at timestamptz,
    add column profile_version bigint not null default 0,
    add constraint ck_app_user_support_language_canonical check (
        preferred_support_language is null
        or preferred_support_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    ),
    add constraint ck_app_user_learning_languages_distinct check (
        preferred_support_language is null
        or active_target_language <> preferred_support_language
    ),
    add constraint ck_app_user_profile_setup_state check (
        (
            profile_setup_completed_at is null
            and preferred_support_language is null
            and profile_version = 0
        )
        or (
            profile_setup_completed_at is not null
            and preferred_support_language is not null
            and profile_version > 0
        )
    );

create table identity_profile_event (
    id uuid primary key,
    user_id uuid not null references app_user(id),
    event_type varchar(80) not null,
    profile_version bigint not null,
    changed_fields text[] not null,
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint uq_identity_profile_event_version unique (user_id, profile_version),
    constraint ck_identity_profile_event_type check (event_type in ('PROFILE_SETUP_COMPLETED')),
    constraint ck_identity_profile_event_version check (profile_version > 0),
    constraint ck_identity_profile_event_fields check (cardinality(changed_fields) > 0),
    constraint ck_identity_profile_event_correlation_not_blank check (length(btrim(correlation_id)) > 0)
);

create trigger tr_identity_profile_event_append_only before update or delete on identity_profile_event
    for each row execute function reject_fact_mutation();
