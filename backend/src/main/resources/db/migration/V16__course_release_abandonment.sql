alter table course_release drop constraint ck_course_release_status;
alter table course_release
    add constraint ck_course_release_status
    check (status in ('DRAFT', 'ACTIVE', 'RETIRED', 'ABANDONED'));

create table course_release_abandonment (
    id uuid primary key,
    course_id uuid not null references course(id),
    course_release_id uuid not null,
    actor_user_id uuid not null references app_user(id),
    outbox_event_id uuid not null unique references outbox_event(id),
    abandoned_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint fk_release_abandonment_release foreign key (course_release_id, course_id)
        references course_release(id, course_id),
    constraint uq_release_abandonment_release unique (course_release_id)
);

create trigger tr_course_release_abandonment_append_only
    before update or delete on course_release_abandonment
    for each row execute function reject_fact_mutation();
