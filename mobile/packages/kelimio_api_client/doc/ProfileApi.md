# kelimio_api_client.api.ProfileApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**completeProfileSetup**](ProfileApi.md#completeprofilesetup) | **POST** /v1/me/profile-setup | Complete the authenticated user&#39;s first-login profile setup
[**getMe**](ProfileApi.md#getme) | **GET** /v1/me | Return the authenticated user&#39;s profile and language preferences


# **completeProfileSetup**
> MeResponse completeProfileSetup(idempotencyKey, profileSetupRequest)

Complete the authenticated user's first-login profile setup

Completes the provisional subject-bound profile exactly once. Repeating the same Idempotency-Key and canonical request returns the original result without duplicate facts. This is not legal-terms acceptance, and identity-provider subject, email, and username are neither accepted by this command nor exposed by the profile response.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getProfileApi();
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final ProfileSetupRequest profileSetupRequest = ; // ProfileSetupRequest |

try {
    final response = api.completeProfileSetup(idempotencyKey, profileSetupRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling ProfileApi->completeProfileSetup: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **profileSetupRequest** | [**ProfileSetupRequest**](ProfileSetupRequest.md)|  |

### Return type

[**MeResponse**](MeResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getMe**
> MeResponse getMe()

Return the authenticated user's profile and language preferences

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getProfileApi();

try {
    final response = api.getMe();
    print(response);
} catch on DioException (e) {
    print('Exception when calling ProfileApi->getMe: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**MeResponse**](MeResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
