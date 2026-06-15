import 'dart:async';
import 'package:ai_kit/ai_kit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// A provider that automatically switches between an online provider
/// and an offline provider based on network connectivity.
class HybridProvider implements AIProvider {
  final AIProvider onlineProvider;
  final AIProvider offlineProvider;

  HybridProvider({
    required this.onlineProvider,
    required this.offlineProvider,
  });

  @override
  String get name => 'Hybrid (${onlineProvider.name} / ${offlineProvider.name})';

  @override
  String get defaultModel => onlineProvider.defaultModel;

  @override
  List<String> get availableModels => [
        ...onlineProvider.availableModels,
        ...offlineProvider.availableModels,
      ];

  @override
  Future<bool> get isReady async {
    final onlineReady = await onlineProvider.isReady;
    final offlineReady = await offlineProvider.isReady;
    return onlineReady || offlineReady;
  }

  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }

  @override
  Future<AIResponse> complete(String prompt, {AIRequestConfig? config}) async {
    if (await _isOnline()) {
      try {
        return await onlineProvider.complete(prompt, config: config);
      } catch (e) {
        debugPrint('Online provider failed, falling back to offline: $e');
        return await offlineProvider.complete(prompt, config: config);
      }
    } else {
      return await offlineProvider.complete(prompt, config: config);
    }
  }

  @override
  Future<AIResponse> chat(
    List<AIMessage> messages, {
    AIRequestConfig? config,
    List<AIFunction>? functions,
  }) async {
    if (await _isOnline()) {
      try {
        return await onlineProvider.chat(
          messages,
          config: config,
          functions: functions,
        );
      } catch (e) {
        debugPrint('Online provider failed, falling back to offline: $e');
        return await offlineProvider.chat(
          messages,
          config: config,
          functions: functions,
        );
      }
    } else {
      return await offlineProvider.chat(
        messages,
        config: config,
        functions: functions,
      );
    }
  }

  @override
  Stream<AIResponse> chatStream(
    List<AIMessage> messages, {
    AIRequestConfig? config,
    List<AIFunction>? functions,
  }) async* {
    if (await _isOnline()) {
      bool failed = false;
      try {
        yield* onlineProvider.chatStream(
          messages,
          config: config,
          functions: functions,
        );
      } catch (e) {
        debugPrint('Online provider stream failed: $e');
        failed = true;
      }
      if (failed) {
        // Fallback to offline stream if online fails initially
        yield* offlineProvider.chatStream(
          messages,
          config: config,
          functions: functions,
        );
      }
    } else {
      yield* offlineProvider.chatStream(
        messages,
        config: config,
        functions: functions,
      );
    }
  }

  @override
  Stream<AIResponse> completeStream(String prompt, {AIRequestConfig? config}) async* {
    if (await _isOnline()) {
      bool failed = false;
      try {
        yield* onlineProvider.completeStream(prompt, config: config);
      } catch (e) {
        debugPrint('Online provider stream failed: $e');
        failed = true;
      }
      if (failed) {
        yield* offlineProvider.completeStream(prompt, config: config);
      }
    } else {
      yield* offlineProvider.completeStream(prompt, config: config);
    }
  }

  @override
  int estimateTokens(String text) {
    // Both providers likely have similar token estimations. Let's use online by default.
    return onlineProvider.estimateTokens(text);
  }

  @override
  void cancel() {
    onlineProvider.cancel();
    offlineProvider.cancel();
  }

  @override
  void dispose() {
    onlineProvider.dispose();
    offlineProvider.dispose();
  }
}
