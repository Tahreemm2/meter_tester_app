// =============================================================================
// FILE: lib/core/utils/scope_defaults.dart
// PURPOSE: Implements the workflow spec's core access rule — "the app has
// one dashboard design, but the data changes according to the logged-in
// user's access": an SDO must only ever see their own sub-division's data,
// an XEN only their own division's, while SE/ADMIN see everything (the data
// model has no per-circle field yet, so circle-level scoping for SE isn't
// enforceable client-side — see the note below).
//
// This computes the division/sub_division values every role-scoped list or
// dashboard screen should silently pass to its repository calls. Unlike an
// ordinary filter, these are NOT presented as an editable control for SDO/
// XEN — per the spec they must not be able to opt into seeing another
// sub-division/division, so there's no "All" toggle for those two roles.
//
// "The SDO supervises one or more sub-divisions" (workflow spec) — the
// backend's users.scope_name is a single text column, so a multi-sub-
// division assignment is represented as a comma/semicolon-separated list
// within that one string (e.g. "Multan North Sub-Division, Multan South
// Sub-Division") until the backend grows a proper one-to-many assignment
// table. [subDivisions] parses that; [mergeAcrossSubDivisions] is the
// fetch-per-area-and-flatten helper every multi-area screen uses.
//
// NOTE: SE's scope is a *circle*, which spans multiple divisions, but
// consumers/schedules only carry `division`/`sub_division` columns — there's
// no `circle` field to filter by. Until the backend schema adds one, SE
// (and ADMIN) intentionally see unfiltered division-wide data here; this is
// a known gap to close on the backend, not something the frontend can fix
// alone.
// =============================================================================

import '../models/user_model.dart';

class ScopeDefaults {
  final String? division;
  final String? subDivision;

  /// One entry per sub-division this user supervises. Empty for
  /// division/circle/region/national-scoped users. For a single-sub-division
  /// SDO this is a singleton list equal to [subDivision]; for a multi-area
  /// SDO it has 2+ entries and [subDivision] itself is left null (there is
  /// no single value to filter by — see [mergeAcrossSubDivisions]).
  final List<String> subDivisions;

  const ScopeDefaults({this.division, this.subDivision, this.subDivisions = const []});

  factory ScopeDefaults.forUser(UserModel user) {
    switch (user.scope) {
      case GeographicScope.subDivision:
        // Covers both M&T and SDO. M&T's own-tasks scoping is already
        // enforced server-side regardless of filters sent, so splitting
        // multi-value scope_name is a no-op for them; for SDO it's the
        // actual restriction.
        final parts = user.scopeName
            .split(RegExp(r'[,;]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (parts.length > 1) {
          return ScopeDefaults(subDivisions: parts);
        }
        return ScopeDefaults(subDivision: user.scopeName, subDivisions: [user.scopeName]);
      case GeographicScope.division:
        return ScopeDefaults(division: user.scopeName);
      case GeographicScope.circle:
      case GeographicScope.region:
      case GeographicScope.national:
      case GeographicScope.unassigned:
        return const ScopeDefaults();
    }
  }

  bool get isMultiSubDivision => subDivisions.length > 1;

  bool get isScoped => division != null || subDivision != null || subDivisions.isNotEmpty;

  /// Human-readable current scope, for the "Showing data for ..." labels
  /// every scoped screen displays.
  String? get label {
    if (isMultiSubDivision) return subDivisions.join(', ');
    return subDivision ?? division;
  }
}

/// When [scope] covers more than one sub-division, calls [fetchOne] for each
/// and flattens the results into a single list — returns null when the user
/// has a single (or no) sub-division scope, signaling the caller should fall
/// back to one ordinary fetch using scope.division/scope.subDivision
/// directly. Every multi-area SDO screen follows this exact pattern:
///
/// ```dart
/// final merged = mergeAcrossSubDivisions<Foo>(
///   scope,
///   fetchOne: (sd) async => (await repo.list(subDivision: sd)).items,
/// );
/// final items = merged != null
///     ? await merged
///     : (await repo.list(division: scope.division, subDivision: scope.subDivision)).items;
/// ```
Future<List<T>>? mergeAcrossSubDivisions<T>(
  ScopeDefaults scope, {
  required Future<List<T>> Function(String subDivision) fetchOne,
}) {
  if (!scope.isMultiSubDivision) return null;
  return Future.wait(scope.subDivisions.map(fetchOne)).then((lists) => lists.expand((l) => l).toList());
}
