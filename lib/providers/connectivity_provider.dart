import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider that watches network connectivity changes
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    // results is a List<ConnectivityResult>
    // User is offline only if the list contains ConnectivityResult.none
    return !results.contains(ConnectivityResult.none);
  });
});
