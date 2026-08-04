alter table question_revision
    drop constraint ck_question_revision_type;

alter table question_revision
    add constraint ck_question_revision_type
        check (question_type in ('A', 'B')),
    add constraint ck_question_revision_multiple_choice_cloze_prompt
        check (
            question_type <> 'B'
            or (
                position('---' in prompt) > 0
                and position(
                    '---' in substring(prompt from position('---' in prompt) + 1)
                ) = 0
            )
        );
