import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../providers/dispute_provider.dart';

class FileDisputeScreen extends ConsumerStatefulWidget {
  final String transactionId;
  final int transactionAmount;
  final String transactionCurrency;
  final String? recipientName;

  const FileDisputeScreen({
    super.key,
    required this.transactionId,
    required this.transactionAmount,
    required this.transactionCurrency,
    this.recipientName,
  });

  @override
  ConsumerState<FileDisputeScreen> createState() => _FileDisputeScreenState();
}

class _FileDisputeScreenState extends ConsumerState<FileDisputeScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _issueType = 'money_sent_not_received';
  bool _feeAcknowledged = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, String> _issueTypes(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return {
      'money_sent_not_received': l10n.fileDisputeIssueTypeMoneySentNotReceived,
      'service_not_delivered': l10n.fileDisputeIssueTypeServiceNotDelivered,
      'item_not_delivered': l10n.fileDisputeIssueTypeItemNotDelivered,
      'other': l10n.fileDisputeIssueTypeOther,
    };
  }

  @override
  void initState() {
    super.initState();
    _amountController.text = (widget.transactionAmount / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      setState(() => _errorMessage = l10n.fileDisputeErrorDescriptionTooShort);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = l10n.fileDisputeErrorInvalidAmount);
      return;
    }
    final maxAmount = widget.transactionAmount / 100;
    if (amount > maxAmount) {
      setState(() => _errorMessage = l10n.fileDisputeErrorAmountExceedsMax(maxAmount.toStringAsFixed(2)));
      return;
    }
    if (!_feeAcknowledged) {
      setState(() => _errorMessage = l10n.fileDisputeErrorFeeNotAcknowledged);
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final service = ref.read(disputeServiceProvider);
      final idempotencyKey = 'dsp_${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(999999).toString().padLeft(6, '0')}';
      final result = await service.fileDispute(
        originalTransactionId: widget.transactionId,
        disputedAmount: (amount * 100).round().toDouble(),
        issueType: _issueType,
        description: description,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fileDisputeSuccessSnackbar(result['disputeId'].toString())),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fileDisputeTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.fileDisputeTransactionLabel(widget.transactionId),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.recipientName != null) ...[
                const SizedBox(height: 4),
                Text(l10n.fileDisputeRecipientLabel(widget.recipientName!), style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 20),

              Text(l10n.fileDisputeIssueTypeLabel, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _issueType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _issueTypes(context).entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _issueType = v ?? _issueType),
              ),
              const SizedBox(height: 20),

              Text(l10n.fileDisputeAmountLabel(widget.transactionCurrency), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.fileDisputeAmountHint((widget.transactionAmount / 100).toStringAsFixed(2)),
                ),
              ),
              const SizedBox(height: 20),

              Text(l10n.fileDisputeDescriptionLabel, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.fileDisputeDescriptionHint,
                ),
              ),
              const SizedBox(height: 16),

              CheckboxListTile(
                value: _feeAcknowledged,
                onChanged: (v) => setState(() => _feeAcknowledged = v ?? false),
                title: Text(
                  l10n.fileDisputeFeeAcknowledgement,
                  style: const TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.fileDisputeSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
