alter table question_revision
    alter column prompt drop not null,
    alter column correct_answer drop not null,
    add column matching_policy varchar(32),
    add column matching_label_policy varchar(32),
    add column matching_order_policy varchar(32),
    add column matching_target_language varchar(35);

alter table question_revision
    drop constraint ck_question_revision_type,
    drop constraint ck_question_revision_prompt_not_blank,
    drop constraint ck_question_revision_answer_not_blank,
    drop constraint ck_question_revision_cloze_prompt,
    drop constraint ck_question_revision_typed_answer_shape;

alter table question_revision
    add constraint ck_question_revision_type
        check (question_type in ('A', 'B', 'C', 'D')),
    add constraint ck_question_revision_prompt_shape
        check (
            (question_type in ('A', 'B', 'C') and prompt is not null and length(btrim(prompt)) > 0)
            or (question_type = 'D' and prompt is null)
        ),
    add constraint ck_question_revision_answer_shape
        check (
            (question_type in ('A', 'B', 'C') and correct_answer is not null and length(btrim(correct_answer)) > 0)
            or (question_type = 'D' and correct_answer is null)
        ),
    add constraint ck_question_revision_cloze_prompt
        check (
            question_type not in ('B', 'C')
            or (
                position('---' in prompt) > 0
                and position(
                    '---' in substring(prompt from position('---' in prompt) + 1)
                ) = 0
            )
        ),
    add constraint ck_question_revision_answer_material_shape
        check (
            (
                question_type in ('A', 'B')
                and alternative_correct_answer is null
                and answer_match_policy is null
                and answer_match_language is null
                and correct_answer_match_key is null
                and alternative_answer_match_key is null
                and matching_policy is null
                and matching_label_policy is null
                and matching_order_policy is null
                and matching_target_language is null
            )
            or (
                question_type = 'C'
                and answer_match_policy = 'typed-answer-v1'
                and answer_match_language is not null
                and answer_match_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
                and correct_answer_match_key is not null
                and length(btrim(correct_answer_match_key)) > 0
                and (
                    (alternative_correct_answer is null and alternative_answer_match_key is null)
                    or (
                        alternative_correct_answer is not null
                        and alternative_answer_match_key is not null
                        and length(btrim(alternative_correct_answer)) > 0
                        and length(btrim(alternative_answer_match_key)) > 0
                        and alternative_answer_match_key <> correct_answer_match_key
                    )
                )
                and matching_policy is null
                and matching_label_policy is null
                and matching_order_policy is null
                and matching_target_language is null
            )
            or (
                question_type = 'D'
                and alternative_correct_answer is null
                and answer_match_policy is null
                and answer_match_language is null
                and correct_answer_match_key is null
                and alternative_answer_match_key is null
                and matching_policy = 'matching-v1'
                and matching_label_policy = 'matching-label-v1'
                and matching_order_policy = 'matching-order-v1'
                and matching_target_language is not null
                and matching_target_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
            )
        );

create table question_revision_matching_pair (
    target_item_id uuid primary key,
    question_revision_id uuid not null,
    course_id uuid not null,
    position smallint not null,
    target_text varchar(500) not null,
    target_label_key varchar(2000) not null,
    constraint fk_matching_pair_revision foreign key (question_revision_id, course_id)
        references question_revision(id, course_id),
    constraint uq_matching_pair_revision_identity unique (question_revision_id, target_item_id, course_id),
    constraint uq_matching_pair_position unique (question_revision_id, position),
    constraint uq_matching_pair_target_label unique (question_revision_id, target_label_key),
    constraint ck_matching_pair_target_uuid_v4 check (
        target_item_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    ),
    constraint ck_matching_pair_position check (position between 1 and 6),
    constraint ck_matching_pair_target_text check (length(btrim(target_text)) > 0),
    constraint ck_matching_pair_target_label check (length(btrim(target_label_key)) > 0)
);

create table question_revision_matching_translation (
    support_item_id uuid primary key,
    question_revision_id uuid not null,
    course_id uuid not null,
    target_item_id uuid not null,
    support_language varchar(35) not null,
    support_text varchar(500) not null,
    support_label_key varchar(2000) not null,
    constraint fk_matching_translation_pair foreign key (
        question_revision_id, target_item_id, course_id
    ) references question_revision_matching_pair(
        question_revision_id, target_item_id, course_id
    ),
    constraint fk_matching_translation_language foreign key (course_id, support_language)
        references course_support_language(course_id, language_code),
    constraint uq_matching_translation_pair_language unique (
        question_revision_id, target_item_id, support_language
    ),
    constraint uq_matching_translation_support_label unique (
        question_revision_id, support_language, support_label_key
    ),
    constraint ck_matching_translation_support_uuid_v4 check (
        support_item_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    ),
    constraint ck_matching_translation_distinct_item_ids check (support_item_id <> target_item_id),
    constraint ck_matching_translation_language_canonical check (
        support_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    ),
    constraint ck_matching_translation_support_text check (length(btrim(support_text)) > 0),
    constraint ck_matching_translation_support_label check (length(btrim(support_label_key)) > 0)
);

create trigger tr_matching_pair_append_only
    before update or delete on question_revision_matching_pair
    for each row execute function reject_fact_mutation();
create trigger tr_matching_translation_append_only
    before update or delete on question_revision_matching_translation
    for each row execute function reject_fact_mutation();

-- PostgreSQL acquires the row being updated before a row-level trigger runs.
-- Serialize the small set of matching-structure statements before any such row
-- lock is taken; their row triggers/validators can then lock course followed by
-- revision rows without a language-add/activation race or lock-order cycle.
create function serialize_matching_structure_change() returns trigger language plpgsql as $$
begin
    perform pg_advisory_xact_lock(451239807123456789);
    return null;
end;
$$;

create trigger tr_matching_serialize_revision_status
    before update of status on question_revision
    for each statement execute function serialize_matching_structure_change();
create trigger tr_matching_serialize_pair_insert
    before insert on question_revision_matching_pair
    for each statement execute function serialize_matching_structure_change();
create trigger tr_matching_serialize_translation_insert
    before insert on question_revision_matching_translation
    for each statement execute function serialize_matching_structure_change();
create trigger tr_matching_serialize_support_language
    before insert or update or delete on course_support_language
    for each statement execute function serialize_matching_structure_change();
create trigger tr_matching_serialize_course_activation
    before update of publication_status, target_language on course
    for each statement execute function serialize_matching_structure_change();
create trigger tr_matching_serialize_release_activation
    before update of status on course_release
    for each statement execute function serialize_matching_structure_change();

create function require_matching_draft_parent() returns trigger language plpgsql as $$
declare
    parent_status varchar(16);
    parent_type varchar(8);
    parent_course_id uuid;
    public_item_id uuid;
begin
    perform 1
      from course
     where id = new.course_id
     for update;

    select status, question_type, course_id
      into parent_status, parent_type, parent_course_id
      from question_revision
     where id = new.question_revision_id
     for update;

    if parent_status is null
        or parent_type <> 'D'
        or parent_course_id is distinct from new.course_id then
        raise exception 'Matching content must reference a Type-D revision in the same course'
            using errcode = '23514';
    end if;
    if parent_status <> 'DRAFT' then
        raise exception 'Cannot add matching content to a non-draft question revision'
            using errcode = '55000';
    end if;

    if tg_table_name = 'question_revision_matching_pair' then
        public_item_id := new.target_item_id;
    else
        public_item_id := new.support_item_id;
    end if;
    perform pg_advisory_xact_lock(hashtextextended('matching-public-item:' || public_item_id::text, 0));

    if tg_table_name = 'question_revision_matching_pair' then
        if exists (
            select 1
              from question_revision_matching_translation
             where support_item_id = new.target_item_id
        ) then
            raise exception 'Target and support item identities must be globally disjoint'
                using errcode = '23514';
        end if;
    elsif exists (
        select 1
          from question_revision_matching_pair
         where target_item_id = new.support_item_id
    ) then
        raise exception 'Target and support item identities must be globally disjoint'
            using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_matching_pair_requires_draft
    before insert on question_revision_matching_pair
    for each row execute function require_matching_draft_parent();
create trigger tr_matching_translation_requires_draft
    before insert on question_revision_matching_translation
    for each row execute function require_matching_draft_parent();

create function assert_matching_revision_complete(
    target_revision_id uuid,
    validate_draft boolean
) returns void language plpgsql as $$
declare
    revision_status varchar(16);
    revision_type varchar(8);
    revision_course_id uuid;
    revision_target_language varchar(35);
    course_target_language varchar(35);
    pair_count integer;
    first_position integer;
    last_position integer;
    option_count integer;
    support_language_count integer;
    translation_count integer;
    missing_translation_count integer;
begin
    select status, question_type, course_id, matching_target_language
      into revision_status, revision_type, revision_course_id, revision_target_language
      from question_revision
     where id = target_revision_id;

    if revision_type is distinct from 'D'
        or (revision_status <> 'ACTIVE' and not validate_draft) then
        return;
    end if;

    select target_language into course_target_language
      from course
     where id = revision_course_id;
    if revision_target_language is distinct from course_target_language then
        raise exception 'Matching target language must equal the course target language'
            using errcode = '23514';
    end if;

    select count(*) into option_count
      from question_revision_option
     where question_revision_id = target_revision_id;
    if option_count <> 0 then
        raise exception 'An active matching question revision cannot contain options'
            using errcode = '23514';
    end if;

    select count(*), min(position), max(position)
      into pair_count, first_position, last_position
      from question_revision_matching_pair
     where question_revision_id = target_revision_id;
    if pair_count not between 2 and 6
        or first_position <> 1
        or last_position <> pair_count then
        raise exception 'An active matching revision requires two through six contiguous pairs'
            using errcode = '23514';
    end if;

    select count(*) into support_language_count
      from course_support_language
     where course_id = revision_course_id;
    if support_language_count = 0 then
        raise exception 'An active matching revision requires a declared support language'
            using errcode = '23514';
    end if;

    select count(*) into translation_count
      from question_revision_matching_translation
     where question_revision_id = target_revision_id;
    select count(*) into missing_translation_count
      from question_revision_matching_pair pair
      cross join course_support_language language
     where pair.question_revision_id = target_revision_id
       and language.course_id = revision_course_id
       and not exists (
            select 1
              from question_revision_matching_translation translation
             where translation.question_revision_id = pair.question_revision_id
               and translation.target_item_id = pair.target_item_id
               and translation.support_language = language.language_code
       );
    if translation_count <> pair_count * support_language_count
        or missing_translation_count <> 0 then
        raise exception 'An active matching revision requires one translation per pair and support language'
            using errcode = '23514';
    end if;
end;
$$;

create or replace function require_draft_parent_for_content() returns trigger language plpgsql as $$
declare
    parent_status varchar(16);
    parent_question_type varchar(8);
begin
    if tg_table_name = 'course_release_test_revision' then
        select status into parent_status from course_release where id = new.course_release_id;
    elsif tg_table_name = 'test_revision_question' then
        select status into parent_status from test_revision where id = new.test_revision_id;
    elsif tg_table_name = 'question_revision_option' then
        select status, question_type
          into parent_status, parent_question_type
          from question_revision
         where id = new.question_revision_id;
    end if;
    if parent_status is distinct from 'DRAFT' then
        raise exception 'Cannot add content to non-draft parent for %', tg_table_name using errcode = '55000';
    end if;
    if tg_table_name = 'question_revision_option' and parent_question_type in ('C', 'D') then
        raise exception 'This question revision type cannot contain options' using errcode = '23514';
    end if;
    return new;
end;
$$;

create or replace function require_draft_course_for_support_language() returns trigger language plpgsql as $$
declare
    target_course_id uuid;
    parent_status varchar(24);
    locked_course record;
begin
    if tg_op = 'UPDATE' then
        for locked_course in
            select id, publication_status
              from course
             where id in (old.course_id, new.course_id)
             order by id
             for update
        loop
            if locked_course.publication_status is distinct from 'DRAFT' then
                raise exception 'Course support languages are frozen after publication'
                    using errcode = '55000';
            end if;
        end loop;
        perform id
          from question_revision
         where question_type = 'D'
           and course_id in (old.course_id, new.course_id)
         order by course_id, id
         for update;
        return new;
    end if;

    if tg_op = 'DELETE' then
        target_course_id := old.course_id;
    else
        target_course_id := new.course_id;
    end if;
    select publication_status into parent_status
      from course
     where id = target_course_id
     for update;
    if parent_status is distinct from 'DRAFT' then
        raise exception 'Course support languages are frozen after publication' using errcode = '55000';
    end if;
    perform id
      from question_revision
     where question_type = 'D'
       and course_id = target_course_id
     order by id
     for update;
    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

create or replace function reject_revision_content_mutation() returns trigger language plpgsql as $$
declare
    child_count integer;
    inactive_child_count integer;
    correct_count integer;
    referenced_count integer;
    course_target_language varchar(35);
begin
    if new.status = 'DRAFT' and old.status <> 'DRAFT' then
        raise exception '% cannot return to DRAFT', tg_table_name using errcode = '55000';
    end if;
    if tg_table_name = 'course_release' then
        if new.id is distinct from old.id
            or new.course_id is distinct from old.course_id
            or new.revision_number is distinct from old.revision_number
            or new.created_at is distinct from old.created_at then
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
        if new.id is distinct from old.id
            or new.question_id is distinct from old.question_id
            or new.course_id is distinct from old.course_id
            or new.revision_number is distinct from old.revision_number
            or new.question_type is distinct from old.question_type
            or new.prompt is distinct from old.prompt
            or new.correct_answer is distinct from old.correct_answer
            or new.alternative_correct_answer is distinct from old.alternative_correct_answer
            or new.answer_match_policy is distinct from old.answer_match_policy
            or new.answer_match_language is distinct from old.answer_match_language
            or new.correct_answer_match_key is distinct from old.correct_answer_match_key
            or new.alternative_answer_match_key is distinct from old.alternative_answer_match_key
            or new.matching_policy is distinct from old.matching_policy
            or new.matching_label_policy is distinct from old.matching_label_policy
            or new.matching_order_policy is distinct from old.matching_order_policy
            or new.matching_target_language is distinct from old.matching_target_language
            or new.created_at is distinct from old.created_at then
            raise exception 'question_revision content is immutable' using errcode = '55000';
        end if;
        if new.status = 'ACTIVE' and old.status <> 'ACTIVE' then
            select count(*), count(*) filter (where is_correct)
              into child_count, correct_count
              from question_revision_option
             where question_revision_id = new.id;
            if new.question_type in ('A', 'B') and (child_count <> 4 or correct_count <> 1) then
                raise exception 'An active multiple-choice question revision must have four options and one correct option'
                    using errcode = '23514';
            end if;
            if new.question_type in ('C', 'D') and child_count <> 0 then
                raise exception 'This active question revision type cannot contain options'
                    using errcode = '23514';
            end if;
            if new.question_type = 'C' then
                select target_language into course_target_language from course where id = new.course_id;
                if new.answer_match_language is distinct from course_target_language then
                    raise exception 'Typed-cloze answer language must match the course target language'
                        using errcode = '23514';
                end if;
            elsif new.question_type = 'D' then
                perform 1 from course where id = new.course_id for update;
                perform assert_matching_revision_complete(new.id, true);
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
        if new.id is distinct from old.id
            or new.test_id is distinct from old.test_id
            or new.course_id is distinct from old.course_id
            or new.revision_number is distinct from old.revision_number
            or new.title is distinct from old.title
            or new.pass_threshold is distinct from old.pass_threshold
            or new.created_at is distinct from old.created_at then
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

create function validate_matching_revision_trigger() returns trigger language plpgsql as $$
declare
    target_revision_id uuid;
begin
    if tg_table_name = 'question_revision' then
        target_revision_id := new.id;
    else
        target_revision_id := new.question_revision_id;
    end if;
    perform assert_matching_revision_complete(target_revision_id, false);
    return null;
end;
$$;

create constraint trigger tr_matching_revision_complete_from_revision
    after update on question_revision deferrable initially deferred
    for each row execute function validate_matching_revision_trigger();
create constraint trigger tr_matching_revision_complete_from_pair
    after insert on question_revision_matching_pair deferrable initially deferred
    for each row execute function validate_matching_revision_trigger();
create constraint trigger tr_matching_revision_complete_from_translation
    after insert on question_revision_matching_translation deferrable initially deferred
    for each row execute function validate_matching_revision_trigger();

create function validate_matching_course_trigger() returns trigger language plpgsql as $$
declare
    target_course_id uuid;
    revision record;
begin
    if tg_table_name = 'course_support_language' and tg_op = 'UPDATE' then
        perform id
          from course
         where id in (old.course_id, new.course_id)
         order by id
         for update;
        for revision in
            select id
              from question_revision
             where course_id in (old.course_id, new.course_id)
               and question_type = 'D'
             order by course_id, id
             for update
        loop
            perform assert_matching_revision_complete(revision.id, false);
        end loop;
        return null;
    end if;

    if tg_table_name = 'course' then
        target_course_id := new.id;
    elsif tg_table_name = 'course_release' then
        target_course_id := new.course_id;
    elsif tg_op = 'DELETE' then
        target_course_id := old.course_id;
    else
        target_course_id := new.course_id;
    end if;
    perform 1 from course where id = target_course_id for update;
    for revision in
        select id
          from question_revision
         where course_id = target_course_id
           and question_type = 'D'
         order by id
         for update
    loop
        perform assert_matching_revision_complete(revision.id, false);
    end loop;
    return null;
end;
$$;

create constraint trigger tr_matching_course_complete_from_language
    after insert or update or delete on course_support_language deferrable initially deferred
    for each row execute function validate_matching_course_trigger();
create constraint trigger tr_matching_course_complete_from_course
    after update on course deferrable initially deferred
    for each row execute function validate_matching_course_trigger();
create constraint trigger tr_matching_course_complete_from_release
    after update on course_release deferrable initially deferred
    for each row execute function validate_matching_course_trigger();

alter table test_attempt add column support_language varchar(35);

-- The V7 backfill changes only the newly introduced snapshot field. The V1
-- snapshot trigger quite correctly rejects ordinary no-version-bump updates,
-- so suspend it only for this migration-owned, transactional rewrite.
alter table test_attempt disable trigger tr_test_attempt_snapshot_immutable;

-- Keep the precondition check and rewrite on one stable enrollment image.
-- SHARE conflicts with enrollment INSERT/UPDATE/DELETE while allowing reads.
lock table enrollment in share mode;

do $$
begin
    if exists (
        select 1
          from test_attempt attempt
          left join enrollment owning
            on owning.course_id = attempt.course_id
           and owning.user_id = attempt.user_id
         group by attempt.id
        having count(owning.id) <> 1
    ) then
        raise exception 'V7 cannot pin support language: every existing attempt requires exactly one owning enrollment'
            using errcode = '23514';
    end if;
end;
$$;

update test_attempt attempt
   set support_language = owning.support_language
  from enrollment owning
 where owning.course_id = attempt.course_id
   and owning.user_id = attempt.user_id;

alter table test_attempt enable trigger tr_test_attempt_snapshot_immutable;

alter table test_attempt
    alter column support_language set not null,
    add constraint fk_test_attempt_enrollment foreign key (course_id, user_id)
        references enrollment(course_id, user_id),
    add constraint fk_test_attempt_support_language foreign key (course_id, support_language)
        references course_support_language(course_id, language_code),
    add constraint ck_test_attempt_support_language_canonical check (
        support_language ~ '^[a-z]{2,8}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?(-([a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$'
    );

create function require_active_enrollment_language_for_attempt() returns trigger language plpgsql as $$
declare
    enrollment_language varchar(35);
    enrollment_status varchar(16);
begin
    select support_language, status
      into enrollment_language, enrollment_status
      from enrollment
     where course_id = new.course_id
       and user_id = new.user_id
     for share;
    if enrollment_status is distinct from 'ACTIVE'
        or new.support_language is distinct from enrollment_language then
        raise exception 'Attempt support language must be pinned from the active enrollment'
            using errcode = '23514';
    end if;
    return new;
end;
$$;

create trigger tr_test_attempt_pins_active_enrollment_language
    before insert on test_attempt
    for each row execute function require_active_enrollment_language_for_attempt();

create or replace function protect_attempt_snapshot() returns trigger language plpgsql as $$
declare
    required_threshold numeric(5,4);
    expected_completion_status varchar(32);
begin
    if new.id is distinct from old.id
        or new.user_id is distinct from old.user_id
        or new.course_id is distinct from old.course_id
        or new.course_release_id is distinct from old.course_release_id
        or new.course_access_type is distinct from old.course_access_type
        or new.test_revision_id is distinct from old.test_revision_id
        or new.support_language is distinct from old.support_language
        or new.shuffle_seed is distinct from old.shuffle_seed
        or new.total_questions is distinct from old.total_questions
        or new.started_at is distinct from old.started_at then
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

alter table answer_submission
    add column matching_answer_salt bytea,
    add column matching_answer_digest bytea,
    add column matching_correct_pair_count smallint,
    drop constraint ck_answer_kind,
    drop constraint ck_answer_evidence_shape,
    drop constraint ck_answer_typed_correctness;

alter table answer_submission
    add constraint ck_answer_kind check (answer_kind in ('OPTION', 'TYPED_TEXT', 'MATCHING')),
    add constraint ck_answer_evidence_shape check (
        (
            answer_kind = 'OPTION'
            and selected_option_id is not null
            and typed_answer_salt is null
            and typed_answer_digest is null
            and typed_match_ordinal is null
            and matching_answer_salt is null
            and matching_answer_digest is null
            and matching_correct_pair_count is null
        )
        or (
            answer_kind = 'TYPED_TEXT'
            and selected_option_id is null
            and typed_answer_salt is not null
            and octet_length(typed_answer_salt) = 16
            and typed_answer_digest is not null
            and octet_length(typed_answer_digest) = 32
            and typed_match_ordinal is not null
            and typed_match_ordinal between 0 and 2
            and matching_answer_salt is null
            and matching_answer_digest is null
            and matching_correct_pair_count is null
        )
        or (
            answer_kind = 'MATCHING'
            and selected_option_id is null
            and typed_answer_salt is null
            and typed_answer_digest is null
            and typed_match_ordinal is null
            and matching_answer_salt is not null
            and octet_length(matching_answer_salt) = 16
            and matching_answer_digest is not null
            and octet_length(matching_answer_digest) = 32
            and matching_correct_pair_count is not null
            and matching_correct_pair_count between 0 and 6
        )
    ),
    add constraint ck_answer_typed_correctness check (
        answer_kind <> 'TYPED_TEXT'
        or is_correct = (typed_match_ordinal in (1, 2))
    );

create or replace function validate_answer_fact() returns trigger language plpgsql as $$
declare
    stored_question_type varchar(8);
    expected_correct boolean;
    has_alternative boolean;
    authored_pair_count integer;
begin
    select question_type, alternative_correct_answer is not null
      into stored_question_type, has_alternative
      from question_revision
     where id = new.question_revision_id;

    if stored_question_type in ('A', 'B') then
        if new.answer_kind <> 'OPTION' then
            raise exception 'answer_submission kind does not match the question revision'
                using errcode = '23514';
        end if;
        select is_correct into expected_correct
          from question_revision_option
         where question_revision_id = new.question_revision_id
           and id = new.selected_option_id;
        if expected_correct is null or new.is_correct is distinct from expected_correct then
            raise exception 'answer_submission correctness does not match the selected option'
                using errcode = '23514';
        end if;
    elsif stored_question_type = 'C' then
        if new.answer_kind <> 'TYPED_TEXT'
            or new.is_correct is distinct from (new.typed_match_ordinal in (1, 2))
            or (new.typed_match_ordinal = 2 and not has_alternative) then
            raise exception 'answer_submission typed evidence does not match the question revision'
                using errcode = '23514';
        end if;
    elsif stored_question_type = 'D' then
        select count(*) into authored_pair_count
          from question_revision_matching_pair
         where question_revision_id = new.question_revision_id;
        if new.answer_kind <> 'MATCHING'
            or authored_pair_count not between 2 and 6
            or new.matching_correct_pair_count not between 0 and authored_pair_count
            or new.is_correct is distinct from (new.matching_correct_pair_count = authored_pair_count) then
            raise exception 'answer_submission matching evidence does not match the question revision'
                using errcode = '23514';
        end if;
    else
        raise exception 'answer_submission references an unsupported question revision'
            using errcode = '23514';
    end if;
    return new;
end;
$$;
