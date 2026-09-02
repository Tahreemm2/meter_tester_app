// =============================================================================
// FILE: lib/core/config/api_config.dart
// PURPOSE: Single source of truth for the backend base URL and endpoint
// paths. This is the ONLY file you need to edit to point the app at a
// different environment (local dev, staging, production Railway URL).
//
// The backend is the vanilla PHP + MySQL API deployed on Railway
// (see: mepco-meter-testing-backend.zip / API.md for the full contract).
// =============================================================================

class ApiConfig {
  ApiConfig._();

  // ---------------------------------------------------------------------------
  // ⚠️ SET THIS to your deployed Railway URL (no trailing slash), e.g.:
  //   'https://mepco-meter-testing-backend.up.railway.app'
  //
  // For local testing against `php -S 0.0.0.0:8000 -t .` on the same machine
  // as the Android emulator, use 'http://10.0.2.2:8000' instead of
  // 'http://localhost:8000' (the emulator can't see the host's localhost).
  // For a physical device on the same Wi-Fi as your dev machine, use your
  // machine's LAN IP, e.g. 'http://192.168.1.50:8000'.
  // ---------------------------------------------------------------------------
  static const String baseUrl = 'https://backend-production-70a7.up.railway.app';

  // How long to wait before giving up on a request and surfacing a
  // network-error message to the user. Railway's free/hobby tier can sleep
  // after inactivity and take several seconds to cold-start on the next
  // request — 30s gives that room without hanging the UI indefinitely.
  static const Duration requestTimeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // ENDPOINT PATHS — must match backend/api/*.php exactly.
  // ---------------------------------------------------------------------------
  static const String login  = '/api/login.php';
  static const String logout = '/api/logout.php';
  static const String me     = '/api/me.php';
  static const String changePassword = '/api/change_password.php';

  static const String data              = '/api/data.php';
  static const String formOptionsAction  = 'form-options';
  static const String consumerFetchAction = 'consumer-fetch';
  static const String inspectionSubmitAction = 'inspection-submit';
  static const String inspectionsListAction  = 'inspections-list';
  static const String inspectionDetailAction = 'inspection-detail';

  // ---------------------------------------------------------------------------
  // ADMIN ENDPOINTS — ADMIN role only. Full CRUD for employee accounts,
  // consumer/meter records, and inspection-form dropdown options.
  // See backend/api/admin/*.php and API.md "Admin management" section.
  // ---------------------------------------------------------------------------
  static const String adminUsers        = '/api/admin/users.php';
  static const String adminConsumers    = '/api/admin/consumers.php';
  static const String adminFormOptions  = '/api/admin/form_options.php';
  static const String adminSchedules    = '/api/admin/schedules.php';

  // ---------------------------------------------------------------------------
  // SUPERVISORY / SHARED ENDPOINTS — access is role-scoped server-side per
  // method rather than admin-exclusive. See API.md "Meter Scheduling System",
  // "Task Assignment", and "Discrepancy Reporting" sections.
  // ---------------------------------------------------------------------------
  static const String tasks         = '/api/tasks.php';
  static const String discrepancies = '/api/discrepancies.php';

  // ---------------------------------------------------------------------------
  // APPROVAL WORKFLOW & DASHBOARD — supervisory roles (SDO/XEN/SE/ADMIN).
  // See API.md "Approval Workflow" / "Dashboard & Analytics".
  // ---------------------------------------------------------------------------
  static const String approvals      = '/api/approvals.php';
  static const String approvalRules  = '/api/admin/approval_rules.php';
  static const String dashboard      = '/api/dashboard.php';
  static const String alerts         = '/api/alerts.php';

  static Uri adminUri(String path, [Map<String, String>? params]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: {
      if (params != null) ...params,
    });
  }

  static Uri dataUri(String action, [Map<String, String>? extraParams]) {
    return Uri.parse('$baseUrl$data').replace(queryParameters: {
      'action': action,
      ...?extraParams,
    });
  }

  static Uri uri(String path) => Uri.parse('$baseUrl$path');
}
