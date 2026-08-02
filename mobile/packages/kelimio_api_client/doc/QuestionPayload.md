# kelimio_api_client.model.QuestionPayload

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**questionId** | **String** |  |
**questionRevisionId** | **String** |  |
**type** | **String** |  |
**position** | **int** |  |
**prompt** | **String** | Required question prompt value. MATCHING carries an explicit null; every other question type carries nonblank target-language text. |
**options** | [**List&lt;AnswerOption&gt;**](AnswerOption.md) |  |
**targetItems** | [**List&lt;MatchingItem&gt;**](MatchingItem.md) |  |
**supportItems** | [**List&lt;MatchingItem&gt;**](MatchingItem.md) |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
