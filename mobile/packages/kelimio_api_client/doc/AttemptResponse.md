# kelimio_api_client.model.AttemptResponse

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  |
**testId** | **String** |  |
**testRevisionId** | **String** |  |
**supportLanguage** | **String** | Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract. |
**state** | [**AttemptState**](AttemptState.md) |  |
**questions** | [**List&lt;QuestionPayload&gt;**](QuestionPayload.md) |  |
**startedAt** | [**DateTime**](DateTime.md) |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
