import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import 'catalog_frame.dart';
import 'frames_catalog_mock_data.dart';

abstract interface class FramesCatalogRepository {
  bool get isDemo;

  List<CatalogFrame>? get localFrames;

  Future<List<CatalogFrame>> getFrames();
}

class DemoFramesCatalogRepository implements FramesCatalogRepository {
  const DemoFramesCatalogRepository();

  @override
  bool get isDemo => true;

  @override
  List<CatalogFrame> get localFrames => FramesCatalogMockData.frames;

  @override
  Future<List<CatalogFrame>> getFrames() async => localFrames;
}

class ApiFramesCatalogRepository implements FramesCatalogRepository {
  const ApiFramesCatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  bool get isDemo => false;

  @override
  List<CatalogFrame>? get localFrames => null;

  @override
  Future<List<CatalogFrame>> getFrames() async {
    try {
      final rows = await _apiClient.getJsonList('/api/frames');
      return rows
          .map((row) {
            if (row is! Map<String, dynamic>) {
              throw const FormatException('Invalid frame catalog entry.');
            }
            return CatalogFrame.fromJson(row, assetBaseUri: _apiClient.baseUri);
          })
          .toList(growable: false);
    } on FormatException {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: 'The clinic service returned an invalid frame catalog.',
      );
    }
  }
}
