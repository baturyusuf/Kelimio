# kelimio_api_client.api.CourseReleaseApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**activateCourseRelease**](CourseReleaseApi.md#activatecourserelease) | **POST** /v1/courses/{courseId}/releases/{releaseId}/activate | Publish or roll back to an exact reviewed immutable release
[**getCourseReleaseImpact**](CourseReleaseApi.md#getcoursereleaseimpact) | **GET** /v1/courses/{courseId}/releases/{releaseId}/impact | Review the exact owner-scoped impact of activating an immutable release


# **activateCourseRelease**
> CourseReleaseActivationResponse activateCourseRelease(courseId, releaseId, idempotencyKey, activateCourseReleaseRequest)

Publish or roll back to an exact reviewed immutable release

Atomically activates the reviewed release, appends the activation and outbox facts, and creates a cutoff-bound progress reprojection job. In production this endpoint additionally requires the server-side teacher feature gate, Cognito teacher-group eligibility, and current versioned authoring-terms acceptance.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseReleaseApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String releaseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final ActivateCourseReleaseRequest activateCourseReleaseRequest = ; // ActivateCourseReleaseRequest |

try {
    final response = api.activateCourseRelease(courseId, releaseId, idempotencyKey, activateCourseReleaseRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseReleaseApi->activateCourseRelease: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **releaseId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **activateCourseReleaseRequest** | [**ActivateCourseReleaseRequest**](ActivateCourseReleaseRequest.md)|  |

### Return type

[**CourseReleaseActivationResponse**](CourseReleaseActivationResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCourseReleaseImpact**
> CourseReleaseImpactResponse getCourseReleaseImpact(courseId, releaseId)

Review the exact owner-scoped impact of activating an immutable release

Returns a canonical binding digest over the locked release manifests and current active release. The enrollment count is advisory and deliberately excluded from the binding because projection membership is cutoff-bound at activation.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseReleaseApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String releaseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.getCourseReleaseImpact(courseId, releaseId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseReleaseApi->getCourseReleaseImpact: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **releaseId** | **String**|  |

### Return type

[**CourseReleaseImpactResponse**](CourseReleaseImpactResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
