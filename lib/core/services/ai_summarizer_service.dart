import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_summarizer_service.g.dart';

@Riverpod(keepAlive: true)
class AiSummarizer extends _$AiSummarizer {
  GenerativeModel? _model;

  @override
  void build() {
    // Initial state is void, waiting for configuration
  }

  void initialize(String apiKey) {
    if (apiKey.isEmpty) return;

    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  bool get isConfigured => _model != null;

  Future<String> summarizeCode(String rawCode) async {
    if (_model == null) {
      return rawCode; // Fallback if not configured
    }

    try {
      final prompt =
          '''
You are an elite Lead Engineer. Analyze the following raw code files. 
Create a concise, file-by-file summary of the architecture and logic. 
Highlight key functions, state changes, or API integrations. 
Format using markdown bullet points. 
DO NOT return the raw code, only the structural summary.

RAW CODE:
$rawCode
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text ?? 'Error: No response from AI';
    } catch (e) {
      return 'Error summarizing code: $e';
    }
  }
}
