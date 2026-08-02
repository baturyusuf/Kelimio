# kelimio_api_client.model.CourseImportUploadInstructions

## Load the model package
```dart
import 'package:kelimio_api_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**expiresAt** | [**DateTime**](DateTime.md) | Earliest exact expiry among the signed part-upload URLs in this response; no URL in the response remains valid after this instant. This can be earlier than the import session's uploadExpiresAt value. |
**parts** | [**List&lt;CourseImportPresignedPart&gt;**](CourseImportPresignedPart.md) |  |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)
