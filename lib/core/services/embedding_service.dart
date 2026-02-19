import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'embedding_service.g.dart';

@Riverpod(keepAlive: true)
class EmbeddingService extends _$EmbeddingService {
  GenerativeModel? _model;

  @override
  void build() {
    // Initial state is void, waiting for explicit init with key
  }

  void initialize(String apiKey) {
    if (apiKey.isEmpty) return;
    _model = GenerativeModel(
      model: 'models/gemini-embedding-001',
      apiKey: apiKey,
    );
  }

  Future<List<double>> getEmbedding(String text) async {
    if (_model == null) {
      throw Exception(
        'Gemini API Key not configured. Please set it in Settings.',
      );
    }

    try {
      final content = Content.text(text);
      final result = await _model!.embedContent(content);
      return result.embedding.values;
    } catch (e) {
      print('Embedding Error: $e');
      rethrow;
    }
  }
}
