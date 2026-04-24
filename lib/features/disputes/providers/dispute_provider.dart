import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DisputeService {
  final _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> fileDispute({
    required String originalTransactionId,
    required double disputedAmount,
    required String issueType,
    required String description,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('userFileDispute');
    final result = await callable.call({
      'originalTransactionId': originalTransactionId,
      'disputedAmount': disputedAmount,
      'issueType': issueType,
      'description': description,
      'idempotencyKey': idempotencyKey,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<List<Map<String, dynamic>>> getMyDisputes({required String role}) async {
    final callable = _functions.httpsCallable('userGetMyDisputes');
    final result = await callable.call({'role': role});
    final data = Map<String, dynamic>.from(result.data as Map);
    final list = data['disputes'] as List? ?? [];
    return list.map((d) => Map<String, dynamic>.from(d as Map)).toList();
  }

  Future<Map<String, dynamic>> viewDispute(String disputeId) async {
    final callable = _functions.httpsCallable('userViewDispute');
    final result = await callable.call({'disputeId': disputeId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return Map<String, dynamic>.from(data['dispute'] as Map);
  }

  Future<Map<String, dynamic>> respondToDispute({
    required String disputeId,
    required String response,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('userRespondToDispute');
    final result = await callable.call({
      'disputeId': disputeId,
      'response': response,
      'idempotencyKey': idempotencyKey,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}

final disputeServiceProvider = Provider<DisputeService>((ref) => DisputeService());
