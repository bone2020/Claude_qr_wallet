import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../providers/dispute_provider.dart';
import 'package:qr_wallet/generated/l10n/app_localizations.dart';

// Phase 5c-B status grouping
const _activeStatuses = {
  'filed',
  'investigating',
  'supervisor_review',
  'manager_review',
  'super_admin_escalation',
};
const _resolvedStatuses = {
  'resolved',
  'closed_stuck',
};

const _serverLimitPerCall = 50;

// Phase 5c-B status labels (user-facing)
String disputeStatusLabel(String status) {
  switch (status) {
    case 'filed':
      return 'Submitted';
    case 'investigating':
    case 'supervisor_review':
    case 'manager_review':
      return 'Under Review';
    case 'super_admin_escalation':
      return 'Escalated';
    case 'resolved':
      return 'Resolved';
    case 'closed_stuck':
      return 'Closed';
    default:
      return status;
  }
}

Color disputeStatusColor(String status) {
  switch (status) {
    case 'filed':
      return Colors.orange;
    case 'investigating':
    case 'supervisor_review':
    case 'manager_review':
      return AppColors.primary;
    case 'super_admin_escalation':
      return AppColors.error;
    case 'resolved':
      return AppColors.success;
    case 'closed_stuck':
      return Colors.grey;
    default:
      return AppColors.primary;
  }
}

class MyDisputesScreen extends ConsumerStatefulWidget {
  const MyDisputesScreen({super.key});

  @override
  ConsumerState<MyDisputesScreen> createState() => _MyDisputesScreenState();
}

class _MyDisputesScreenState extends ConsumerState<MyDisputesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _outerTabController;

  // Buckets after fetch + client-side classification
  List<Map<String, dynamic>> _filerActive = [];
  List<Map<String, dynamic>> _filerResolved = [];
  List<Map<String, dynamic>> _recipientActive = [];
  List<Map<String, dynamic>> _recipientResolved = [];

  // Was the role-level fetch capped at 50?
  bool _filerHitCap = false;
  bool _recipientHitCap = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _outerTabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _outerTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(disputeServiceProvider);

      // Phase 5c-B Strategy W: 2 calls per screen load, no status filter.
      // Bucket client-side into Active/Resolved using _activeStatuses set.
      // Limit is 50 per call (server cap); display warning if either hits 50.
      final results = await Future.wait([
        service.getMyDisputes(role: 'filer'),
        service.getMyDisputes(role: 'recipient'),
      ]);

      final filerAll = results[0];
      final recipientAll = results[1];

      final filerActive = <Map<String, dynamic>>[];
      final filerResolved = <Map<String, dynamic>>[];
      final recipientActive = <Map<String, dynamic>>[];
      final recipientResolved = <Map<String, dynamic>>[];

      for (final d in filerAll) {
        final status = (d['status'] ?? '') as String;
        if (_activeStatuses.contains(status)) {
          filerActive.add(d);
        } else if (_resolvedStatuses.contains(status)) {
          filerResolved.add(d);
        }
        // Unknown statuses fall through — not displayed in either tab,
        // but don't crash. Forward-compat for future status additions.
      }
      for (final d in recipientAll) {
        final status = (d['status'] ?? '') as String;
        if (_activeStatuses.contains(status)) {
          recipientActive.add(d);
        } else if (_resolvedStatuses.contains(status)) {
          recipientResolved.add(d);
        }
      }

      // Server returns sorted by filedAt desc; bucket order preserved.

      if (!mounted) return;
      setState(() {
        _filerActive = filerActive;
        _filerResolved = filerResolved;
        _recipientActive = recipientActive;
        _recipientResolved = recipientResolved;
        _filerHitCap = filerAll.length >= _serverLimitPerCall;
        _recipientHitCap = recipientAll.length >= _serverLimitPerCall;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).myDisputesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _outerTabController,
          tabs: [
            Tab(text: AppLocalizations.of(context).filedByMeTab),
            Tab(text: AppLocalizations.of(context).againstMeTab),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ),
                )
              : TabBarView(
                  controller: _outerTabController,
                  children: [
                    _NestedActiveResolvedTabs(
                      activeList: _filerActive,
                      resolvedList: _filerResolved,
                      hitCap: _filerHitCap,
                      emptyActiveMessage: AppLocalizations.of(context).noActiveDisputesFiled,
                      emptyResolvedMessage: AppLocalizations.of(context).noResolvedDisputes,
                      onRefresh: _loadAll,
                    ),
                    _NestedActiveResolvedTabs(
                      activeList: _recipientActive,
                      resolvedList: _recipientResolved,
                      hitCap: _recipientHitCap,
                      emptyActiveMessage: AppLocalizations.of(context).noActiveDisputesAgainstYou,
                      emptyResolvedMessage: AppLocalizations.of(context).noResolvedDisputes,
                      onRefresh: _loadAll,
                    ),
                  ],
                ),
    );
  }
}

class _NestedActiveResolvedTabs extends StatelessWidget {
  final List<Map<String, dynamic>> activeList;
  final List<Map<String, dynamic>> resolvedList;
  final bool hitCap;
  final String emptyActiveMessage;
  final String emptyResolvedMessage;
  final Future<void> Function() onRefresh;

  const _NestedActiveResolvedTabs({
    required this.activeList,
    required this.resolvedList,
    required this.hitCap,
    required this.emptyActiveMessage,
    required this.emptyResolvedMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              tabs: [
                Tab(text: AppLocalizations.of(context).activeTabWithCount(activeList.length)),
                Tab(text: AppLocalizations.of(context).resolvedTabWithCount(resolvedList.length)),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
            ),
          ),
          if (hitCap)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withOpacity(0.1),
              child: Text(
                AppLocalizations.of(context).disputesCappedNotice,
                style: TextStyle(color: Colors.orange[800], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: TabBarView(
              children: [
                _DisputeList(disputes: activeList, emptyMessage: emptyActiveMessage, onRefresh: onRefresh),
                _DisputeList(disputes: resolvedList, emptyMessage: emptyResolvedMessage, onRefresh: onRefresh),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisputeList extends StatelessWidget {
  final List<Map<String, dynamic>> disputes;
  final String emptyMessage;
  final Future<void> Function() onRefresh;

  const _DisputeList({
    required this.disputes,
    required this.emptyMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (disputes.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: disputes.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final d = disputes[index];
          final status = (d['status'] ?? 'unknown') as String;
          final disputeId = (d['disputeId'] ?? '') as String;
          final filedAt = d['filedAt'];
          String timeStr = '';
          if (filedAt != null && filedAt is Map && filedAt['_seconds'] != null) {
            timeStr = timeago.format(DateTime.fromMillisecondsSinceEpoch((filedAt['_seconds'] as int) * 1000));
          }
          final color = disputeStatusColor(status);
          return ListTile(
            title: Text(
              disputeId,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${d['issueType'] ?? ''} • ${d['disputedCurrency'] ?? ''} ${(((d['disputedAmount'] ?? 0) as num) / 100).toStringAsFixed(2)}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    disputeStatusLabel(status),
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
            // Phase 5c-B: path parameter URL (was: extra: disputeId)
            onTap: () => context.push('${AppRoutes.disputeDetail}/$disputeId'),
          );
        },
      ),
    );
  }
}
