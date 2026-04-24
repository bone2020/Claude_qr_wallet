import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
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

  static const _issueTypes = {
    'money_sent_not_received': 'Money sent but not received',
    'service_not_delivered': 'Service not delivered',
    'item_not_delivered': 'Item not delivered',
    'other': 'Other',
  };

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
    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      setState(() => _errorMessage = 'Description must be at least 10 characters.');
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }
    final maxAmount = widget.transactionAmount / 100;
    if (amount > maxAmount) {
      setState(() => _errorMessage = 'Amount cannot exceed ${maxAmount.toStringAsFixed(2)}.');
      return;
    }
    if (!_feeAcknowledged) {
      setState(() => _errorMessage = 'Please acknowledge the dispute fee.');
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
          content: Text('Dispute filed: ${result['disputeId']}'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
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
                'Transaction: ${widget.transactionId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.recipientName != null) ...[
                const SizedBox(height: 4),
                Text('To: ${widget.recipientName}', style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 20),

              Text('Issue Type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _issueType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _issueTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _issueType = v ?? _issueType),
              ),
              const SizedBox(height: 20),

              Text('Amount in Dispute (${widget.transactionCurrency})', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Max: ${(widget.transactionAmount / 100).toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(height: 20),

              Text('Description', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Describe what happened (min 10 characters)...',
                ),
              ),
              const SizedBox(height: 16),

              CheckboxListTile(
                value: _feeAcknowledged,
                onChanged: (v) => setState(() => _feeAcknowledged = v ?? false),
                title: const Text(
                  'I understand a dispute fee will be charged. It will be refunded if the dispute is upheld.',
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
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
                    : const Text('Submit Dispute'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
