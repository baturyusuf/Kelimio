create table course_origin (
    course_id uuid primary key references course(id),
    owner_user_id uuid not null references app_user(id),
    origin_type varchar(32) not null,
    origin_key varchar(160) not null,
    source_sha256 char(64) not null,
    created_at timestamptz not null,
    constraint uq_course_origin_owner_source unique (owner_user_id, origin_type, origin_key),
    constraint ck_course_origin_type check (origin_type in ('LOCAL_STARTER', 'EXCEL_IMPORT', 'MOBILE_AUTHORED')),
    constraint ck_course_origin_key_not_blank check (length(btrim(origin_key)) > 0),
    constraint ck_course_origin_sha256 check (source_sha256 ~ '^[0-9a-f]{64}$')
);

create trigger tr_course_origin_append_only before update or delete on course_origin
    for each row execute function reject_fact_mutation();
