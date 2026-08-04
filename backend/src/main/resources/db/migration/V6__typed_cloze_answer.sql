alter table question_revision
    add column alternative_correct_answer varchar(500),
    add column answer_match_policy varchar(32),
    add column answer_match_language varchar(35),
    add column correct_answer_match_key varchar(2000),
    add column alternative_answer_match_key varchar(2000);

alter table question_revision
    drop constraint ck_question_revision_type,
    drop constraint ck_question_revision_multiple_choice_cloze_prompt;

alter table question_revision
    add constraint ck_question_revision_type
        check (question_type in ('A', 'B', 'C')),
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
    add constraint ck_question_revision_typed_answer_shape
        check (
            (
                question_type in ('A', 'B')
                and alternative_correct_answer is null
                and answer_match_policy is null
                and answer_match_language is null
                and correct_answer_match_key is null
                and alternative_answer_match_key is null
            )
            or (
                question_type = 'C'
                and answer_match_policy is not null
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
            )
        );

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
    if tg_table_name = 'question_revision_option' and parent_question_type = 'C' then
        raise exception 'Typed cloze question revisions cannot contain options' using errcode = '23514';
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
            or new.alternative_correct_answer is distinct from old.alternative_correct_answer
            or new.answer_match_policy is distinct from old.answer_match_policy
            or new.answer_match_language is distinct from old.answer_match_language
            or new.correct_answer_match_key is distinct from old.correct_answer_match_key
            or new.alternative_answer_match_key is distinct from old.alternative_answer_match_key
            or new.created_at <> old.created_at then
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
            if new.question_type = 'C' and child_count <> 0 then
                raise exception 'An active typed-cloze question revision cannot contain options'
                    using errcode = '23514';
            end if;
            if new.question_type = 'C' then
                select target_language into course_target_language from course where id = new.course_id;
                if new.answer_match_language is distinct from course_target_language then
                    raise exception 'Typed-cloze answer language must match the course target language'
                        using errcode = '23514';
                end if;
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

alter table answer_submission
    alter column selected_option_id drop not null,
    add column answer_kind varchar(16) not null default 'OPTION',
    add column typed_answer_salt bytea,
    add column typed_answer_digest bytea,
    add column typed_match_ordinal smallint,
    add constraint ck_answer_kind check (answer_kind in ('OPTION', 'TYPED_TEXT')),
    add constraint ck_answer_evidence_shape check (
        (
            answer_kind = 'OPTION'
            and selected_option_id is not null
            and typed_answer_salt is null
            and typed_answer_digest is null
            and typed_match_ordinal is null
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
    else
        raise exception 'answer_submission references an unsupported question revision'
            using errcode = '23514';
    end if;
    return new;
end;
$$;
