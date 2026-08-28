# kelimio_api_client.api.SocialApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getGlobalLeaderboard**](SocialApi.md#getgloballeaderboard) | **GET** /v1/leaderboards/global | List only users who explicitly opted in to public ranking
[**getOwnPublicProfile**](SocialApi.md#getownpublicprofile) | **GET** /v1/me/public-profile | Read private settings and public-profile projection for the current user
[**getPublicProfile**](SocialApi.md#getpublicprofile) | **GET** /v1/profiles/{username} | Read an explicitly enabled public profile
[**updateOwnPublicProfile**](SocialApi.md#updateownpublicprofile) | **PUT** /v1/me/public-profile | Update public-profile fields and explicit visibility choices


# **getGlobalLeaderboard**
> Leaderboard getGlobalLeaderboard(limit)

List only users who explicitly opted in to public ranking

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getSocialApi();
final int limit = 56; // int |

try {
    final response = api.getGlobalLeaderboard(limit);
    print(response);
} catch on DioException (e) {
    print('Exception when calling SocialApi->getGlobalLeaderboard: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**Leaderboard**](Leaderboard.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getOwnPublicProfile**
> OwnPublicProfile getOwnPublicProfile()

Read private settings and public-profile projection for the current user

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getSocialApi();

try {
    final response = api.getOwnPublicProfile();
    print(response);
} catch on DioException (e) {
    print('Exception when calling SocialApi->getOwnPublicProfile: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**OwnPublicProfile**](OwnPublicProfile.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getPublicProfile**
> PublicProfile getPublicProfile(username)

Read an explicitly enabled public profile

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getSocialApi();
final String username = username_example; // String |

try {
    final response = api.getPublicProfile(username);
    print(response);
} catch on DioException (e) {
    print('Exception when calling SocialApi->getPublicProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **username** | **String**|  |

### Return type

[**PublicProfile**](PublicProfile.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateOwnPublicProfile**
> OwnPublicProfile updateOwnPublicProfile(updatePublicProfileRequest)

Update public-profile fields and explicit visibility choices

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getSocialApi();
final UpdatePublicProfileRequest updatePublicProfileRequest = ; // UpdatePublicProfileRequest |

try {
    final response = api.updateOwnPublicProfile(updatePublicProfileRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling SocialApi->updateOwnPublicProfile: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **updatePublicProfileRequest** | [**UpdatePublicProfileRequest**](UpdatePublicProfileRequest.md)|  |

### Return type

[**OwnPublicProfile**](OwnPublicProfile.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
