# kelimio_api_client.api.CatalogApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getCourse**](CatalogApi.md#getcourse) | **GET** /v1/courses/{courseId} | Return course details visible to the authenticated user
[**listCatalogCourses**](CatalogApi.md#listcatalogcourses) | **GET** /v1/catalog/courses | List public, published courses


# **getCourse**
> CourseDetail getCourse(courseId, xKelimioClientCapabilities)

Return course details visible to the authenticated user

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCatalogApi();
final String courseId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String |
final String xKelimioClientCapabilities = xKelimioClientCapabilities_example; // String | Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.

try {
    final response = api.getCourse(courseId, xKelimioClientCapabilities);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CatalogApi->getCourse: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **courseId** | **String**|  |
 **xKelimioClientCapabilities** | **String**| Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization. | [optional]

### Return type

[**CourseDetail**](CourseDetail.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listCatalogCourses**
> CoursePage listCatalogCourses(xKelimioClientCapabilities, cursor, limit, targetLanguage, supportLanguage)

List public, published courses

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getCatalogApi();
final String xKelimioClientCapabilities = xKelimioClientCapabilities_example; // String | Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
final String cursor = cursor_example; // String | Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates.
final int limit = 56; // int |
final String targetLanguage = targetLanguage_example; // String |
final String supportLanguage = supportLanguage_example; // String |

try {
    final response = api.listCatalogCourses(xKelimioClientCapabilities, cursor, limit, targetLanguage, supportLanguage);
    print(response);
} catch on DioException (e) {
    print('Exception when calling CatalogApi->listCatalogCourses: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **xKelimioClientCapabilities** | **String**| Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization. | [optional]
 **cursor** | **String**| Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates. | [optional]
 **limit** | **int**|  | [optional] [default to 20]
 **targetLanguage** | **String**|  | [optional]
 **supportLanguage** | **String**|  | [optional]

### Return type

[**CoursePage**](CoursePage.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
