# kelimio_api_client.api.TeacherApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**acceptTeacherTerms**](TeacherApi.md#acceptteacherterms) | **POST** /v1/teacher/access/terms-acceptance | Accept the exact current version of the production authoring terms
[**getTeacherAccess**](TeacherApi.md#getteacheraccess) | **GET** /v1/teacher/access | Return the authenticated user&#39;s production teacher access state


# **acceptTeacherTerms**
> TeacherAccessResponse acceptTeacherTerms(acceptTeacherTermsRequest)

Accept the exact current version of the production authoring terms

Appends one auditable owner-scoped acceptance fact. The account must be eligible through the managed identity group and production teacher features must already be enabled.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getTeacherApi();
final AcceptTeacherTermsRequest acceptTeacherTermsRequest = ; // AcceptTeacherTermsRequest |

try {
    final response = api.acceptTeacherTerms(acceptTeacherTermsRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling TeacherApi->acceptTeacherTerms: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **acceptTeacherTermsRequest** | [**AcceptTeacherTermsRequest**](AcceptTeacherTermsRequest.md)|  |

### Return type

[**TeacherAccessResponse**](TeacherAccessResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTeacherAccess**
> TeacherAccessResponse getTeacherAccess()

Return the authenticated user's production teacher access state

Reports server-authoritative feature enablement, Cognito group eligibility, and current versioned terms acceptance. A client flag never grants access.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getTeacherApi();

try {
    final response = api.getTeacherAccess();
    print(response);
} catch on DioException (e) {
    print('Exception when calling TeacherApi->getTeacherAccess: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**TeacherAccessResponse**](TeacherAccessResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
