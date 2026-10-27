import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/frames_catalog/catalog_frame.dart';
import 'package:patient_portal_flutter/features/frames_catalog/frames_catalog_mock_data.dart';
import 'package:patient_portal_flutter/features/frames_catalog/frames_catalog_repository.dart';

Map<String, dynamic> validFrame({
  Object? price = 2450,
  Object? stockQuantity = 8,
  Object? createdAt = '2026-10-25T10:00:00Z',
  Object? image = '/uploads/frame.jpg',
  Object? conversionStatus = 'Converted',
  Object? model3dUrl = '/uploads/models/frame.glb',
}) => {
  'frame_id': 12,
  'name': 'Avery Classic',
  'brand': 'Vista Optical',
  'category': 'Eyeglasses',
  'price': price,
  'stock_quantity': stockQuantity,
  'description': 'Lightweight frame.',
  'image_2d_url': image,
  'conversion_status': conversionStatus,
  'model_3d_url': model3dUrl,
  'created_at': createdAt,
};

void main() {
  const assetBaseUri = 'https://api.example.test';

  test('parses catalog fields, timestamp, and relative image URL', () {
    final frame = CatalogFrame.fromJson(
      validFrame(),
      assetBaseUri: Uri.parse(assetBaseUri),
    );

    expect(frame.frameId, 12);
    expect(frame.name, 'Avery Classic');
    expect(frame.brand, 'Vista Optical');
    expect(frame.category, 'Eyeglasses');
    expect(frame.price, 2450);
    expect(frame.stockQuantity, 8);
    expect(frame.description, 'Lightweight frame.');
    expect(frame.imageUrl, Uri.parse('$assetBaseUri/uploads/frame.jpg'));
    expect(frame.createdAt, DateTime.parse('2026-10-25T10:00:00Z'));
    expect(frame.model3dUrl, '/uploads/models/frame.glb');
    expect(frame.hasTryOnModel, isTrue);
  });

  test('supports decimal prices and documented nullable fields', () {
    final row = validFrame(
      price: '3190.50',
      stockQuantity: '2',
      createdAt: null,
      image: null,
      conversionStatus: null,
      model3dUrl: null,
    )..addAll({'brand': null, 'category': null, 'description': null});
    final frame = CatalogFrame.fromJson(
      row,
      assetBaseUri: Uri.parse(assetBaseUri),
    );

    expect(frame.price, 3190.5);
    expect(frame.stockQuantity, 2);
    expect(frame.brand, isNull);
    expect(frame.category, isNull);
    expect(frame.description, isNull);
    expect(frame.imageUrl, isNull);
    expect(frame.createdAt, isNull);
    expect(frame.hasTryOnModel, isFalse);
  });

  test('accepts absolute HTTPS image URLs and unknown conversion states', () {
    final frame = CatalogFrame.fromJson(
      validFrame(
        image: 'https://images.example.test/frame.png',
        conversionStatus: 'Future Status',
      ),
      assetBaseUri: Uri.parse(assetBaseUri),
    );

    expect(frame.imageUrl, Uri.parse('https://images.example.test/frame.png'));
    expect(frame.hasTryOnModel, isFalse);
  });

  test('requires a usable model URL as well as converted status', () {
    final missingModel = CatalogFrame.fromJson(
      validFrame(model3dUrl: null),
      assetBaseUri: Uri.parse(assetBaseUri),
    );
    final malformedModel = CatalogFrame.fromJson(
      validFrame(model3dUrl: 'javascript:alert(1)'),
      assetBaseUri: Uri.parse(assetBaseUri),
    );
    final insecureModel = CatalogFrame.fromJson(
      validFrame(model3dUrl: 'http://api.example.test/uploads/frame.glb'),
      assetBaseUri: Uri.parse(assetBaseUri),
    );
    final relativeModel = CatalogFrame.fromJson(
      validFrame(model3dUrl: 'uploads/models/frame.glb'),
      assetBaseUri: Uri.parse(assetBaseUri),
    );

    expect(missingModel.isTryOnConverted, isTrue);
    expect(missingModel.hasTryOnModel, isFalse);
    expect(malformedModel.hasTryOnModel, isFalse);
    expect(insecureModel.hasTryOnModel, isFalse);
    expect(relativeModel.hasTryOnModel, isTrue);
  });

  test('uses the legacy image URL when the primary URL is empty', () {
    final row = validFrame(image: '')..['image_url'] = '/uploads/legacy.jpg';
    final frame = CatalogFrame.fromJson(
      row,
      assetBaseUri: Uri.parse(assetBaseUri),
    );

    expect(frame.imageUrl, Uri.parse('$assetBaseUri/uploads/legacy.jpg'));
  });

  test('rejects invalid required and numeric fields', () {
    final invalidRows = <Map<String, dynamic>>[
      validFrame()..['frame_id'] = 0,
      validFrame()..['frame_id'] = 'not-an-id',
      validFrame()..['name'] = '  ',
      validFrame(price: '-1'),
      validFrame(price: 'NaN'),
      validFrame(price: double.infinity),
      validFrame(stockQuantity: -1),
      validFrame(stockQuantity: 2.5),
      validFrame(stockQuantity: 'not-stock'),
    ];

    for (final row in invalidRows) {
      expect(
        () => CatalogFrame.fromJson(row, assetBaseUri: Uri.parse(assetBaseUri)),
        throwsFormatException,
      );
    }
  });

  test('rejects non-HTTPS absolute image URLs and malformed timestamps', () {
    for (final row in [
      validFrame(image: 'http://images.example.test/frame.png'),
      validFrame(createdAt: 'not-a-date'),
    ]) {
      expect(
        () => CatalogFrame.fromJson(row, assetBaseUri: Uri.parse(assetBaseUri)),
        throwsFormatException,
      );
    }
  });

  test(
    'API repository reads the public array and preserves server order',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse(assetBaseUri),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/frames');
          return http.Response(
            jsonEncode([
              validFrame()..['frame_id'] = 12,
              validFrame()..['frame_id'] = 11,
            ]),
            200,
          );
        }),
      );
      addTearDown(client.close);

      final repository = ApiFramesCatalogRepository(client);
      final frames = await repository.getFrames();

      expect(frames.map((frame) => frame.frameId), [12, 11]);
      expect(repository.isDemo, isFalse);
    },
  );

  test('API repository accepts an empty catalog', () async {
    final client = ApiClient(
      baseUri: Uri.parse(assetBaseUri),
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(client.close);

    expect(await ApiFramesCatalogRepository(client).getFrames(), isEmpty);
  });

  test('API repository hides malformed catalog payload details', () async {
    final client = ApiClient(
      baseUri: Uri.parse(assetBaseUri),
      client: MockClient(
        (_) async => http.Response(jsonEncode([validFrame(price: -5)]), 200),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      ApiFramesCatalogRepository(client).getFrames(),
      throwsA(
        isA<ApiFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            )
            .having(
              (failure) => failure.message,
              'message',
              'The clinic service returned an invalid frame catalog.',
            ),
      ),
    );
  });

  test(
    'demo setup selects the existing mock catalog without an API client',
    () async {
      final setup = createPatientAuthSetup(mode: 'demo');
      addTearDown(setup.controller.dispose);

      expect(setup.controller.isDemoMode, isTrue);
      expect(setup.framesCatalogRepository.isDemo, isTrue);
      expect(
        await setup.framesCatalogRepository.getFrames(),
        same(FramesCatalogMockData.frames),
      );
    },
  );
}
