# kelimio_api_client.model.CourseDetail

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  |
**name** | **String** |  |
**description** | **String** |  | [optional]
**targetLanguage** | **String** | Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract. |
**supportLanguages** | **Set&lt;String&gt;** |  |
**accessType** | **String** |  |
**visibility** | **String** |  |
**enrolled** | **bool** |  |
**ownerDisplayName** | **String** |  |
**releaseId** | **String** |  |
**tests** | [**List&lt;TestSummary&gt;**](TestSummary.md) |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
