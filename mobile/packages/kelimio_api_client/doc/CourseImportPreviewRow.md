# kelimio_api_client.model.CourseImportPreviewRow

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**ordinal** | **int** |  |
**questionOrdinal** | **int** |  |
**projectedQuestionType** | **String** |  |
**compositionKind** | **String** |  |
**groupPosition** | **int** |  |
**source_** | [**CourseImportSource**](CourseImportSource.md) |  |
**level** | **String** |  |
**unit** | **String** |  |
**topic** | **String** |  |
**testNumber** | **int** |  |
**allocationKind** | **String** |  |
**allocationReason** | **String** |  |
**resolvedMode** | **String** |  |
**recordType** | **String** |  |
**targetText** | **String** |  |
**translations** | **Map&lt;String, String&gt;** | Required non-empty language map for WORD rows; intentionally empty for MULTIPLE_CHOICE_CLOZE and TYPED_CLOZE rows under xlsx-v1. |
**sentence** | **String** |  |
**correctAnswer** | **String** |  |
**alternativeCorrectAnswer** | **String** |  |
**wrongAnswers** | **List&lt;String&gt;** |  |
**matchingGroup** | **String** |  |
**hidden** | **bool** |  |
**note** | **String** |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
