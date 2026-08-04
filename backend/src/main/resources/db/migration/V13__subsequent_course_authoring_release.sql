create table test_revision_source_change_set (
    test_revision_id uuid primary key,
    test_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    created_at timestamptz not null,
    constraint fk_test_revision_source_revision foreign key (test_revision_id, test_id, course_id)
        references test_revision(id, test_id, course_id),
    constraint fk_test_revision_source_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id)
);

create table question_revision_source_change_set (
    question_revision_id uuid primary key,
    question_id uuid not null,
    course_id uuid not null,
    content_change_set_id uuid not null,
    created_at timestamptz not null,
    constraint fk_question_revision_source_revision foreign key (question_revision_id, question_id, course_id)
        references question_revision(id, question_id, course_id),
    constraint fk_question_revision_source_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id)
);

insert into test_revision_source_change_set(
    test_revision_id, test_id, course_id, content_change_set_id, created_at
)
select test_revision_id, test_id, course_id, content_change_set_id, created_at
  from test_revision_authoring;

insert into question_revision_source_change_set(
    question_revision_id, question_id, course_id, content_change_set_id, created_at
)
select question_revision_id, question_id, course_id, content_change_set_id, created_at
  from question_revision_authoring;

create trigger tr_test_revision_source_append_only
    before update or delete on test_revision_source_change_set
    for each row execute function reject_fact_mutation();

create trigger tr_question_revision_source_append_only
    before update or delete on question_revision_source_change_set
    for each row execute function reject_fact_mutation();

create function require_draft_revision_source() returns trigger language plpgsql as $$
declare
    revision_status varchar(16);
    change_set_record record;
begin
    if tg_table_name = 'test_revision_source_change_set' then
        select status into revision_status from test_revision where id = new.test_revision_id;
    else
        select status into revision_status from question_revision where id = new.question_revision_id;
    end if;
    select * into change_set_record
      from content_change_set
     where id = new.content_change_set_id and course_id = new.course_id;

    if revision_status is distinct from 'DRAFT'
        or change_set_record.id is null
        or change_set_record.status <> 'COMMITTED' then
        raise exception 'Revision source provenance requires one DRAFT revision and COMMITTED change set'
            using errcode = '23514';
    end if;
    if change_set_record.source_type = 'EXCEL_IMPORT' and exists (
        select 1 from course_import_commit where import_id = change_set_record.source_reference_id
    ) then
        raise exception 'Revision source provenance cannot change after import commit'
            using errcode = '55000';
    end if;
    if change_set_record.source_type = 'MOBILE_AUTHORING' and exists (
        select 1 from course_authoring_commit where id = change_set_record.source_reference_id
    ) then
        raise exception 'Revision source provenance cannot change after authoring commit'
            using errcode = '55000';
    end if;
    return new;
end;
$$;

create trigger tr_test_revision_source_requires_draft
    before insert on test_revision_source_change_set
    for each row execute function require_draft_revision_source();

create trigger tr_question_revision_source_requires_draft
    before insert on question_revision_source_change_set
    for each row execute function require_draft_revision_source();

create table course_authoring_commit (
    id uuid primary key,
    course_id uuid not null,
    owner_user_id uuid not null references app_user(id),
    base_release_id uuid not null,
    content_change_set_id uuid not null unique,
    draft_release_id uuid not null unique,
    changed_question_id uuid not null,
    previous_question_revision_id uuid not null,
    question_revision_id uuid not null unique,
    changed_test_id uuid not null,
    previous_test_revision_id uuid not null,
    test_revision_id uuid not null unique,
    outbox_event_id uuid not null unique references outbox_event(id),
    occurred_at timestamptz not null,
    correlation_id varchar(128) not null,
    constraint fk_authoring_commit_base_release foreign key (base_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_authoring_commit_change_set foreign key (content_change_set_id, course_id)
        references content_change_set(id, course_id),
    constraint fk_authoring_commit_draft_release foreign key (draft_release_id, course_id)
        references course_release(id, course_id),
    constraint fk_authoring_commit_previous_question foreign key (
        previous_question_revision_id, changed_question_id, course_id
    ) references question_revision(id, question_id, course_id),
    constraint fk_authoring_commit_question foreign key (
        question_revision_id, changed_question_id, course_id
    ) references question_revision(id, question_id, course_id),
    constraint fk_authoring_commit_previous_test foreign key (
        previous_test_revision_id, changed_test_id, course_id
    ) references test_revision(id, test_id, course_id),
    constraint fk_authoring_commit_test foreign key (test_revision_id, changed_test_id, course_id)
        references test_revision(id, test_id, course_id),
    constraint ck_authoring_commit_correlation check (length(btrim(correlation_id)) > 0)
);

create index ix_course_authoring_commit_course_time
    on course_authoring_commit(course_id, occurred_at, id);

create trigger tr_course_authoring_commit_append_only
    before update or delete on course_authoring_commit
    for each row execute function reject_fact_mutation();

create function validate_course_authoring_commit() returns trigger language plpgsql as $$
declare
    course_record record;
    base_record record;
    draft_record record;
    change_set_record record;
    source_record record;
    previous_question_record record;
    question_record record;
    previous_test_record record;
    test_record record;
    outbox_record record;
begin
    select * into course_record from course where id = new.course_id;
    select * into base_record from course_release where id = new.base_release_id;
    select * into draft_record from course_release where id = new.draft_release_id;
    select * into change_set_record from content_change_set where id = new.content_change_set_id;
    select * into source_record
      from course_release_source_change_set
     where course_release_id = new.draft_release_id;
    select * into previous_question_record
      from question_revision where id = new.previous_question_revision_id;
    select * into question_record from question_revision where id = new.question_revision_id;
    select * into previous_test_record from test_revision where id = new.previous_test_revision_id;
    select * into test_record from test_revision where id = new.test_revision_id;
    select * into outbox_record from outbox_event where id = new.outbox_event_id;

    if course_record.id is null
        or course_record.owner_user_id <> new.owner_user_id
        or course_record.active_release_id <> new.base_release_id
        or course_record.publication_status not in ('PUBLISHED', 'HIDDEN') then
        raise exception 'Authoring commit does not match the owned active course'
            using errcode = '23514';
    end if;
    if base_record.id is null
        or base_record.course_id <> new.course_id
        or base_record.status <> 'ACTIVE' then
        raise exception 'Authoring commit base release is not active'
            using errcode = '23514';
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
        or draft_record.created_at <> new.occurred_at then
        raise exception 'Authoring commit target is not the next immutable DRAFT release'
            using errcode = '23514';
    end if;
    if change_set_record.id is null
        or change_set_record.course_id <> new.course_id
        or change_set_record.owner_user_id <> new.owner_user_id
        or change_set_record.base_release_id <> new.base_release_id
        or change_set_record.source_type <> 'MOBILE_AUTHORING'
        or change_set_record.source_reference_id <> new.id
        or change_set_record.status <> 'COMMITTED'
        or change_set_record.created_at <> new.occurred_at
        or change_set_record.committed_at <> new.occurred_at
        or change_set_record.correlation_id <> new.correlation_id then
        raise exception 'Authoring commit change set is invalid'
            using errcode = '23514';
    end if;
    if source_record.course_release_id is null
        or source_record.course_id <> new.course_id
        or source_record.content_change_set_id <> new.content_change_set_id
        or source_record.created_at <> new.occurred_at then
        raise exception 'Authoring commit release source provenance is invalid'
            using errcode = '23514';
    end if;
    if not exists (
        select 1 from content_change_set_event
         where content_change_set_id = new.content_change_set_id
           and event_type = 'CREATED'
           and actor_user_id = new.owner_user_id
           and occurred_at = new.occurred_at
           and correlation_id = new.correlation_id
    ) or not exists (
        select 1 from content_change_set_event
         where content_change_set_id = new.content_change_set_id
           and event_type = 'COMMITTED'
           and actor_user_id = new.owner_user_id
           and occurred_at = new.occurred_at
           and correlation_id = new.correlation_id
    ) then
        raise exception 'Authoring commit requires exact change-set lifecycle events'
            using errcode = '23514';
    end if;

    if previous_question_record.id is null
        or previous_question_record.question_id <> new.changed_question_id
        or previous_question_record.course_id <> new.course_id
        or previous_question_record.status <> 'ACTIVE'
        or previous_question_record.question_type <> 'C'
        or question_record.id is null
        or question_record.question_id <> new.changed_question_id
        or question_record.course_id <> new.course_id
        or question_record.status <> 'DRAFT'
        or question_record.question_type <> 'C'
        or question_record.revision_number <> (
            select coalesce(max(candidate.revision_number), 0) + 1
              from question_revision candidate
             where candidate.question_id = new.changed_question_id
               and candidate.id <> new.question_revision_id
        )
        or question_record.prompt = previous_question_record.prompt
        or question_record.correct_answer is distinct from previous_question_record.correct_answer
        or question_record.alternative_correct_answer is distinct from previous_question_record.alternative_correct_answer
        or question_record.answer_match_policy is distinct from previous_question_record.answer_match_policy
        or question_record.answer_match_language is distinct from previous_question_record.answer_match_language
        or question_record.correct_answer_match_key is distinct from previous_question_record.correct_answer_match_key
        or question_record.alternative_answer_match_key is distinct from previous_question_record.alternative_answer_match_key
        or question_record.created_at <> new.occurred_at then
        raise exception 'Authoring commit typed-cloze revision is invalid'
            using errcode = '23514';
    end if;
    if not exists (
        select 1 from question_revision_source_change_set
         where question_revision_id = new.question_revision_id
           and question_id = new.changed_question_id
           and course_id = new.course_id
           and content_change_set_id = new.content_change_set_id
           and created_at = new.occurred_at
    ) then
        raise exception 'Authoring commit question source provenance is invalid'
            using errcode = '23514';
    end if;
    if exists (
        (select support_language, translation_text
           from question_revision_translation
          where question_revision_id = new.previous_question_revision_id
         except
         select support_language, translation_text
           from question_revision_translation
          where question_revision_id = new.question_revision_id)
        union all
        (select support_language, translation_text
           from question_revision_translation
          where question_revision_id = new.question_revision_id
         except
         select support_language, translation_text
           from question_revision_translation
          where question_revision_id = new.previous_question_revision_id)
    ) then
        raise exception 'Authoring commit changed typed-cloze translations unexpectedly'
            using errcode = '23514';
    end if;

    if previous_test_record.id is null
        or previous_test_record.test_id <> new.changed_test_id
        or previous_test_record.course_id <> new.course_id
        or previous_test_record.status <> 'ACTIVE'
        or test_record.id is null
        or test_record.test_id <> new.changed_test_id
        or test_record.course_id <> new.course_id
        or test_record.status <> 'DRAFT'
        or test_record.revision_number <> (
            select coalesce(max(candidate.revision_number), 0) + 1
              from test_revision candidate
             where candidate.test_id = new.changed_test_id
               and candidate.id <> new.test_revision_id
        )
        or test_record.title <> previous_test_record.title
        or test_record.pass_threshold <> previous_test_record.pass_threshold
        or test_record.created_at <> new.occurred_at then
        raise exception 'Authoring commit test revision is invalid'
            using errcode = '23514';
    end if;
    if not exists (
        select 1 from test_revision_source_change_set
         where test_revision_id = new.test_revision_id
           and test_id = new.changed_test_id
           and course_id = new.course_id
           and content_change_set_id = new.content_change_set_id
           and created_at = new.occurred_at
    ) then
        raise exception 'Authoring commit test source provenance is invalid'
            using errcode = '23514';
    end if;
    if not exists (
        select 1
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
         where release_test.course_release_id = new.base_release_id
           and release_test.test_revision_id = new.previous_test_revision_id
           and test_question.question_revision_id = new.previous_question_revision_id
    ) or not exists (
        select 1
          from course_release_test_revision release_test
          join test_revision_question test_question
            on test_question.test_revision_id = release_test.test_revision_id
         where release_test.course_release_id = new.draft_release_id
           and release_test.test_revision_id = new.test_revision_id
           and test_question.question_revision_id = new.question_revision_id
    ) then
        raise exception 'Authoring commit changed question is outside the replaced test'
            using errcode = '23514';
    end if;
    if exists (
        select 1
          from test_revision_question previous_question
          left join test_revision_question target_question
            on target_question.test_revision_id = new.test_revision_id
           and target_question.question_id = previous_question.question_id
         where previous_question.test_revision_id = new.previous_test_revision_id
           and (
                target_question.question_id is null
                or target_question.position <> previous_question.position
                or target_question.course_id <> previous_question.course_id
                or target_question.question_revision_id <> case
                    when previous_question.question_id = new.changed_question_id
                    then new.question_revision_id
                    else previous_question.question_revision_id
                end
           )
    ) or (
        select count(*) from test_revision_question
         where test_revision_id = new.previous_test_revision_id
    ) <> (
        select count(*) from test_revision_question
         where test_revision_id = new.test_revision_id
    ) then
        raise exception 'Authoring commit test manifest changed outside the selected question'
            using errcode = '23514';
    end if;

    if exists (
        select 1
          from course_release_test_revision previous_test
          left join course_release_test_revision target_test
            on target_test.course_release_id = new.draft_release_id
           and target_test.test_id = previous_test.test_id
         where previous_test.course_release_id = new.base_release_id
           and (
                target_test.test_id is null
                or target_test.position <> previous_test.position
                or target_test.course_id <> previous_test.course_id
                or target_test.test_revision_id <> case
                    when previous_test.test_id = new.changed_test_id
                    then new.test_revision_id
                    else previous_test.test_revision_id
                end
           )
    ) or (
        select count(*) from course_release_test_revision
         where course_release_id = new.base_release_id
    ) <> (
        select count(*) from course_release_test_revision
         where course_release_id = new.draft_release_id
    ) then
        raise exception 'Authoring commit release manifest changed outside the selected test'
            using errcode = '23514';
    end if;
    if exists (
        (select level_revision_id, level_id, course_id, position
           from course_release_level_revision where course_release_id = new.base_release_id
         except
         select level_revision_id, level_id, course_id, position
           from course_release_level_revision where course_release_id = new.draft_release_id)
        union all
        (select level_revision_id, level_id, course_id, position
           from course_release_level_revision where course_release_id = new.draft_release_id
         except
         select level_revision_id, level_id, course_id, position
           from course_release_level_revision where course_release_id = new.base_release_id)
    ) or exists (
        (select parent_level_revision_id, unit_revision_id, unit_id, course_id, position
           from course_release_unit_revision where course_release_id = new.base_release_id
         except
         select parent_level_revision_id, unit_revision_id, unit_id, course_id, position
           from course_release_unit_revision where course_release_id = new.draft_release_id)
        union all
        (select parent_level_revision_id, unit_revision_id, unit_id, course_id, position
           from course_release_unit_revision where course_release_id = new.draft_release_id
         except
         select parent_level_revision_id, unit_revision_id, unit_id, course_id, position
           from course_release_unit_revision where course_release_id = new.base_release_id)
    ) or exists (
        (select parent_unit_revision_id, topic_revision_id, topic_id, course_id, position
           from course_release_topic_revision where course_release_id = new.base_release_id
         except
         select parent_unit_revision_id, topic_revision_id, topic_id, course_id, position
           from course_release_topic_revision where course_release_id = new.draft_release_id)
        union all
        (select parent_unit_revision_id, topic_revision_id, topic_id, course_id, position
           from course_release_topic_revision where course_release_id = new.draft_release_id
         except
         select parent_unit_revision_id, topic_revision_id, topic_id, course_id, position
           from course_release_topic_revision where course_release_id = new.base_release_id)
    ) then
        raise exception 'Authoring commit changed immutable hierarchy revisions unexpectedly'
            using errcode = '23514';
    end if;
    if exists (
        select 1
          from course_release_test_hierarchy previous_hierarchy
          left join course_release_test_hierarchy target_hierarchy
            on target_hierarchy.course_release_id = new.draft_release_id
           and target_hierarchy.test_id = previous_hierarchy.test_id
         where previous_hierarchy.course_release_id = new.base_release_id
           and (
                target_hierarchy.test_id is null
                or target_hierarchy.parent_topic_revision_id <> previous_hierarchy.parent_topic_revision_id
                or target_hierarchy.position <> previous_hierarchy.position
                or target_hierarchy.course_id <> previous_hierarchy.course_id
                or target_hierarchy.test_revision_id <> case
                    when previous_hierarchy.test_id = new.changed_test_id
                    then new.test_revision_id
                    else previous_hierarchy.test_revision_id
                end
           )
    ) or (
        select count(*) from course_release_test_hierarchy
         where course_release_id = new.base_release_id
    ) <> (
        select count(*) from course_release_test_hierarchy
         where course_release_id = new.draft_release_id
    ) then
        raise exception 'Authoring commit release hierarchy changed outside the selected test'
            using errcode = '23514';
    end if;
    if (
        select coalesce(array_agg(capability order by capability), '{}'::varchar(64)[])
          from course_release_required_capability where course_release_id = new.base_release_id
    ) is distinct from (
        select coalesce(array_agg(capability order by capability), '{}'::varchar(64)[])
          from course_release_required_capability where course_release_id = new.draft_release_id
    ) then
        raise exception 'Authoring commit release capability manifest changed unexpectedly'
            using errcode = '23514';
    end if;

    if outbox_record.id is null
        or outbox_record.aggregate_type <> 'course'
        or outbox_record.aggregate_id <> new.course_id
        or outbox_record.event_type <> 'content.release-draft-created.v1'
        or outbox_record.schema_version <> 1
        or outbox_record.correlation_id <> new.correlation_id
        or outbox_record.occurred_at <> new.occurred_at
        or outbox_record.payload <> jsonb_build_object(
            'eventId', new.outbox_event_id,
            'courseId', new.course_id,
            'baseReleaseId', new.base_release_id,
            'draftReleaseId', new.draft_release_id,
            'contentChangeSetId', new.content_change_set_id,
            'changedQuestionId', new.changed_question_id,
            'previousQuestionRevisionId', new.previous_question_revision_id,
            'questionRevisionId', new.question_revision_id,
            'releaseRevision', draft_record.revision_number
        )
        or not exists (
            select 1 from outbox_delivery
             where event_id = new.outbox_event_id
               and attempt_count = 0
               and published_at is null
        ) then
        raise exception 'Authoring commit requires the exact transactional draft-created outbox fact'
            using errcode = '23514';
    end if;
    return null;
end;
$$;

create constraint trigger tr_course_authoring_commit_valid
    after insert on course_authoring_commit
    deferrable initially deferred
    for each row execute function validate_course_authoring_commit();
