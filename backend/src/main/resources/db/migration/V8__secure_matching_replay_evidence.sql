do $$
begin
    if exists (select 1 from answer_submission where answer_kind = 'MATCHING') then
        raise exception 'V8 cannot convert existing matching answer facts to keyed replay evidence'
            using errcode = '55000';
    end if;
end;
$$;

alter table answer_submission
    drop constraint ck_answer_evidence_shape;

alter table answer_submission
    add column matching_replay_key_version varchar(32),
    drop column matching_correct_pair_count;

alter table answer_submission
    add constraint ck_answer_evidence_shape check (
        (
            answer_kind = 'OPTION'
            and selected_option_id is not null
            and typed_answer_salt is null
            and typed_answer_digest is null
            and typed_match_ordinal is null
            and matching_answer_salt is null
            and matching_answer_digest is null
            and matching_replay_key_version is null
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
            and matching_replay_key_version is null
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
            and matching_replay_key_version is not null
            and matching_replay_key_version ~ '^[a-z0-9][a-z0-9._-]{0,31}$'
        )
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
        if new.answer_kind <> 'MATCHING' or authored_pair_count not between 2 and 6 then
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
