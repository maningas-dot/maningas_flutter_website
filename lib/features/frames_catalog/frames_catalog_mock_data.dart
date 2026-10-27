import 'catalog_frame.dart';

typedef DemoFrame = CatalogFrame;

class FramesCatalogMockData {
  const FramesCatalogMockData._();

  static const frames = <CatalogFrame>[
    DemoFrame(
      frameId: 112,
      name: 'Avery Classic',
      brand: 'Vista Optical',
      category: 'Eyeglasses',
      price: 2450,
      stockQuantity: 8,
      description:
          'A lightweight everyday frame with a clean, timeless silhouette.',
      conversionStatus: 'converted',
    ),
    DemoFrame(
      frameId: 111,
      name: 'Harper Round',
      brand: 'Northline',
      category: 'Eyeglasses',
      price: 3190,
      stockQuantity: 2,
      description:
          'A rounded acetate frame designed for a comfortable daily fit.',
      conversionStatus: 'processing',
    ),
    DemoFrame(
      frameId: 110,
      name: 'Sol Coast',
      brand: 'Daylight',
      category: 'Sunglasses',
      price: 2850,
      stockQuantity: 5,
      description:
          'A classic sun frame with a balanced shape for everyday wear.',
      conversionStatus: 'converted',
    ),
    DemoFrame(
      frameId: 109,
      name: 'Milo Junior',
      brand: 'Little Look',
      category: 'Kids',
      price: 1850,
      stockQuantity: 0,
      description: 'A compact, lightweight frame with a flexible fit for younger wearers.',
      conversionStatus: 'pending',
    ),
    DemoFrame(
      frameId: 108,
      name: 'Luna Slim',
      brand: 'Vista Optical',
      category: 'Eyeglasses',
      price: 2190,
      stockQuantity: 12,
      description:
          'A slim-profile frame with understated detailing and a light feel.',
      conversionStatus: 'pending',
    ),
    DemoFrame(
      frameId: 107,
      name: 'Ridge Sport',
      brand: 'Motion',
      category: 'Sports',
      price: 3790,
      stockQuantity: 1,
      description: 'A secure-fitting sport frame designed to stay comfortable during activity.',
      conversionStatus: 'converted',
    ),
    DemoFrame(
      frameId: 106,
      name: 'Parker Square',
      brand: 'Northline',
      category: 'Eyeglasses',
      price: 2950,
      stockQuantity: 6,
      description:
          'A structured square frame with a versatile, everyday profile.',
      conversionStatus: 'pending',
    ),
    DemoFrame(
      frameId: 105,
      name: 'Sol Mini',
      brand: 'Daylight',
      category: 'Sunglasses',
      price: 2650,
      stockQuantity: 0,
      description: 'A smaller sun frame with a simple shape and lightweight construction.',
      conversionStatus: 'pending',
    ),
    DemoFrame(
      frameId: 104,
      name: 'Arden Soft',
      brand: 'Vista Optical',
      category: 'Eyeglasses',
      price: 3420,
      stockQuantity: 3,
      description:
          'A softly rounded frame with subtle accents and a balanced fit.',
      conversionStatus: 'converted',
    ),
    DemoFrame(
      frameId: 103,
      name: 'Kai Flex',
      brand: 'Little Look',
      category: 'Kids',
      price: 1690,
      stockQuantity: 7,
      description:
          'A flexible kids frame with a light feel for everyday school wear.',
      conversionStatus: 'pending',
    ),
    DemoFrame(
      frameId: 102,
      name: 'Harbor Shade',
      brand: 'Motion',
      category: 'Sunglasses',
      price: 4100,
      stockQuantity: 4,
      description: 'A contemporary sun frame with a broad, comfortable fit.',
      conversionStatus: 'processing',
    ),
    DemoFrame(
      frameId: 101,
      name: 'Ellis Minimal',
      brand: 'Northline',
      category: 'Eyeglasses',
      price: 2290,
      stockQuantity: 9,
      description:
          'A minimal frame with a light profile for a simple everyday look.',
      conversionStatus: 'pending',
    ),
  ];
}
