import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/dashboard/dashboard_page.dart';
import 'package:patient_portal_flutter/features/frames_catalog/catalog_frame.dart';
import 'package:patient_portal_flutter/features/frames_catalog/frames_catalog_repository.dart';

void main() {
  testWidgets('opens Try-On and returns to the mounted catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final setup = createPatientAuthSetup(mode: 'demo');
    addTearDown(setup.controller.dispose);
    await tester.pumpWidget(
      PatientAuthScope(
        controller: setup.controller,
        framesCatalogRepository: _LiveFramesRepository([
          _frame(model3dUrl: '/uploads/models/frame.glb'),
        ]),
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: DashboardPage(isDark: false, onToggleTheme: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Frames Catalog').first);
    await tester.pumpAndSettle();
    expect(find.text('Our Collection'), findsOneWidget);

    await tester.ensureVisible(find.text('Try On 3D').first);
    await tester.tap(find.text('Try On 3D').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Virtual Try-On'), findsNothing);
    expect(find.byTooltip('Close Try-On'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close Try-On'));
    await tester.pumpAndSettle();

    expect(find.text('Our Collection'), findsOneWidget);
    expect(find.text('Virtual Try-On'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

CatalogFrame _frame({required String? model3dUrl}) => CatalogFrame(
  frameId: 42,
  name: 'Live Catalog Frame',
  price: 2500,
  stockQuantity: 4,
  conversionStatus: 'Converted',
  model3dUrl: model3dUrl,
);

class _LiveFramesRepository implements FramesCatalogRepository {
  const _LiveFramesRepository(this.frames);

  final List<CatalogFrame> frames;

  @override
  bool get isDemo => false;

  @override
  List<CatalogFrame>? get localFrames => null;

  @override
  Future<List<CatalogFrame>> getFrames() async => frames;
}
