# kelimio_api_client.api.LearningApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**finishAttempt**](LearningApi.md#finishattempt) | **POST** /v1/attempts/{attemptId}/finish | Finish an attempt after all planned questions are answered
[**getCourseProgress**](LearningApi.md#getcourseprogress) | **GET** /v1/courses/{courseId}/progress | Return the authenticated learner&#39;s rebuildable course progress projection
[**startAttempt**](LearningApi.md#startattempt) | **POST** /v1/tests/{testId}/attempts | Start an online attempt for the current test revision
[**submitAnswer**](LearningApi.md#submitanswer) | **POST** /v1/attempts/{attemptId}/answers | Record and evaluate one online answer exactly once


# **finishAttempt**
> FinishAttemptResponse finishAttempt(attemptId, idempotencyKey)

Finish an attempt after all planned questions are answered

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getLearningApi();
final String attemptId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.

try {
    final response = api.finishAttempt(attemptId, idempotencyKey);
    print(response);
} catch on DioException (e) {
    print('Exception when calling LearningApi->finishAttempt: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **attemptId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |

### Return type

[**FinishAttemptResponse**](FinishAttemptResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCourseProgress**
> CourseProgressResponse getCourseProgress(courseId)

Return the authenticated learner's rebuildable course progress projection

Counts and scores are projected only from server-authoritative PostgreSQL facts. When updating is true, the last completed projection is returned while unresolved outbox facts remain, including a delivery awaiting operational replay after exhausting worker retries. Clients must use bounded polling and expose a retry state instead of an endless spinner.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getLearningApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.getCourseProgress(courseId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling LearningApi->getCourseProgress: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |

### Return type

[**CourseProgressResponse**](CourseProgressResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **startAttempt**
> AttemptResponse startAttempt(testId, idempotencyKey)

Start an online attempt for the current test revision

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getLearningApi();
final String testId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.

try {
    final response = api.startAttempt(testId, idempotencyKey);
    print(response);
} catch on DioException (e) {
    print('Exception when calling LearningApi->startAttempt: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **testId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |

### Return type

[**AttemptResponse**](AttemptResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **submitAnswer**
> AnswerRecordedResponse submitAnswer(attemptId, idempotencyKey, submitAnswerRequest)

Record and evaluate one online answer exactly once

Reusing submissionId returns the previously committed response and never creates a second attempt fact, score event, energy event, or outbox event.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getLearningApi();
final String attemptId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final SubmitAnswerRequest submitAnswerRequest = ; // SubmitAnswerRequest |

try {
    final response = api.submitAnswer(attemptId, idempotencyKey, submitAnswerRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling LearningApi->submitAnswer: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **attemptId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **submitAnswerRequest** | [**SubmitAnswerRequest**](SubmitAnswerRequest.md)|  |

### Return type

[**AnswerRecordedResponse**](AnswerRecordedResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
