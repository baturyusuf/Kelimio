# kelimio_api_client.api.AccountApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cancelAccountDeletion**](AccountApi.md#cancelaccountdeletion) | **POST** /v1/me/deletion-requests/{requestId}/cancel | Cancel a pending deletion request during its recovery window
[**exportOwnAccount**](AccountApi.md#exportownaccount) | **GET** /v1/me/export | Export the authenticated user&#39;s portable account and learning facts
[**getNotificationPreferences**](AccountApi.md#getnotificationpreferences) | **GET** /v1/me/notification-preferences | Read notification choices and real provider availability
[**listAccountDeletionRequests**](AccountApi.md#listaccountdeletionrequests) | **GET** /v1/me/deletion-requests | List the current user&#39;s recent deletion requests
[**listLegalConsents**](AccountApi.md#listlegalconsents) | **GET** /v1/me/legal-consents | List append-only legal-consent facts recorded for the current user
[**requestAccountDeletion**](AccountApi.md#requestaccountdeletion) | **POST** /v1/me/deletion-requests | Request audited account deletion after a seven-day recovery window
[**revokeAllSessions**](AccountApi.md#revokeallsessions) | **POST** /v1/me/session-revocations | Revoke all Cognito refresh sessions for the authenticated identity
[**updateNotificationPreferences**](AccountApi.md#updatenotificationpreferences) | **PUT** /v1/me/notification-preferences | Optimistically update notification preferences


# **cancelAccountDeletion**
> AccountDeletionRequest cancelAccountDeletion(requestId, idempotencyKey)

Cancel a pending deletion request during its recovery window

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();
final String requestId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.

try {
    final response = api.cancelAccountDeletion(requestId, idempotencyKey);
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->cancelAccountDeletion: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **requestId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |

### Return type

[**AccountDeletionRequest**](AccountDeletionRequest.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **exportOwnAccount**
> AccountExport exportOwnAccount()

Export the authenticated user's portable account and learning facts

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();

try {
    final response = api.exportOwnAccount();
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->exportOwnAccount: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AccountExport**](AccountExport.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getNotificationPreferences**
> NotificationPreference getNotificationPreferences()

Read notification choices and real provider availability

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();

try {
    final response = api.getNotificationPreferences();
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->getNotificationPreferences: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**NotificationPreference**](NotificationPreference.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listAccountDeletionRequests**
> List<AccountDeletionRequest> listAccountDeletionRequests()

List the current user's recent deletion requests

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();

try {
    final response = api.listAccountDeletionRequests();
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->listAccountDeletionRequests: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List&lt;AccountDeletionRequest&gt;**](AccountDeletionRequest.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listLegalConsents**
> List<LegalConsent> listLegalConsents()

List append-only legal-consent facts recorded for the current user

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();

try {
    final response = api.listLegalConsents();
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->listLegalConsents: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List&lt;LegalConsent&gt;**](LegalConsent.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestAccountDeletion**
> AccountDeletionRequest requestAccountDeletion(idempotencyKey)

Request audited account deletion after a seven-day recovery window

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.

try {
    final response = api.requestAccountDeletion(idempotencyKey);
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->requestAccountDeletion: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |

### Return type

[**AccountDeletionRequest**](AccountDeletionRequest.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revokeAllSessions**
> SessionRevocation revokeAllSessions()

Revoke all Cognito refresh sessions for the authenticated identity

Calls Cognito AdminUserGlobalSignOut using the server-authenticated username, then appends an audit/outbox event. The current access token may remain valid until its short expiry and the client must clear its local session.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();

try {
    final response = api.revokeAllSessions();
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->revokeAllSessions: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SessionRevocation**](SessionRevocation.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateNotificationPreferences**
> NotificationPreference updateNotificationPreferences(updateNotificationPreferenceRequest)

Optimistically update notification preferences

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getAccountApi();
final UpdateNotificationPreferenceRequest updateNotificationPreferenceRequest = ; // UpdateNotificationPreferenceRequest |

try {
    final response = api.updateNotificationPreferences(updateNotificationPreferenceRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling AccountApi->updateNotificationPreferences: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **updateNotificationPreferenceRequest** | [**UpdateNotificationPreferenceRequest**](UpdateNotificationPreferenceRequest.md)|  |

### Return type

[**NotificationPreference**](NotificationPreference.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
