import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
import 'package:kelimio_mobile/infrastructure/repositories/api_decoders.dart';

void main() {
  test('maps both supported question types without exposing answer data', () {
    final session = mapAttempt(
      _attempt([
        _question(
          type: api.QuestionPayloadTypeEnum.WORD_MULTIPLE_CHOICE,
          prompt: 'Pencere',
          position: 1,
        ),
        _question(
          type: api.QuestionPayloadTypeEnum.MULTIPLE_CHOICE_CLOZE,
          prompt: 'Ben her sabah çay ---.',
          position: 2,
        ),
      ]),
    );

    expect(session.questions.map((question) => question.type), [
      QuestionType.wordMultipleChoice,
      QuestionType.multipleChoiceCloze,
    ]);
  });

  test('invalid cloze payload fails closed with a content-free error', () {
    expect(
      () => mapAttempt(
        _attempt([
          _question(
            type: api.QuestionPayloadTypeEnum.MULTIPLE_CHOICE_CLOZE,
            prompt: 'private course text without a marker',
            position: 1,
          ),
        ]),
      ),
      throwsA(
        isA<ProtocolFailure>().having(
          (failure) => failure.message,
          'message',
          'Invalid question payload',
        ),
      ),
    );
  });
}

api.AttemptResponse _attempt(List<api.QuestionPayload> questions) =>
    api.AttemptResponse(
      id: '00000000-0000-4000-8000-000000000001',
      testId: '00000000-0000-4000-8000-000000000002',
      testRevisionId: '00000000-0000-4000-8000-000000000003',
      state: api.AttemptState.IN_PROGRESS,
      questions: questions,
      startedAt: DateTime.utc(2026),
    );

api.QuestionPayload _question({
  required api.QuestionPayloadTypeEnum type,
  required String prompt,
  required int position,
}) => api.QuestionPayload(
  questionId: '00000000-0000-4000-8000-00000000010$position',
  questionRevisionId: '00000000-0000-4000-8000-00000000020$position',
  type: type,
  position: position,
  prompt: prompt,
  options: List.generate(
    4,
    (index) => api.AnswerOption(
      id: '00000000-0000-4000-8000-00000000003${index + 1}',
      text: 'option ${index + 1}',
    ),
  ),
);
