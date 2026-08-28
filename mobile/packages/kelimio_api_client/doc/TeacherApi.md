# kelimio_api_client.api.TeacherApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**acceptTeacherTerms**](TeacherApi.md#acceptteacherterms) | **POST** /v1/teacher/access/terms-acceptance | Accept the exact current version of the production authoring terms
[**createCourseInvitation**](TeacherApi.md#createcourseinvitation) | **POST** /v1/teacher/courses/{courseId}/invitations | Create an expiring private free-course invitation
[**createFullCourseEditorDraft**](TeacherApi.md#createfullcourseeditordraft) | **POST** /v1/teacher/courses/{courseId}/editor/drafts | Save an ETag-bound complete immutable course draft
[**getFullCourseEditor**](TeacherApi.md#getfullcourseeditor) | **GET** /v1/teacher/courses/{courseId}/editor | Read the active immutable release as a full owner-scoped editor document
[**getTeacherAccess**](TeacherApi.md#getteacheraccess) | **GET** /v1/teacher/access | Return the authenticated user&#39;s production teacher access state
[**listTeacherCourses**](TeacherApi.md#listteachercourses) | **GET** /v1/teacher/courses | List courses owned by the authenticated authorized teacher


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

# **createCourseInvitation**
> CourseInvitationCreated createCourseInvitation(courseId, createCourseInvitationRequest)

Create an expiring private free-course invitation

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getTeacherApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final CreateCourseInvitationRequest createCourseInvitationRequest = ; // CreateCourseInvitationRequest |

try {
    final response = api.createCourseInvitation(courseId, createCourseInvitationRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling TeacherApi->createCourseInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **createCourseInvitationRequest** | [**CreateCourseInvitationRequest**](CreateCourseInvitationRequest.md)|  |

### Return type

[**CourseInvitationCreated**](CourseInvitationCreated.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createFullCourseEditorDraft**
> FullCourseEditorDraftResponse createFullCourseEditorDraft(courseId, idempotencyKey, ifMatch, saveFullCourseEditorDraftRequest)

Save an ETag-bound complete immutable course draft

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getTeacherApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final String ifMatch = ifMatch_example; // String | Strong ETag returned by the current owner-scoped editor document.
final SaveFullCourseEditorDraftRequest saveFullCourseEditorDraftRequest = ; // SaveFullCourseEditorDraftRequest |

try {
    final response = api.createFullCourseEditorDraft(courseId, idempotencyKey, ifMatch, saveFullCourseEditorDraftRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling TeacherApi->createFullCourseEditorDraft: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **ifMatch** | **String**| Strong ETag returned by the current owner-scoped editor document. |
 **saveFullCourseEditorDraftRequest** | [**SaveFullCourseEditorDraftRequest**](SaveFullCourseEditorDraftRequest.md)|  |

### Return type

[**FullCourseEditorDraftResponse**](FullCourseEditorDraftResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getFullCourseEditor**
> FullCourseEditorDocument getFullCourseEditor(courseId)

Read the active immutable release as a full owner-scoped editor document

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getTeacherApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.getFullCourseEditor(courseId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling TeacherApi->getFullCourseEditor: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |

### Return type

[**FullCourseEditorDocument**](FullCourseEditorDocument.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
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

# **listTeacherCourses**
> TeacherCoursePage listTeacherCourses(cursor, limit)

List courses owned by the authenticated authorized teacher

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getTeacherApi();
final String cursor = cursor_example; // String | Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates.
final int limit = 56; // int |

try {
    final response = api.listTeacherCourses(cursor, limit);
    print(response);
} catch on DioException (e) {
    print('Exception when calling TeacherApi->listTeacherCourses: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **cursor** | **String**| Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates. | [optional]
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**TeacherCoursePage**](TeacherCoursePage.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
