import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../providers/dispute_provider.dart';

class RespondToDisputeScreen extends ConsumerStatefulWidget {
  final String disputeId;
  const RespondToDisputeScreen({super.key, required this.disputeId});

  @override
  ConsumerState<RespondToDisputeScreen> createState() => _RespondToDisputeScreenState();
}

class _RespondToDisputeScreenState extends ConsumerState<RespondToDisputeScreen> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final response = _controller.text.trim();
    if (response.length < 10) {
      setState(() => _error = l10n.respondToDisputeErrorTooShort);
      return;
    }

    setState(() { _isSubmitting = true; _error = null; });

    try {
      final service = ref.read(disputeServiceProvider);
      final key = 'rsp_${DateTime.now().millisecondsSinceEpoch}_${Random.secure().nextInt(999999).toString().padLeft(6, '0')}';
      await service.respondToDispute(
        disputeId: widget.disputeId,
        response: response,
        idempotencyKey: key,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.respondToDisputeSuccessSnackbar), backgroundColor: AppColors.success),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.respondToDisputeTitle),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.respondToDisputeIdLabel(widget.disputeId), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              Text(l10n.respondToDisputeResponseLabel, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  maxLength: 1000,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: l10n.respondToDisputeResponseHint,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.respondToDisputeSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
