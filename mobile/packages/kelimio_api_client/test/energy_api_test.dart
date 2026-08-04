import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for EnergyApi
void main() {
  final instance = KelimioApiClient().getEnergyApi();

  group(EnergyApi, () {
    // Return the lazily regenerated free-course energy account
    //
    //Future<EnergyResponse> getEnergy() async
    test('test getEnergy', () async {
      // TODO
    });
  });
}
