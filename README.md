# Gonzales Vision Clinic Patient Portal (Flutter Web)

This is an isolated Flutter Web development project for the authenticated
patient portal. The existing HTML/CSS/JavaScript portal remains available and
unchanged.

The portal defaults to a dashboard preview using local, presentation-only mock
data. Demo mode does not authenticate patients or send credentials. Unfinished
destinations display local placeholder content.

## Run locally

From this directory, run:

```powershell
flutter run -d chrome
```

Or from the repository root:

```powershell
Set-Location landing\patient_flutter
flutter run -d chrome
```

## Run against the patient API

`API_BASE_URL` is not read by this Flutter project. Use
`PATIENT_AUTH_MODE=api` to select the API-backed repositories and
`PATIENT_API_BASE_URL` to configure the API host. From this directory, run:

```powershell
flutter run -d chrome -t lib\main.dart `
  --dart-define=PATIENT_AUTH_MODE=api `
  --dart-define=PATIENT_API_BASE_URL=https://api.gonzalesvisionclinic.com
```

`PATIENT_AUTH_MODE` accepts `demo` or `api`; API mode defaults to
`https://api.gonzalesvisionclinic.com` if `PATIENT_API_BASE_URL` is omitted.
The API host is used for API requests; Try-On has a separate website origin.
The `main_login.dart` entry point also starts at Login while using the selected
mode's repositories. API login keeps its returned JWT in memory only and opens
the existing Dashboard after successful login. Logout in API mode clears the
in-memory token locally but does not revoke it on the server. The app does not
restore sessions after a reload, persist tokens, or refresh tokens, so
refreshing the browser returns API mode to Login. The existing `Remember me`
choice is sent to the backend for its documented token lifetime behavior but
does not cause browser persistence.

In API mode, My Profile loads the authenticated account identity from
`GET /api/patients/auth/me` using the in-memory Bearer token. Only the returned
patient ID, name, email, email-verification state, and account status are shown
as server-confirmed. Date of birth, address, and contact number are unavailable
from this endpoint and are not filled with demo values. Edit Profile remains a
local preview and does not save patient data.

The backend's patient login and `/auth/me` routes are implemented in source,
but their production security and deployment configuration have not been
independently verified. The API preview is not a production-readiness claim.

In API mode, the Frames Catalog loads published frames from the public
`GET /api/frames` endpoint using the shared API client. Demo mode remains
network-free and keeps the local sample catalog. Relative frame image paths
resolve against `PATIENT_API_BASE_URL`; absolute image URLs must use HTTPS.
Search, category, stock, and sort controls operate on the loaded catalog.
Frame details remain read-only. For converted API catalog frames with a usable
3D model URL, Try-On opens a Flutter route in the current tab and embeds the
existing HTML experience using `mobileTryOn=true` and the selected `frameId`.
The Flutter route provides a minimal close control to return to the catalog.
The embedded HTML page still renders its own catalog UI; Flutter cannot hide
that content when the page is cross-origin. The website origin is
configured separately with `PATIENT_WEBSITE_BASE_URL`, which defaults to
`https://gonzalesvisionclinic.com`. The handoff is enabled only when the
configured API origin is `https://api.gonzalesvisionclinic.com`; Demo Mode and
custom or unmatched API/website environments are blocked so sample or
development frame IDs are not sent to the production website. The browser may
require camera permission for the clinic website.

In API mode, the patient notification dropdown uses the authenticated session
and the `/api/notifications/patient/:patient_id` endpoints to load notifications
and unread counts, mark individual notifications read, and mark all as read.
Notification polling runs every 20 seconds while the portal shell is mounted.
Demo mode continues to use local mock notifications without network requests.
Deployed endpoint availability, CORS, and production behavior have not been
independently verified.

Appointment History uses local sample records in Demo Mode. In API Mode it
uses the authenticated patient session and the existing
`GET /api/appointments/patient/:patient_id` endpoint through the shared API
client. The programmer has confirmed server-side patient-ownership protection;
however, the checked-out appointment route filters by the supplied patient ID
and does not expose that protection in the route or server middleware. This
integration therefore relies on that programmer confirmation, which has not
been independently verified against the deployed service. Reconfirm the
authorization behavior before deployment.

## Registration and email verification

Demo mode keeps Registration and OTP verification local and clearly marked as
simulated; it sends no requests. In API mode, Registration is intentionally
blocked before any HTTP request is made. The current backend route writes the
submitted password directly into `pending_patient_registrations` and later
copies that value into `patients.password`; do not enable registration until
the backend password storage is corrected and reviewed.

The Flutter API repository contains source-confirmed integrations for
`POST /api/patients/verify-email` and
`POST /api/patients/resend-verification`. Verification only succeeds when the
service returns success; otherwise the OTP screen displays a safe error and
remains open. A confirmed verification returns the user to Login; resend
cooldown begins only after a successful response. The cooldown is client-side
UX, not server-side rate limiting. These contracts and the security remediation
must be rechecked against the deployed backend before enabling the full flow.

## Design foundation

The theme starts from source-defined patient portal colors, rounded surfaces,
borders, and light/dark variants. Inter is not bundled in this project; the UI
uses Flutter's platform font fallback until an approved local font asset is
available. Pixel-level parity has not been assessed.
