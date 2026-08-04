# kelimio_api_client.model.MeResponse

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **String** |  |
**displayName** | **String** |  |
**appLocale** | **String** | Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract. |
**activeTargetLanguage** | **String** | Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract. |
**preferredSupportLanguage** | **String** | Absent or null until first-login profile setup is complete. | [optional]
**timeZone** | **String** | Named IANA time-zone identifier accepted by the backend runtime, or UTC. Raw numeric offsets and GMT-prefixed fixed offsets are rejected. |
**profileVersion** | **int** |  |
**profileSetupStatus** | **String** | REQUIRED pairs with profileVersion 0 and no support language; COMPLETE pairs with profileVersion at least 1 and a support language. |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
