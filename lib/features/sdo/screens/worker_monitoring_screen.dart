// =============================================================================
// FILE: lib/features/sdo/screens/worker_monitoring_screen.dart
// PURPOSE: SDO spec item 4 — "List of M&T workers assigned under the SDO,
// with assigned/completed/pending inspection counts." Reuses the
// team_performance breakdown already returned by GET /api/dashboard.php
// (built for the Dashboard & Analytics feature) rather than a new endpoint,
// since it already carries exactly this data, filtered by sub_division.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/models/dashboard_models.dart';

class WorkerMonitoringScreen extends StatefulWidget {
  final UserModel currentUser;
  const WorkerMonitoringScreen({super.key, required this.currentUser});

  @override
  State<WorkerMonitoringScreen> createState() => _WorkerMonitoringScreenState();
}

class _WorkerMonitoringScreenState extends State<WorkerMonitoringScreen> {
  late final DashboardRepository _repo = ApiDashboardRepository(token: widget.currentUser.token);
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  List<TeamPerformanceEntry> _workers = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<TeamPerformanceEntry> workers;
      if (_scope.isMultiSubDivision) {
        final parts = await Future.wait(
          _scope.subDivisions.map((sd) => _repo.getDashboard(subDivision: sd)),
        );
        workers = parts.expand((p) => p.teamPerformance).toList();
      } else {
        final data = await _repo.getDashboard(division: _scope.division, subDivision: _scope.subDivision);
        workers = data.teamPerformance;
      }
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  List<TeamPerformanceEntry> get _visibleWorkers {
    if (_search.trim().isEmpty) return _workers;
    final q = _search.trim().toLowerCase();
    return _workers.where((w) => w.fullName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text('Worker Monitoring'), actions: const [LogoutAction()]),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_scope.isScoped)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('Workers in ${_scope.label}', style: AppTextStyles.bodySmall),
                ),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search worker name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _visibleWorkers.isEmpty,
                onRetry: () => _load(),
              ),
              if (!_isLoading && _error == null && _visibleWorkers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Center(child: Text('No M&T workers found.', style: AppTextStyles.bodySmall)),
                ),
              ..._visibleWorkers.map((w) => _WorkerCard(worker: w)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final TeamPerformanceEntry worker;
  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    final pendingRaw = worker.assignedCount - worker.completedCount;
    final pending = pendingRaw < 0 ? 0 : pendingRaw;
    final rate = worker.completionRatePct;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(worker.fullName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15)),
              ),
              if (rate != null)
                Text('${rate.toStringAsFixed(0)}% complete', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGreen)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Metric(label: 'Assigned', value: worker.assignedCount, color: AppColors.primaryGreen),
              const SizedBox(width: AppSpacing.lg),
              _Metric(label: 'Completed', value: worker.completedCount, color: AppColors.successGreen),
              const SizedBox(width: AppSpacing.lg),
              _Metric(label: 'Pending', value: pending, color: AppColors.accentGold),
            ],
          ),
          if (worker.avgCompletionHours != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('~${worker.avgCompletionHours!.toStringAsFixed(1)}h avg time to complete', style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: AppTextStyles.headingMedium.copyWith(color: color, fontSize: 18)),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
