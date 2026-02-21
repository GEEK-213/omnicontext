import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_summarizer_service.g.dart';

const _ollamaGenerateUrl = 'http://localhost:11434/api/generate';
const _ollamaModel = 'qwen2.5-coder:3b';

const _systemPrompt =
    'You are an elite Lead Engineer. Analyze the following raw code. '
    'Create a concise, file-by-file summary of the architecture and logic. '
    'Format using markdown bullet points. DO NOT return raw code.';

const _driftSystemPrompt =
    'You are a Git Conflict Mediator. A developer is about to pull remote changes. '
    'Analyze the following `git diff --name-status` output and explain what changed '
    'in exactly 2 short bullet points. Keep it incredibly brief. Use plain English — '
    'no jargon. If you see patterns that suggest a potential merge conflict, add a ⚠️ warning.';

@Riverpod(keepAlive: true)
class AiSummarizer extends _$AiSummarizer {
  @override
  void build() {}

  /// No-op — kept for Settings dialog compatibility.
  void initialize(String geminiKey, {String openAiKey = ''}) {}

  /// Always true — local Ollama server requires no configuration.
  bool get isConfigured => true;

  // ---------------------------------------------------------------------------
  // Internal helper: POST to Ollama /api/generate
  // ---------------------------------------------------------------------------
  Future<String> _generate(String prompt) async {
    final body = jsonEncode({
      'model': _ollamaModel,
      'prompt': prompt,
      'stream': false,
    });

    debugPrint('🤖 [Ollama] POST → $_ollamaGenerateUrl  model=$_ollamaModel');

    try {
      final response = await http.post(
        Uri.parse(_ollamaGenerateUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final text = (decoded['response'] as String? ?? '').trim();
        debugPrint('✅ [Ollama] Response received (${text.length} chars).');
        return text.isNotEmpty ? text : 'No response from local model.';
      } else {
        debugPrint('❌ [Ollama] HTTP ${response.statusCode}: ${response.body}');
        return 'Error: Ollama returned status ${response.statusCode}.\n${response.body}';
      }
    } on SocketException {
      debugPrint('❌ [Ollama] SocketException — server not reachable.');
      return 'Error: Could not reach Ollama. Is it running?';
    } catch (e) {
      debugPrint('❌ [Ollama] Unexpected error: $e');
      return 'Error: $e';
    }
  }

  // ---------------------------------------------------------------------------
  // Code Summarizer
  // ---------------------------------------------------------------------------

  Future<String> summarizeCode(String rawCode) async {
    final prompt = '$_systemPrompt\n\nCode to summarize:\n$rawCode';
    return _generate(prompt);
  }

  // ---------------------------------------------------------------------------
  // Drift Mediator
  // ---------------------------------------------------------------------------

  Future<String> summarizeDrift(String rawGitDiff) async {
    final prompt = '$_driftSystemPrompt\n\nGIT DIFF OUTPUT:\n$rawGitDiff';
    final result = await _generate(prompt);
    // If Ollama is unreachable, append raw diff for context
    if (result.startsWith('Error:')) {
      return '$result\n\nRaw diff:\n$rawGitDiff';
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Raw Generation (For Commit Messages)
  // ---------------------------------------------------------------------------

  Future<String> generateRaw(String prompt) async {
    return _generate(prompt);
  }
}
