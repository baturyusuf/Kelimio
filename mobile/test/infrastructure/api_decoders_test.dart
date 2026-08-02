import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
import 'package:kelimio_mobile/infrastructure/repositories/api_decoders.dart';

void main() {
  test('maps all supported question types without exposing answer data', () {
    final session = mapAttempt(
      _attempt([
        _question(
          type: api.QuestionPayloadTypeEnum.WORD_MULTIPLE_CHOICE,
          prompt: 'Window',
          position: 1,
        ),
        _question(
          type: api.QuestionPayloadTypeEnum.MULTIPLE_CHOICE_CLOZE,
          prompt: 'They --- every morning.',
          position: 2,
        ),
        _question(
          type: api.QuestionPayloadTypeEnum.TYPED_CLOZE,
          prompt: 'We --- every evening.',
          position: 3,
        ),
      ]),
    );

    expect(session.questions.map((question) => question.type), [
      QuestionType.wordMultipleChoice,
      QuestionType.multipleChoiceCloze,
      QuestionType.typedCloze,
    ]);
    expect(session.questions.last.options, isEmpty);
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

  test('typed cloze with options fails closed', () {
    expect(
      () => mapAttempt(
        _attempt([
          api.QuestionPayload(
            questionId: '00000000-0000-4000-8000-000000000101',
            questionRevisionId: '00000000-0000-4000-8000-000000000201',
            type: api.QuestionPayloadTypeEnum.TYPED_CLOZE,
            position: 1,
            prompt: 'They --- every morning.',
            options: _options,
          ),
        ]),
      ),
      throwsA(isA<ProtocolFailure>()),
    );
  });

  test('maps mutually-exclusive option and typed feedback branches', () {
    final option = mapAnswerFeedback(_feedback(correctOptionId: 'option'));
    final typed = mapAnswerFeedback(_feedback(correctAnswerText: 'answer'));

    expect(option.correctOptionId, 'option');
    expect(option.correctAnswerText, isNull);
    expect(typed.correctOptionId, isNull);
    expect(typed.correctAnswerText, 'answer');
  });

  test('feedback with both or neither answer branch fails closed', () {
    expect(
      () => mapAnswerFeedback(_feedback()),
      throwsA(isA<ProtocolFailure>()),
    );
    expect(
      () => mapAnswerFeedback(
        _feedback(correctOptionId: 'option', correctAnswerText: 'answer'),
      ),
      throwsA(isA<ProtocolFailure>()),
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
  options: type == api.QuestionPayloadTypeEnum.TYPED_CLOZE
      ? const []
      : _options,
);

api.AnswerRecordedResponse _feedback({
  String? correctOptionId,
  String? correctAnswerText,
}) => api.AnswerRecordedResponse(
  submissionId: '00000000-0000-4000-8000-000000000005',
  correct: true,
  correctOptionId: correctOptionId,
  correctAnswerText: correctAnswerText,
  activeScoreDelta: 60,
  lifetimeScoreDelta: 60,
  activeQuestionScore: 60,
  lifetimeScore: 60,
  energy: api.EnergyResponse(
    balance: 5,
    maximum: api.EnergyResponseMaximumEnum.number5,
    unlimited: false,
    asOf: DateTime.utc(2026),
  ),
  attemptState: api.AttemptState.IN_PROGRESS,
);

final _options = List.generate(
  4,
  (index) => api.AnswerOption(
    id: '00000000-0000-4000-8000-00000000003${index + 1}',
    text: 'option ${index + 1}',
  ),
);
