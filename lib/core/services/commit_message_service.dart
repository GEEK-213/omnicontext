import 'package:omnicontext/core/services/ai_summarizer_service.dart';
import 'package:omnicontext/core/services/git_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'commit_message_service.g.dart';

@Riverpod(keepAlive: true)
class CommitMessageService extends _$CommitMessageService {
  @override
  void build() {}

  /// Generates a commit message using `git diff --cached` and the AI Summarizer (Ollama)
  Future<String> generateCommitMessage(String projectPath) async {
    final gitService = ref.read(gitServiceProvider);
    final aiSummarizer = ref.read(aiSummarizerProvider.notifier);

    try {
      // 1. Get staged changes
      final diff = await gitService.getStagedDiff(projectPath);

      if (diff.trim().isEmpty) {
        return 'No staged changes found. Run `git add` first.';
      }

      // 2. Build prompt for Ollama
      final prompt =
          '''
You are an expert developer. I am going to provide you with the output of `git diff --cached`.
Please generate a clear, concise Conventional Commit message based ONLY on these changes.
Do not provide any explanations, greetings, or markdown formatting blocks. Just the raw commit message.
Format:
<type>(<scope>): <subject>

<body>

<footer (optional)>

GIT DIFF CACHED:
$diff
''';

      // 3. Request generation
      final result = await aiSummarizer.generateRaw(prompt);

      return result.trim();
    } catch (e) {
      return 'Error generating commit message: $e';
    }
  }
}
