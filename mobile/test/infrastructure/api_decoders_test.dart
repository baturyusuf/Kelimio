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
        _question(
          type: api.QuestionPayloadTypeEnum.MATCHING,
          prompt: null,
          position: 4,
          targetItems: _targetItems(),
          supportItems: _supportItems(),
        ),
      ]),
    );

    expect(session.questions.map((question) => question.type), [
      QuestionType.wordMultipleChoice,
      QuestionType.multipleChoiceCloze,
      QuestionType.typedCloze,
      QuestionType.matching,
    ]);
    expect(session.supportLanguage, 'en');
    expect(session.questions[2].options, isEmpty);
    expect(session.questions.last.targetItems, hasLength(2));
    expect(session.questions.last.supportItems, hasLength(2));
  });

  test('non-canonical attempt support language fails closed', () {
    expect(
      () => mapAttempt(_attempt([], supportLanguage: 'EN')),
      throwsA(isA<ProtocolFailure>()),
    );
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
            targetItems: const [],
            supportItems: const [],
          ),
        ]),
      ),
      throwsA(isA<ProtocolFailure>()),
    );
  });

  test('matching question shape and side identifiers fail closed', () {
    expect(
      () => mapAttempt(
        _attempt([
          _question(
            type: api.QuestionPayloadTypeEnum.MATCHING,
            prompt: null,
            position: 1,
            targetItems: _targetItems(),
            supportItems: [
              api.MatchingItem(id: _targetOneId, text: 'apple'),
              api.MatchingItem(id: _supportTwoId, text: 'pear'),
            ],
          ),
        ]),
      ),
      throwsA(isA<ProtocolFailure>()),
    );
  });

  test('maps all mutually-exclusive authoritative feedback branches', () {
    final option = mapAnswerFeedback(_feedback(correctOptionId: 'option'));
    final typed = mapAnswerFeedback(_feedback(correctAnswerText: 'answer'));
    final matching = mapAnswerFeedback(
      _feedback(correctMatches: _correctMatches()),
    );

    expect(option.correctOptionId, 'option');
    expect(option.correctAnswerText, isNull);
    expect(typed.correctOptionId, isNull);
    expect(typed.correctAnswerText, 'answer');
    expect(matching.correctMatches, hasLength(2));
    expect(matching.correctOptionId, isNull);
    expect(matching.correctAnswerText, isNull);
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
    expect(
      () => mapAnswerFeedback(
        _feedback(correctOptionId: 'option', correctMatches: _correctMatches()),
      ),
      throwsA(isA<ProtocolFailure>()),
    );
  });

  test('malformed authoritative matching coverage fails closed', () {
    expect(
      () => mapAnswerFeedback(
        _feedback(
          correctMatches: [
            api.MatchingSelection(
              targetItemId: _targetOneId,
              supportItemId: _supportOneId,
            ),
            api.MatchingSelection(
              targetItemId: _targetTwoId,
              supportItemId: _supportOneId,
            ),
          ],
        ),
      ),
      throwsA(isA<ProtocolFailure>()),
    );
  });
}

api.AttemptResponse _attempt(
  List<api.QuestionPayload> questions, {
  String supportLanguage = 'en',
}) => api.AttemptResponse(
  id: '00000000-0000-4000-8000-000000000001',
  testId: '00000000-0000-4000-8000-000000000002',
  testRevisionId: '00000000-0000-4000-8000-000000000003',
  supportLanguage: supportLanguage,
  state: api.AttemptState.IN_PROGRESS,
  questions: questions,
  startedAt: DateTime.utc(2026),
);

api.QuestionPayload _question({
  required api.QuestionPayloadTypeEnum type,
  required String? prompt,
  required int position,
  List<api.MatchingItem> targetItems = const [],
  List<api.MatchingItem> supportItems = const [],
}) => api.QuestionPayload(
  questionId: '00000000-0000-4000-8000-00000000010$position',
  questionRevisionId: '00000000-0000-4000-8000-00000000020$position',
  type: type,
  position: position,
  prompt: prompt,
  options:
      type == api.QuestionPayloadTypeEnum.TYPED_CLOZE ||
          type == api.QuestionPayloadTypeEnum.MATCHING
      ? const []
      : _options,
  targetItems: targetItems,
  supportItems: supportItems,
);

api.AnswerRecordedResponse _feedback({
  String? correctOptionId,
  String? correctAnswerText,
  List<api.MatchingSelection>? correctMatches,
}) => api.AnswerRecordedResponse(
  submissionId: '00000000-0000-4000-8000-000000000005',
  correct: true,
  correctOptionId: correctOptionId,
  correctAnswerText: correctAnswerText,
  correctMatches: correctMatches,
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

List<api.MatchingItem> _targetItems() => [
  api.MatchingItem(id: _targetOneId, text: 'elma'),
  api.MatchingItem(id: _targetTwoId, text: 'armut'),
];

List<api.MatchingItem> _supportItems() => [
  api.MatchingItem(id: _supportOneId, text: 'apple'),
  api.MatchingItem(id: _supportTwoId, text: 'pear'),
];

List<api.MatchingSelection> _correctMatches() => [
  api.MatchingSelection(
    targetItemId: _targetOneId,
    supportItemId: _supportOneId,
  ),
  api.MatchingSelection(
    targetItemId: _targetTwoId,
    supportItemId: _supportTwoId,
  ),
];

const _targetOneId = '7c3fb0e8-0fb2-4b4e-8d41-f6bf5ebec2a9';
const _targetTwoId = '294d18f5-1115-499d-a51a-a97635004e91';
const _supportOneId = 'dca8ed80-fcab-42a1-acd8-ff69cda41534';
const _supportTwoId = '5e83bf52-1ed2-41ef-ae24-09f704621f16';
