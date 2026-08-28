# kelimio_api_client.api.EnrollmentApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**acceptCourseInvitation**](EnrollmentApi.md#acceptcourseinvitation) | **POST** /v1/course-invitations/{token}/accept | Accept an opaque invitation and create active course access
[**enrollInCourse**](EnrollmentApi.md#enrollincourse) | **POST** /v1/courses/{courseId}/enrollments | Enroll the authenticated user in a free public course


# **acceptCourseInvitation**
> CourseInvitationAccepted acceptCourseInvitation(token, acceptCourseInvitationRequest)

Accept an opaque invitation and create active course access

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getEnrollmentApi();
final String token = token_example; // String |
final AcceptCourseInvitationRequest acceptCourseInvitationRequest = ; // AcceptCourseInvitationRequest |

try {
    final response = api.acceptCourseInvitation(token, acceptCourseInvitationRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling EnrollmentApi->acceptCourseInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **token** | **String**|  |
 **acceptCourseInvitationRequest** | [**AcceptCourseInvitationRequest**](AcceptCourseInvitationRequest.md)|  |

### Return type

[**CourseInvitationAccepted**](CourseInvitationAccepted.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **enrollInCourse**
> EnrollmentResponse enrollInCourse(courseId, idempotencyKey, createEnrollmentRequest, xKelimioClientCapabilities)

Enroll the authenticated user in a free public course

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getEnrollmentApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final CreateEnrollmentRequest createEnrollmentRequest = ; // CreateEnrollmentRequest |
final String xKelimioClientCapabilities = xKelimioClientCapabilities_example; // String | Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.

try {
    final response = api.enrollInCourse(courseId, idempotencyKey, createEnrollmentRequest, xKelimioClientCapabilities);
    print(response);
} catch on DioException (e) {
    print('Exception when calling EnrollmentApi->enrollInCourse: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **createEnrollmentRequest** | [**CreateEnrollmentRequest**](CreateEnrollmentRequest.md)|  |
 **xKelimioClientCapabilities** | **String**| Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization. | [optional]

### Return type

[**EnrollmentResponse**](EnrollmentResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
