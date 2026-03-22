import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider that watches network connectivity changes
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((result) {
    // connectivity_plus 5.x returns a single ConnectivityResult
    return result != ConnectivityResult.none;
  });
});
