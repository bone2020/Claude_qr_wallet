import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../providers/dispute_provider.dart';
import 'package:qr_wallet/generated/l10n/app_localizations.dart';

class DisputeDetailScreen extends ConsumerStatefulWidget {
  final String disputeId;
  const DisputeDetailScreen({super.key, required this.disputeId});

  @override
  ConsumerState<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  Map<String, dynamic>? _dispute;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDispute();
  }

  Future<void> _loadDispute() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(disputeServiceProvider);
      final result = await service.viewDispute(widget.disputeId);
      if (!mounted) return;
      setState(() { _dispute = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.disputeId, style: const TextStyle(fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: AppColors.error))))
              : _dispute == null
                  ? Center(child: Text(AppLocalizations.of(context).disputeNotFoundError))
                  : RefreshIndicator(
                      onRefresh: _loadDispute,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _statusBadge(_dispute!['status'] ?? 'unknown'),
                          const SizedBox(height: 20),
                          _infoTile('Issue Type', _dispute!['issueType'] ?? ''),
                          _infoTile('Amount', '${_dispute!['disputedCurrency'] ?? ''} ${((_dispute!['disputedAmount'] ?? 0) / 100).toStringAsFixed(2)}'),
                          _infoTile('Fee Charged', '\$${(_dispute!['feeCharged'] ?? 0).toStringAsFixed(2)} USD'),
                          _infoTile('Hold Amount', '${((_dispute!['currentHoldAmount'] ?? 0) / 100).toStringAsFixed(2)}'),
                          const Divider(height: 32),
                          Text(AppLocalizations.of(context).descriptionLabel, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text(_dispute!['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                          if (_dispute!['recipientResponse'] != null) ...[
                            const Divider(height: 32),
                            Text(AppLocalizations.of(context).recipientResponseLabel, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Text(_dispute!['recipientResponse'], style: Theme.of(context).textTheme.bodyMedium),
                          ],
                          if (_dispute!['resolutionType'] != null) ...[
                            const Divider(height: 32),
                            _infoTile('Resolution', _dispute!['resolutionType']),
                            if (_dispute!['amountRecovered'] != null)
                              _infoTile('Amount Recovered', '${((_dispute!['amountRecovered'] ?? 0) / 100).toStringAsFixed(2)}'),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'filed':
        color = Colors.orange;
        label = 'Submitted';
        break;
      case 'investigating':
      case 'supervisor_review':
      case 'manager_review':
        color = AppColors.primary;
        label = 'Under Review';
        break;
      case 'super_admin_escalation':
        color = AppColors.error;
        label = 'Escalated';
        break;
      case 'resolved':
        color = AppColors.success;
        label = 'Resolved';
        break;
      case 'closed_stuck':
        color = Colors.grey;
        label = 'Closed';
        break;
      default:
        color = AppColors.primary;
        label = status;
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
