import 'dart:async';
import 'package:ai_kit/ai_kit.dart';
import 'package:fllama/fllama.dart';

class QwenOfflineProvider implements AIProvider {
  final String modelPath;
  bool _isReady = false;
  double? _contextId;

  QwenOfflineProvider({required this.modelPath});

  @override
  String get name => 'QwenOffline';

  @override
  String get defaultModel => 'qwen3-4b-gguf';

  @override
  List<String> get availableModels => ['qwen3-4b-gguf'];

  @override
  Future<bool> get isReady async => _isReady;

  /// Call this to initialize the model in memory.
  Future<void> initialize() async {
    try {
      final res = await Fllama.instance()?.initContext(
        modelPath,
        nCtx: 2048, // Reduced context window to save RAM
        nThreads: 2,
      );
      if (res != null && res['contextId'] != null) {
        _contextId = (res['contextId'] as num).toDouble();
        _isReady = true;
      }
    } catch (e) {
      _isReady = false;
      print('Failed to initialize Fllama: $e');
    }
  }

  @override
  Future<AIResponse> complete(String prompt, {AIRequestConfig? config}) async {
    if (!_isReady || _contextId == null) {
      throw Exception('QwenOfflineProvider is not ready or context is null.');
    }

    final res = await Fllama.instance()?.completion(
      _contextId!,
      prompt: prompt,
      temperature: config?.temperature ?? 0.7,
      nPredict: config?.maxTokens ?? 512,
    );

    return AIResponse(
      text: res?['text'] ?? '',
      isComplete: true,
      provider: name,
    );
  }

  @override
  Future<AIResponse> chat(
    List<AIMessage> messages, {
    AIRequestConfig? config,
    List<AIFunction>? functions,
  }) async {
    final prompt = _buildChatPrompt(messages);
    return complete(prompt, config: config);
  }

  @override
  Stream<AIResponse> completeStream(
    String prompt, {
    AIRequestConfig? config,
  }) async* {
    if (!_isReady || _contextId == null) {
      throw Exception('QwenOfflineProvider is not ready.');
    }

    // Call completion but ask for realtime emission
    Fllama.instance()?.completion(
      _contextId!,
      prompt: prompt,
      temperature: config?.temperature ?? 0.7,
      nPredict: config?.maxTokens ?? 512,
      emitRealtimeCompletion: true,
    );

    final stream = Fllama.instance()?.onTokenStream?.where((event) {
      return event['contextId'] == _contextId;
    });

    if (stream != null) {
      await for (final event in stream) {
        // fllama usually emits {'token': ...}
        final token = event['token'] as String?;
        if (token != null) {
          yield AIResponse(text: token, isComplete: false, provider: name);
        }
        final isDone = event['isDone'] as bool? ?? false;
        if (isDone) {
          yield AIResponse(text: '', isComplete: true, provider: name);
          break;
        }
      }
    }
  }

  @override
  Stream<AIResponse> chatStream(
    List<AIMessage> messages, {
    AIRequestConfig? config,
    List<AIFunction>? functions,
  }) {
    final prompt = _buildChatPrompt(messages);
    return completeStream(prompt, config: config);
  }

  String _buildChatPrompt(List<AIMessage> messages) {
    // Qwen ChatML format
    final buffer = StringBuffer();
    for (var msg in messages) {
      final role = msg.role == AIRole.user ? 'user' : 'assistant';
      buffer.writeln('<|im_start|>$role');
      buffer.writeln(msg.content);
      buffer.writeln('<|im_end|>');
    }
    buffer.writeln('<|im_start|>assistant');
    return buffer.toString();
  }

  @override
  void cancel() {
    if (_contextId != null) {
      Fllama.instance()?.stopCompletion(contextId: _contextId!);
    }
  }

  @override
  void dispose() {
    if (_contextId != null) {
      Fllama.instance()?.releaseContext(_contextId!);
      _isReady = false;
    }
  }

  @override
  int estimateTokens(String text) => text.length ~/ 4;
}
