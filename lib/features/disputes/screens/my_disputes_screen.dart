import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/constants.dart';
import '../providers/dispute_provider.dart';

class MyDisputesScreen extends ConsumerStatefulWidget {
  const MyDisputesScreen({super.key});

  @override
  ConsumerState<MyDisputesScreen> createState() => _MyDisputesScreenState();
}

class _MyDisputesScreenState extends ConsumerState<MyDisputesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _filedDisputes = [];
  List<Map<String, dynamic>> _receivedDisputes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDisputes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDisputes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(disputeServiceProvider);
      final results = await Future.wait([
        service.getMyDisputes(role: 'filer'),
        service.getMyDisputes(role: 'recipient'),
      ]);
      if (!mounted) return;
      setState(() {
        _filedDisputes = results[0];
        _receivedDisputes = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved': return AppColors.success;
      case 'closed_stuck': return Colors.grey;
      case 'filed': return Colors.orange;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Disputes'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Filed by Me'), Tab(text: 'Against Me')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_filedDisputes, emptyMessage: 'No disputes filed.'),
                    _buildList(_receivedDisputes, emptyMessage: 'No disputes against you.'),
                  ],
                ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> disputes, {required String emptyMessage}) {
    if (disputes.isEmpty) {
      return Center(child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium));
    }
    return RefreshIndicator(
      onRefresh: _loadDisputes,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: disputes.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final d = disputes[index];
          final status = d['status'] ?? 'unknown';
          final filedAt = d['filedAt'];
          String timeStr = '';
          if (filedAt != null && filedAt is Map && filedAt['_seconds'] != null) {
            timeStr = timeago.format(DateTime.fromMillisecondsSinceEpoch(filedAt['_seconds'] * 1000));
          }
          return ListTile(
            title: Text(d['disputeId'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${d['issueType'] ?? ''} • ${d['disputedCurrency'] ?? ''} ${((d['disputedAmount'] ?? 0) / 100).toStringAsFixed(2)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
            onTap: () => context.push('/dispute-detail', extra: d['disputeId']),
          );
        },
      ),
    );
  }
}
