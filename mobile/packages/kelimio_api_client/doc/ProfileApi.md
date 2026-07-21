# kelimio_api_client.api.ProfileApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getMe**](ProfileApi.md#getme) | **GET** /v1/me | Return the authenticated user&#39;s profile and language preferences


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
