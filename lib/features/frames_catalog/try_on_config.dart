class TryOnConfig {
  const TryOnConfig._();

  static const websiteBaseUrl = String.fromEnvironment(
    'PATIENT_WEBSITE_BASE_URL',
    defaultValue: 'https://gonzalesvisionclinic.com',
  );

  static Uri? buildLaunchUri({
    required int frameId,
    required bool isDemo,
    required Uri apiBaseUri,
    String websiteOrigin = websiteBaseUrl,
  }) {
    if (isDemo || frameId <= 0 || !_isClinicApiOrigin(apiBaseUri)) {
      return null;
    }

    final websiteUri = Uri.tryParse(websiteOrigin);
    if (websiteUri == null || !_isClinicWebsiteOrigin(websiteUri)) {
      return null;
    }

    return websiteUri.replace(
      path: '/patient/frames.html',
      queryParameters: {'mobileTryOn': 'true', 'frameId': '$frameId'},
    );
  }

  static bool _isClinicApiOrigin(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'api.gonzalesvisionclinic.com' &&
      uri.port == 443 &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.userInfo.isEmpty;

  static bool _isClinicWebsiteOrigin(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'gonzalesvisionclinic.com' &&
      uri.port == 443 &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.userInfo.isEmpty;
}
