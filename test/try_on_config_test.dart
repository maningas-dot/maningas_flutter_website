import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/features/frames_catalog/try_on_config.dart';

void main() {
  const productionApi = 'https://api.gonzalesvisionclinic.com';
  const productionWebsite = 'https://gonzalesvisionclinic.com';

  test('builds the existing HTML Try-On URL with the selected frame ID', () {
    final uri = TryOnConfig.buildLaunchUri(
      frameId: 42,
      isDemo: false,
      apiBaseUri: Uri.parse(productionApi),
    );

    expect(
      uri,
      Uri.parse(
        '$productionWebsite/patient/frames.html'
        '?mobileTryOn=true&frameId=42',
      ),
    );
    expect(uri!.queryParameters, {'mobileTryOn': 'true', 'frameId': '42'});
  });

  test('blocks demo data and custom API or website environments', () {
    expect(
      TryOnConfig.buildLaunchUri(
        frameId: 42,
        isDemo: true,
        apiBaseUri: Uri.parse(productionApi),
      ),
      isNull,
    );
    expect(
      TryOnConfig.buildLaunchUri(
        frameId: 42,
        isDemo: false,
        apiBaseUri: Uri.parse('https://api.staging.example.test'),
      ),
      isNull,
    );
    expect(
      TryOnConfig.buildLaunchUri(
        frameId: 42,
        isDemo: false,
        apiBaseUri: Uri.parse(productionApi),
        websiteOrigin: 'https://staging.example.test',
      ),
      isNull,
    );
  });

  test('rejects invalid IDs and API base paths', () {
    expect(
      TryOnConfig.buildLaunchUri(
        frameId: 0,
        isDemo: false,
        apiBaseUri: Uri.parse(productionApi),
      ),
      isNull,
    );
    expect(
      TryOnConfig.buildLaunchUri(
        frameId: 42,
        isDemo: false,
        apiBaseUri: Uri.parse('$productionApi/custom-path'),
      ),
      isNull,
    );
  });
}
