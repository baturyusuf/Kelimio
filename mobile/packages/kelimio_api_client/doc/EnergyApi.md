# kelimio_api_client.api.EnergyApi

## Load the API package
```dart
import 'package:kelimio_api_client/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getEnergy**](EnergyApi.md#getenergy) | **GET** /v1/energy | Return the lazily regenerated free-course energy account


# **getEnergy**
> EnergyResponse getEnergy()

Return the lazily regenerated free-course energy account

### Example
```dart
import 'package:kelimio_api_client/api.dart';

final api = KelimioApiClient().getEnergyApi();

try {
    final response = api.getEnergy();
    print(response);
} catch on DioException (e) {
    print('Exception when calling EnergyApi->getEnergy: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**EnergyResponse**](EnergyResponse.md)

### Authorization

[bearerAuth](../README.md#bearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)
