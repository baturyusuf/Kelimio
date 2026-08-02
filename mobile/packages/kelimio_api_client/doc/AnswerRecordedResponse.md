# kelimio_api_client.model.AnswerRecordedResponse

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**submissionId** | **String** |  |
**correct** | **bool** |  |
**correctOptionId** | **String** |  | [optional]
**correctAnswerText** | **String** |  | [optional]
**correctMatches** | [**List&lt;MatchingSelection&gt;**](MatchingSelection.md) |  | [optional]
**activeScoreDelta** | **int** |  |
**lifetimeScoreDelta** | **int** |  |
**activeQuestionScore** | **int** |  |
**lifetimeScore** | **int** |  |
**energy** | [**EnergyResponse**](EnergyResponse.md) |  |
**attemptState** | [**AttemptState**](AttemptState.md) |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
