# kelimio_api_client.api.CourseImportApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**approveCourseImport**](CourseImportApi.md#approvecourseimport) | **POST** /v1/courses/imports/{importId}/approve | Approve one exact immutable preview and provenance tuple
[**completeCourseImportUpload**](CourseImportApi.md#completecourseimportupload) | **POST** /v1/courses/imports/{importId}/complete | Complete the exact multipart object and queue isolated processing
[**createCourseImport**](CourseImportApi.md#createcourseimport) | **POST** /v1/courses/imports | Create an owner-scoped resumable XLSX upload session
[**getCourseImport**](CourseImportApi.md#getcourseimport) | **GET** /v1/courses/imports/{importId} | Return the current owner-scoped import state
[**listCourseImportPreviewRows**](CourseImportApi.md#listcourseimportpreviewrows) | **GET** /v1/courses/imports/{importId}/preview | Page through the immutable normalized owner preview
[**listCourseImportValidationIssues**](CourseImportApi.md#listcourseimportvalidationissues) | **GET** /v1/courses/imports/{importId}/issues | Page through the immutable owner-scoped validation report


# **approveCourseImport**
> CourseImportApprovalResponse approveCourseImport(importId, idempotencyKey, approveCourseImportRequest)

Approve one exact immutable preview and provenance tuple

Appends owner approval only when the supplied binding digest matches the current PREVIEW_READY fact. Approval creates no course, revision, release, entitlement, or publication side effect. The JSON approval command is rejected before parsing when it exceeds 8192 bytes.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseImportApi();
final String importId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final ApproveCourseImportRequest approveCourseImportRequest = ; // ApproveCourseImportRequest |

try {
    final response = api.approveCourseImport(importId, idempotencyKey, approveCourseImportRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseImportApi->approveCourseImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **approveCourseImportRequest** | [**ApproveCourseImportRequest**](ApproveCourseImportRequest.md)|  |

### Return type

[**CourseImportApprovalResponse**](CourseImportApprovalResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **completeCourseImportUpload**
> CourseImportStatusResponse completeCourseImportUpload(importId, idempotencyKey, completeCourseImportUploadRequest)

Complete the exact multipart object and queue isolated processing

Completes only the server-created multipart upload with its exact consecutive part list. A successful command records one non-null S3 VersionId and transactional outbox event. It does not claim that the workbook is clean, valid, archived, approved, or committed. The JSON completion command is rejected before parsing when it exceeds 8192 bytes.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseImportApi();
final String importId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final CompleteCourseImportUploadRequest completeCourseImportUploadRequest = ; // CompleteCourseImportUploadRequest |

try {
    final response = api.completeCourseImportUpload(importId, idempotencyKey, completeCourseImportUploadRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseImportApi->completeCourseImportUpload: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importId** | **String**|  |
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **completeCourseImportUploadRequest** | [**CompleteCourseImportUploadRequest**](CompleteCourseImportUploadRequest.md)|  |

### Return type

[**CourseImportStatusResponse**](CourseImportStatusResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createCourseImport**
> CourseImportUploadSessionResponse createCourseImport(idempotencyKey, createCourseImportRequest)

Create an owner-scoped resumable XLSX upload session

Creates one bounded S3 multipart upload for an untrusted XLSX. The API never receives or parses workbook bytes. The whole-file and per-part digests are client assertions that the isolated worker recomputes or verifies before any scan, preview, archive, or approval can succeed. The JSON command body is rejected before parsing when it exceeds 8192 bytes; workbook bytes travel only through the bounded direct upload.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseImportApi();
final String idempotencyKey = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | Stable UUID generated once for the logical command.
final CreateCourseImportRequest createCourseImportRequest = ; // CreateCourseImportRequest |

try {
    final response = api.createCourseImport(idempotencyKey, createCourseImportRequest);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseImportApi->createCourseImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **idempotencyKey** | **String**| Stable UUID generated once for the logical command. |
 **createCourseImportRequest** | [**CreateCourseImportRequest**](CreateCourseImportRequest.md)|  |

### Return type

[**CourseImportUploadSessionResponse**](CourseImportUploadSessionResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getCourseImport**
> CourseImportStatusResponse getCourseImport(importId)

Return the current owner-scoped import state

Missing and non-owned imports are indistinguishable. Storage keys, object versions, upload IDs, scanner internals, and raw failures are deliberately absent.

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseImportApi();
final String importId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |

try {
    final response = api.getCourseImport(importId);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseImportApi->getCourseImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importId** | **String**|  |

### Return type

[**CourseImportStatusResponse**](CourseImportStatusResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCourseImportPreviewRows**
> CourseImportPreviewPage listCourseImportPreviewRows(importId, cursor, limit)

Page through the immutable normalized owner preview

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseImportApi();
final String importId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String cursor = cursor_example; // String | Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates.
final int limit = 56; // int |

try {
    final response = api.listCourseImportPreviewRows(importId, cursor, limit);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseImportApi->listCourseImportPreviewRows: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importId** | **String**|  |
 **cursor** | **String**| Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates. | [optional]
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**CourseImportPreviewPage**](CourseImportPreviewPage.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCourseImportValidationIssues**
> CourseImportIssuePage listCourseImportValidationIssues(importId, cursor, limit)

Page through the immutable owner-scoped validation report

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCourseImportApi();
final String importId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String cursor = cursor_example; // String | Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates.
final int limit = 56; // int |

try {
    final response = api.listCourseImportValidationIssues(importId, cursor, limit);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CourseImportApi->listCourseImportValidationIssues: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importId** | **String**|  |
 **cursor** | **String**| Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates. | [optional]
 **limit** | **int**|  | [optional] [default to 20]

### Return type

[**CourseImportIssuePage**](CourseImportIssuePage.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
