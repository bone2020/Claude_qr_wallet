import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
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
                          ..._buildPhase5iStateSection(context),
                          _infoTile('Issue Type', _dispute!['issueType'] ?? ''),
                          _infoTile('Amount', '${_dispute!['disputedCurrency'] ?? ''} ${((_dispute!['disputedAmount'] ?? 0) / 100).toStringAsFixed(2)}'),
                          _infoTile('Fee Charged', '\$${(_dispute!['feeCharged'] ?? 0).toStringAsFixed(2)} USD'),
                          _infoTile('Hold Amount', '${((_dispute!['currentHoldAmount'] ?? 0) / 100).toStringAsFixed(2)}'),
                          const Divider(height: 32),
                          Text(AppLocalizations.of(context).descriptionLabel, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text(_dispute!['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                          ..._buildResponseSections(context),
                          if (_dispute!['resolutionType'] != null) ...[
                            const Divider(height: 32),
                            _infoTile('Resolution', _dispute!['resolutionType']),
                            if (_dispute!['amountRecovered'] != null)
                              _infoTile('Amount Recovered', '${((_dispute!['amountRecovered'] ?? 0) / 100).toStringAsFixed(2)}'),
                          ],
                          ..._buildRespondEntry(context),
                        ],
                      ),
                    ),
    );
  }

  // Phase B: extract the recipient's response history. Prefer the new
  // recipientResponses array (post-Phase-B backend). Fall back to the legacy
  // recipientResponse single field if the array hasn't been populated yet,
  // so disputes that pre-date the backend deploy still render correctly.
  List<Map<String, dynamic>> _extractResponses() {
    final newArray = _dispute?['recipientResponses'];
    if (newArray is List && newArray.isNotEmpty) {
      return newArray
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    final legacy = _dispute?['recipientResponse'];
    if (legacy is String && legacy.isNotEmpty) {
      return [{'response': legacy}];
    }
    return [];
  }

  // Phase B: render each response as its own section with a localized label.
  // The Flutter side renders whatever the backend returns; the backend
  // enforces the cap of 2.
  List<Widget> _buildResponseSections(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final responses = _extractResponses();
    if (responses.isEmpty) return const [];

    final widgets = <Widget>[];
    for (var i = 0; i < responses.length; i++) {
      widgets.add(const Divider(height: 32));
      final label = i == 0 ? l10n.firstResponseLabel : l10n.secondResponseLabel;
      widgets.add(Text(label, style: Theme.of(context).textTheme.titleSmall));
      widgets.add(const SizedBox(height: 8));
      widgets.add(Text(
        (responses[i]['response'] as String?) ?? '',
        style: Theme.of(context).textTheme.bodyMedium,
      ));
    }
    return widgets;
  }

  // Phase B: Respond entry button at the bottom of the detail screen.
  // Visibility / state per Decisions 1, 2, 3:
  //   Decision 3 (alpha) — I am the recipient iff the backend included
  //     recipientUid in the sanitized payload. userViewDispute returns
  //     recipientUid only when the caller is the dispute's recipient.
  //   Decision 2 — button only shows while status == 'filed'. Anything
  //     past 'filed' hides the button (mirrors backend rule).
  //   Decision 1 — cap of 2 responses. Below cap: enabled, label switches
  //     'Respond' -> 'Update Response' after first response. At cap:
  //     button is still rendered but disabled, labelled 'Responded'.
  List<Widget> _buildRespondEntry(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final isRecipient = _dispute?['recipientUid'] != null;
    if (!isRecipient) return const [];

    final status = _dispute?['status'] as String? ?? '';
    if (status != 'filed') return const [];

    final responses = _extractResponses();
    final count = responses.length;

    final String label;
    final VoidCallback? onPressed;
    if (count >= 2) {
      label = l10n.respondedLabel;
      onPressed = null;
    } else {
      label = count == 0 ? l10n.respondButton : l10n.updateResponseButton;
      onPressed = () async {
        final result = await context.push(
          '${AppRoutes.respondToDispute}/${widget.disputeId}',
        );
        if (result == true && mounted) {
          _loadDispute();
        }
      };
    }

    return [
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    ];
  }

  // Phase 5i D2b: state-specific section rendered between the status badge and
  // the existing info tiles. Returns empty for legacy states so old disputes
  // display unchanged. New states render a progress card / banner / closing
  // remarks block as appropriate.
  List<Widget> _buildPhase5iStateSection(BuildContext context) {
    final status = _dispute?['status'] as String? ?? '';
    switch (status) {
      case 'solved':
        return _buildSolvedSection();
      case 'awaiting_release':
        return _buildAwaitingReleaseSection();
      case 'closed':
      case 'closed_returned':
        return _buildClosedSection();
      default:
        return const [];
    }
  }

  // Phase 5i D2b: progress card shown while the dispute is in 'solved' state
  // (decision made, money being collected into escrow). Shows the decision
  // direction, a progress bar, and "X of Y collected (N%)" text.
  List<Widget> _buildSolvedSection() {
    final inEscrow = (_dispute?['amountInEscrow'] ?? 0).toDouble();
    final owed = (_dispute?['amountOwed'] ?? 0).toDouble();
    final currency = _dispute?['disputedCurrency'] as String? ?? '';
    final direction = _dispute?['decisionDirection'] as String?;

    final progress = owed > 0 ? (inEscrow / owed).clamp(0.0, 1.0) : 0.0;
    final percentText = '${(progress * 100).toStringAsFixed(0)}%';

    String directionLabel;
    switch (direction) {
      case 'refund_to_buyer':
        directionLabel = 'Decision: Refund to buyer';
        break;
      case 'pay_to_seller':
        directionLabel = 'Decision: Payment to seller';
        break;
      default:
        directionLabel = 'Decision made — recovering funds';
    }

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              directionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$currency ${(inEscrow / 100).toStringAsFixed(2)} of $currency ${(owed / 100).toStringAsFixed(2)} collected ($percentText)',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  // Phase 5i D2b: banner shown while the dispute is in 'awaiting_release' state
  // (escrow fully collected, support is verifying with both parties before the
  // two-admin release).
  List<Widget> _buildAwaitingReleaseSection() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Funds fully collected',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Our team is verifying with both parties before final release.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  // Phase 5i D2b: terminal-state card shown for 'closed' (decision upheld,
  // money released) and 'closed_returned' (decision reversed, money returned
  // to the original payer). Renders the backend-generated closingRemarks text
  // if present, with a header that distinguishes the two outcomes.
  List<Widget> _buildClosedSection() {
    final status = _dispute?['status'] as String?;
    final remarks = _dispute?['closingRemarks'] as String?;
    final isReversed = status == 'closed_returned';

    final headerColor = isReversed ? Colors.grey : AppColors.success;
    final headerIcon = isReversed ? Icons.swap_horiz : Icons.check_circle_outline;
    final headerText = isReversed ? 'Decision reversed' : 'Dispute closed';

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: headerColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  headerText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: headerColor,
                  ),
                ),
              ],
            ),
            if (remarks != null && remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                remarks,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
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
      case 'solved':
        color = AppColors.primary;
        label = 'Decision Made';
        break;
      case 'awaiting_release':
        color = AppColors.primary;
        label = 'Awaiting Release';
        break;
      case 'resolved':
        color = AppColors.success;
        label = 'Resolved';
        break;
      case 'closed':
        color = AppColors.success;
        label = 'Closed';
        break;
      case 'closed_returned':
        color = Colors.grey;
        label = 'Reversed';
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
