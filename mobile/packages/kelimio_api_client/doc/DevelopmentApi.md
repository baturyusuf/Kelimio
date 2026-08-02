# kelimio_api_client.api.DevelopmentApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createLocalCourseRevision**](DevelopmentApi.md#createlocalcourserevision) | **POST** /v1/development/courses/{courseId}/revisions | Create one subsequent immutable course release for local verification
[**installLocalStarterCourse**](DevelopmentApi.md#installlocalstartercourse) | **POST** /v1/development/starter-course | Install the authenticated owner&#39;s local starter course idempotently


# **createLocalCourseRevision**
> SubsequentCourseDraftResult createLocalCourseRevision(courseId, idempotencyKey, createLocalCourseRevisionRequest)

Create one subsequent immutable course release for local verification

Available only in explicitly enabled local/test environments. The owner creates one real MOBILE_AUTHORING change set from the exact active release, revises one eligible typed-cloze prompt without returning authored text or answer material, and receives an unpublished immutable release. Publication and rollback still require the separate impact-bound release operations.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getDevelopmentApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final CreateLocalCourseRevisionRequest createLocalCourseRevisionRequest = ; // CreateLocalCourseRevisionRequest |

try {
    final response = api.createLocalCourseRevision(courseId, idempotencyKey, createLocalCourseRevisionRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DevelopmentApi->createLocalCourseRevision: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **createLocalCourseRevisionRequest** | [**CreateLocalCourseRevisionRequest**](CreateLocalCourseRevisionRequest.md)|  |

### Return type

[**SubsequentCourseDraftResult**](SubsequentCourseDraftResult.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **installLocalStarterCourse**
> LocalStarterCourseResponse installLocalStarterCourse(idempotencyKey)

Install the authenticated owner's local starter course idempotently

Available only when the backend is explicitly running in the local environment with starter-course installation enabled. It creates one immutable Type-A/Type-B/Type-C English-support release derived from the reviewed workbook subset and never creates users or learning results.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getDevelopmentApi();
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.

try {
    final response = api.installLocalStarterCourse(idempotencyKey);
    print(response);
} catch on DioException (e) {
    print('Exception when calling DevelopmentApi->installLocalStarterCourse: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |

### Return type

[**LocalStarterCourseResponse**](LocalStarterCourseResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
