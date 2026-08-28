# kelimio_api_client.model.FullCourseEditorDocument

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**courseId** | **String** |  |
**activeReleaseId** | **String** |  |
**releaseRevision** | **int** |  |
**name** | **String** |  |
**description** | **String** |  | [optional]
**visibility** | **String** |  |
**targetLanguage** | **String** | Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract. |
**defaultSupportLanguage** | **String** | Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract. |
**supportLanguages** | **Set&lt;String&gt;** |  |
**levels** | [**List&lt;CourseEditorLevel&gt;**](CourseEditorLevel.md) |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
