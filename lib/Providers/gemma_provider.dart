import 'dart:async';
import 'package:ai_kit/ai_kit.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// A provider that uses the flutter_gemma package for on-device inference.
class GemmaProvider implements AIProvider {
  final String _defaultModel = 'gemma-2b-it';

  @override
  String get name => 'Flutter Gemma';

  @override
  String get defaultModel => _defaultModel;

  @override
  List<String> get availableModels => ['gemma-2b-it', 'gemma-2b'];

  @override
  Future<bool> get isReady async {
    return FlutterGemma.hasActiveModel();
  }

  @override
  Future<AIResponse> complete(String prompt, {AIRequestConfig? config}) async {
    final model = await FlutterGemma.getActiveModel();
    final session = await model.createSession();
    await session.addQueryChunk(Message(text: prompt, isUser: true));
    final response = await session.getResponse();
    return AIResponse(
      text: response,
      isComplete: true,
      provider: name,
      model: _defaultModel,
    );
  }

  @override
  Future<AIResponse> chat(
    List<AIMessage> messages, {
    AIRequestConfig? config,
    List<AIFunction>? functions,
  }) async {
    final model = await FlutterGemma.getActiveModel();
    final chat = await model.createChat();
    for (var m in messages) {
       await chat.addQuery(Message(text: m.content, isUser: m.role == AIRole.user));
    }
    final response = await chat.generateChatResponse();
    
    String text = '';
    if (response is TextResponse) {
       text = response.token;
    }

    return AIResponse(
      text: text,
      isComplete: true,
      provider: name,
      model: _defaultModel,
    );
  }

  @override
  Stream<AIResponse> chatStream(
    List<AIMessage> messages, {
    AIRequestConfig? config,
    List<AIFunction>? functions,
  }) async* {
    final model = await FlutterGemma.getActiveModel();
    final chat = await model.createChat();
    for (var m in messages) {
       await chat.addQuery(Message(text: m.content, isUser: m.role == AIRole.user));
    }

    final stream = chat.generateChatResponseAsync();

    String fullText = '';
    await for (final response in stream) {
      if (response is TextResponse) {
         fullText += response.token;
         yield AIResponse(
           text: fullText,
           isComplete: false,
           provider: name,
           model: _defaultModel,
         );
      }
    }
    yield AIResponse(
      text: fullText,
      isComplete: true,
      provider: name,
      model: _defaultModel,
    );
  }

  @override
  Stream<AIResponse> completeStream(String prompt, {AIRequestConfig? config}) async* {
    final model = await FlutterGemma.getActiveModel();
    final session = await model.createSession();
    await session.addQueryChunk(Message(text: prompt, isUser: true));

    final stream = session.getResponseAsync();

    String fullText = '';
    await for (final chunk in stream) {
      fullText += chunk;
      yield AIResponse(
        text: fullText,
        isComplete: false,
        provider: name,
        model: _defaultModel,
      );
    }
    yield AIResponse(
      text: fullText,
      isComplete: true,
      provider: name,
      model: _defaultModel,
    );
  }

  @override
  int estimateTokens(String text) => (text.length / 4).ceil();

  @override
  void cancel() {
  }

  @override
  void dispose() {
  }
}
