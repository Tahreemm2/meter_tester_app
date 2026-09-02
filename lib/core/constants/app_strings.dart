// =============================================================================
// FILE: lib/core/constants/app_strings.dart
// PURPOSE: Centralized UI string constants for the Meter Testing App.
//
// LOCALIZATION GUIDE:
//   - All user-visible strings are defined here as static constants.
//   - To add Urdu (ur_PK) support, create a parallel class `AppStringsUr`
//     and swap the reference via a LocalizationService based on locale.
//   - String keys follow the convention: context_element_state
//     e.g., login_button_label, otp_resend_link_active
//
// USAGE:
//   Text(AppStrings.loginTitle)
// =============================================================================

class AppStrings {
  AppStrings._();

  // ---------------------------------------------------------------------------
  // APP GLOBAL
  // ---------------------------------------------------------------------------
  static const String appName             = 'Meter Testing System';
  static const String appSubtitle         = 'Field Operations Portal';
  static const String appDepartment       = 'WAPDA / Distribution Company';

  // ---------------------------------------------------------------------------
  // LOGIN SCREEN
  // ---------------------------------------------------------------------------
  static const String loginEyebrow        = 'SECURE LOGIN';
  static const String loginTitle          = 'Login';
  static const String loginWelcome        = 'Welcome back';
  static const String loginSubtitle       = 'Login to continue your field operations';
  static const String loginUsernameLabel  = 'Username / Employee ID';
  static const String loginUsernameHint   = 'e.g. emp12345 or user@disco.gov.pk';
  static const String loginPasswordLabel  = 'Password';
  static const String loginPasswordHint   = '••••••••';
  static const String loginRememberMe     = 'Remember me';
  static const String loginForgotPassword = 'Forgot password?';
  static const String loginButtonLabel    = 'Login';
  static const String loginLoadingLabel   = 'Authenticating...';
  static const String loginFooterTagline  = 'MEPCO • Meter Testing System';
  static const String loginForgotPasswordMsg =
      'Please contact your IT administrator to reset your password.';

  // Validation messages
  static const String validUsernameEmpty  = 'Username or Employee ID is required.';
  static const String validUsernameFormat = 'Enter a valid username or email address.';
  static const String validPasswordEmpty  = 'Password is required.';
  static const String validPasswordLength = 'Password must be at least 6 characters.';

  // Error messages (from simulated API)
  static const String errorInvalidCreds  = 'Invalid credentials. Please try again.';
  static const String errorServerDown    = 'Server unavailable. Contact IT support.';
  static const String errorNetworkOff    = 'No network connection detected.';

  // ---------------------------------------------------------------------------
  // OTP SCREEN
  // ---------------------------------------------------------------------------
  static const String otpTitle           = 'Verify Identity';
  static const String otpSubtitle        = 'A one-time PIN has been sent to your registered mobile/email.';
  static const String otpInputLabel      = 'Enter 6-Digit PIN';
  static const String otpVerifyButton    = 'Verify & Proceed';
  static const String otpLoadingLabel    = 'Verifying...';
  static const String otpResendActive    = 'Resend OTP via SIM / Email';
  static const String otpResendCooldown  = 'Resend available in '; // append "XX sec"
  static const String otpResendSuffix    = ' sec';
  static const String otpSentTo          = 'PIN sent to: ';

  // OTP validation
  static const String validOtpEmpty      = 'Please enter the 6-digit PIN.';
  static const String validOtpLength     = 'PIN must be exactly 6 digits.';
  static const String validOtpNumeric    = 'PIN must contain numbers only.';
  static const String errorOtpInvalid    = 'Incorrect PIN. Please try again.';
  static const String errorOtpExpired    = 'PIN has expired. Please request a new one.';

  // ---------------------------------------------------------------------------
  // HOME SHELL / DASHBOARD
  // ---------------------------------------------------------------------------
  static const String homeTitle          = 'Dashboard';
  static const String homeWelcome        = 'Welcome,';
  static const String homeLoggedInAs     = 'Logged in as:';
  static const String homeRegionLabel    = 'Region:';
  static const String homeRoleLabel      = 'Role:';
  static const String homeScopeLabel     = 'Geographic Scope:';
  static const String homeLogoutButton   = 'Logout';
  static const String homeLogoutConfirm  = 'Are you sure you want to logout?';
  static const String homeLogoutCancel   = 'Cancel';
  static const String homeLogoutConfirmBtn = 'Logout';

  // Module placeholders (future screens)
  static const String moduleTests        = 'Meter Tests';
  static const String moduleReports      = 'Reports';
  static const String moduleInventory    = 'Inventory';
  static const String moduleApprovals    = 'Approvals';
  static const String moduleSettings     = 'Settings';
  static const String moduleComingSoon   = 'Module coming soon';
  static const String moduleTasks        = 'My Tasks';
  static const String moduleDiscrepancies = 'Discrepancies';
  static const String moduleScheduling   = 'Scheduling';
  static const String moduleDashboard    = 'Analytics';
  static const String moduleAlerts       = 'Alerts';

  // ---------------------------------------------------------------------------
  // TASK ASSIGNMENT MODULE
  // ---------------------------------------------------------------------------
  static const String tasksTitle           = 'Task Assignment';
  static const String tasksEmptyMine       = 'No tasks assigned to you yet.';
  static const String tasksEmptyAll        = 'No tasks have been assigned yet.';
  static const String tasksAssignNew       = 'Assign Task';
  static const String tasksStartTask       = 'Start Task';
  static const String tasksCancelTask      = 'Cancel Task';
  static const String tasksConfirmCancel   = 'This will cancel the task and preserve it in the history.';
  static const String tasksReassign        = 'Reassign';

  // ---------------------------------------------------------------------------
  // DISCREPANCY REPORTING MODULE
  // ---------------------------------------------------------------------------
  static const String discrepanciesTitle       = 'Discrepancy Reports';
  static const String discrepanciesEmptyMine   = 'You haven\'t reported any discrepancies yet.';
  static const String discrepanciesEmptyAll    = 'No discrepancy reports yet.';
  static const String discrepanciesReportNew   = 'Report Discrepancy';
  static const String discrepanciesTriage      = 'Triage';

  // ---------------------------------------------------------------------------
  // METER SCHEDULING MODULE (supervisory roles)
  // ---------------------------------------------------------------------------
  static const String schedulingTitle        = 'Meter Scheduling';
  static const String schedulingEmpty        = 'No schedule entries for the selected filters.';
  static const String schedulingGenerate     = 'Auto-Generate Quarter';
  static const String schedulingAddManual    = 'Add Manually';

  // ---------------------------------------------------------------------------
  // APPROVAL WORKFLOW MODULE (supervisory roles: SDO -> XEN -> SE)
  // ---------------------------------------------------------------------------
  static const String approvalsTitle          = 'Approvals';
  static const String approvalsEmptyPending   = 'Nothing waiting on your review right now.';
  static const String approvalsEmptyDecided   = 'You haven\'t decided any inspections yet.';
  static const String approvalsApprove        = 'Approve';
  static const String approvalsReject         = 'Reject';
  static const String approvalsRemarksHint    = 'Optional remarks for this decision...';
  static const String approvalsConfirmApprove = 'This will move the inspection to the next approval level (or finalize it if this is the last one).';
  static const String approvalsConfirmReject  = 'This will reject the inspection. The approval chain stops here.';
  static const String approvalsHistoryTitle   = 'Decision History';
  static const String approvalsNotYourLevel   = 'This inspection is awaiting a different reviewer\'s decision.';

  // ---------------------------------------------------------------------------
  // DASHBOARD & ANALYTICS MODULE (supervisory roles)
  // ---------------------------------------------------------------------------
  static const String dashboardTitle          = 'Dashboard & Analytics';
  static const String dashboardSummaryTitle   = 'This Quarter';
  static const String dashboardPipelineTitle  = 'Approval Pipeline';
  static const String dashboardTrendsTitle    = 'Discrepancy Trends';
  static const String dashboardTeamTitle      = 'Team Performance';
  static const String dashboardEmptyTeam      = 'No field-team activity for the selected filters.';
  static const String dashboardEmptyTrends    = 'No discrepancies reported for the selected filters.';

  // ---------------------------------------------------------------------------
  // ROLE DISPLAY NAMES
  // ---------------------------------------------------------------------------
  static const Map<String, String> roleDisplayNames = {
    'MT'    : 'Meter Tester (M&T)',
    'SDO'   : 'Sub-Divisional Officer',
    'XEN'   : 'Executive Engineer',
    'SE'    : 'Superintending Engineer',
    'ADMIN' : 'System Administrator',
  };

  // ---------------------------------------------------------------------------
  // GEOGRAPHIC SCOPE LABELS
  // ---------------------------------------------------------------------------
  static const Map<String, String> scopeLabels = {
    'SUB_DIVISION' : 'Sub-Division',
    'DIVISION'     : 'Division',
    'CIRCLE'       : 'Circle',
    'REGION'       : 'Region',
    'NATIONAL'     : 'National (All)',
  };

  // ---------------------------------------------------------------------------
  // ACCESSIBILITY / SEMANTICS
  // ---------------------------------------------------------------------------
  static const String semanticPasswordShow   = 'Show password';
  static const String semanticPasswordHide   = 'Hide password';
  static const String semanticLoadingSpinner = 'Loading, please wait';

  // ---------------------------------------------------------------------------
  // ADMIN PANEL (ADMIN role only)
  // ---------------------------------------------------------------------------
  static const String adminPanelTitle       = 'Admin Panel';
  static const String adminUsersTitle       = 'Manage Users';
  static const String adminUsersSubtitle    = 'Create, edit, and deactivate employee accounts';
  static const String adminConsumersTitle   = 'Manage Consumers';
  static const String adminConsumersSubtitle = 'Meter & consumer records used by Auto-Fetch';
  static const String adminFormOptionsTitle = 'Form Options';
  static const String adminFormOptionsSubtitle = 'Seal Condition & CT-PT Box dropdown values';

  static const String adminAddNew            = 'Add New';
  static const String adminSave              = 'Save';
  static const String adminCancel            = 'Cancel';
  static const String adminDelete            = 'Delete';
  static const String adminDeactivate        = 'Deactivate';
  static const String adminEdit              = 'Edit';
  static const String adminSearchHint        = 'Search by reference, name, or account...';
  static const String adminEmptyList         = 'Nothing here yet.';
  static const String adminLoadMore          = 'Load more';
  static const String adminConfirmDeleteTitle = 'Are you sure?';
  static const String adminConfirmDeleteUser  = 'This will deactivate the account and revoke all active sessions.';
  static const String adminConfirmDeleteConsumer = 'This will permanently delete this consumer record.';
  static const String adminConfirmDeleteOption = 'This will permanently delete this form option.';
}
