import 'package:flutter_test/flutter_test.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

void main() {
  test('ContextGeneratorService generates prompt', () async {
    final container = ProviderContainer();
    final service = container.read(contextGeneratorServiceProvider);

    final projectPath = Directory.current.path;
    print('Generating context for: $projectPath');

    final prompt = await service.generateContextPrompt(projectPath);
    print('Generated Prompt:\n$prompt');

    expect(prompt, contains('ACTIVE CONTEXT:'));
    expect(prompt, contains('Project Path:'));
    expect(prompt, contains('Git Branch:'));
    expect(prompt, contains('System: Windows 11'));
  });
}
