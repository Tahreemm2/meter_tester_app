// =============================================================================
// FILE: lib/features/admin/data/admin_repository.dart
// PURPOSE: Talks to backend/api/admin/{users,consumers,form_options}.php.
// All calls require a bearer token belonging to an ADMIN-role user; the
// backend enforces this server-side (403 FORBIDDEN_ROLE otherwise) but the
// UI also gates access to this feature to Admins only (see AdminHomeScreen).
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/admin_models.dart';

/// A page of results plus the total row count, for pagination controls.
class AdminPage<T> {
  final List<T> items;
  final int total;
  const AdminPage({required this.items, required this.total});
}

abstract class AdminRepository {
  // ---- Users --------------------------------------------------------------
  Future<AdminPage<ManagedUser>> listUsers({int page = 1, int perPage = 20});

  Future<void> createUser({
    required String employeeId,
    required String fullName,
    required String username,
    required String password,
    required String roleCode,
    required String scopeCode,
    required String scopeName,
    String? contactNumber,
  });

  Future<void> updateUser(
    int id, {
    String? fullName,
    String? roleCode,
    String? scopeCode,
    String? scopeName,
    String? contactNumber,
    bool? isActive,
    String? password,
  });

  Future<void> deactivateUser(int id);

  // ---- Consumers ------------------------------------------------------------
  Future<AdminPage<ManagedConsumer>> listConsumers({
    int page = 1,
    int perPage = 20,
    String? search,
  });

  Future<void> createConsumer({
    required String referenceNumber,
    required String meterId,
    required String consumerName,
    required String consumerAddress,
    required String consumerAccount,
    required String tariffCategory,
    required String sanctionedLoad,
  });

  Future<void> updateConsumer(
    int id, {
    String? referenceNumber,
    String? meterId,
    String? consumerName,
    String? consumerAddress,
    String? consumerAccount,
    String? tariffCategory,
    String? sanctionedLoad,
  });

  Future<void> deleteConsumer(int id);

  // ---- Form options ---------------------------------------------------------
  Future<List<ManagedFormOption>> listFormOptions({String? dropdownKey});

  Future<void> createFormOption({
    required String dropdownKey,
    required String code,
    required String label,
    String? description,
    int sortOrder = 0,
  });

  Future<void> updateFormOption(
    int id, {
    String? label,
    String? description,
    int? sortOrder,
    bool? isActive,
  });

  Future<void> deleteFormOption(int id);
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiAdminRepository implements AdminRepository {
  final ApiClient _client;
  final String token;

  ApiAdminRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  // ---- Users ----------------------------------------------------------------
  @override
  Future<AdminPage<ManagedUser>> listUsers({int page = 1, int perPage = 20}) async {
    final response = await _client.get(
      ApiConfig.adminUri(ApiConfig.adminUsers, {
        'page': '$page',
        'per_page': '$perPage',
      }),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => ManagedUser.fromJson(e as Map<String, dynamic>))
        .toList();
    return AdminPage(items: items, total: (response['total'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<void> createUser({
    required String employeeId,
    required String fullName,
    required String username,
    required String password,
    required String roleCode,
    required String scopeCode,
    required String scopeName,
    String? contactNumber,
  }) {
    return _client.post(
      ApiConfig.adminUri(ApiConfig.adminUsers),
      token: token,
      body: {
        'employee_id': employeeId,
        'full_name': fullName,
        'username': username,
        'password': password,
        'role_code': roleCode,
        'scope_code': scopeCode,
        'scope_name': scopeName,
        if (contactNumber != null && contactNumber.isNotEmpty) 'contact_number': contactNumber,
      },
    );
  }

  @override
  Future<void> updateUser(
    int id, {
    String? fullName,
    String? roleCode,
    String? scopeCode,
    String? scopeName,
    String? contactNumber,
    bool? isActive,
    String? password,
  }) {
    return _client.put(
      ApiConfig.adminUri(ApiConfig.adminUsers, {'id': '$id'}),
      token: token,
      body: {
        if (fullName != null) 'full_name': fullName,
        if (roleCode != null) 'role_code': roleCode,
        if (scopeCode != null) 'scope_code': scopeCode,
        if (scopeName != null) 'scope_name': scopeName,
        if (contactNumber != null) 'contact_number': contactNumber,
        if (isActive != null) 'is_active': isActive,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  @override
  Future<void> deactivateUser(int id) {
    return _client.delete(ApiConfig.adminUri(ApiConfig.adminUsers, {'id': '$id'}), token: token);
  }

  // ---- Consumers --------------------------------------------------------------
  @override
  Future<AdminPage<ManagedConsumer>> listConsumers({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final response = await _client.get(
      ApiConfig.adminUri(ApiConfig.adminConsumers, {
        'page': '$page',
        'per_page': '$perPage',
        if (search != null && search.isNotEmpty) 'search': search,
      }),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => ManagedConsumer.fromJson(e as Map<String, dynamic>))
        .toList();
    return AdminPage(items: items, total: (response['total'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<void> createConsumer({
    required String referenceNumber,
    required String meterId,
    required String consumerName,
    required String consumerAddress,
    required String consumerAccount,
    required String tariffCategory,
    required String sanctionedLoad,
  }) {
    return _client.post(
      ApiConfig.adminUri(ApiConfig.adminConsumers),
      token: token,
      body: {
        'reference_number': referenceNumber,
        'meter_id': meterId,
        'consumer_name': consumerName,
        'consumer_address': consumerAddress,
        'consumer_account': consumerAccount,
        'tariff_category': tariffCategory,
        'sanctioned_load': sanctionedLoad,
      },
    );
  }

  @override
  Future<void> updateConsumer(
    int id, {
    String? referenceNumber,
    String? meterId,
    String? consumerName,
    String? consumerAddress,
    String? consumerAccount,
    String? tariffCategory,
    String? sanctionedLoad,
  }) {
    return _client.put(
      ApiConfig.adminUri(ApiConfig.adminConsumers, {'id': '$id'}),
      token: token,
      body: {
        if (referenceNumber != null) 'reference_number': referenceNumber,
        if (meterId != null) 'meter_id': meterId,
        if (consumerName != null) 'consumer_name': consumerName,
        if (consumerAddress != null) 'consumer_address': consumerAddress,
        if (consumerAccount != null) 'consumer_account': consumerAccount,
        if (tariffCategory != null) 'tariff_category': tariffCategory,
        if (sanctionedLoad != null) 'sanctioned_load': sanctionedLoad,
      },
    );
  }

  @override
  Future<void> deleteConsumer(int id) {
    return _client.delete(ApiConfig.adminUri(ApiConfig.adminConsumers, {'id': '$id'}), token: token);
  }

  // ---- Form options -------------------------------------------------------------
  @override
  Future<List<ManagedFormOption>> listFormOptions({String? dropdownKey}) async {
    final response = await _client.get(
      ApiConfig.adminUri(ApiConfig.adminFormOptions, {
        if (dropdownKey != null) 'dropdown_key': dropdownKey,
      }),
      token: token,
    );
    return (response['data'] as List)
        .map((e) => ManagedFormOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> createFormOption({
    required String dropdownKey,
    required String code,
    required String label,
    String? description,
    int sortOrder = 0,
  }) {
    return _client.post(
      ApiConfig.adminUri(ApiConfig.adminFormOptions),
      token: token,
      body: {
        'dropdown_key': dropdownKey,
        'code': code,
        'label': label,
        if (description != null && description.isNotEmpty) 'description': description,
        'sort_order': sortOrder,
      },
    );
  }

  @override
  Future<void> updateFormOption(
    int id, {
    String? label,
    String? description,
    int? sortOrder,
    bool? isActive,
  }) {
    return _client.put(
      ApiConfig.adminUri(ApiConfig.adminFormOptions, {'id': '$id'}),
      token: token,
      body: {
        if (label != null) 'label': label,
        if (description != null) 'description': description,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  @override
  Future<void> deleteFormOption(int id) {
    return _client.delete(ApiConfig.adminUri(ApiConfig.adminFormOptions, {'id': '$id'}), token: token);
  }
}
