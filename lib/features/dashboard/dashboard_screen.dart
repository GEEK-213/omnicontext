import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('OmniContext Dashboard')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final service = ref.read(contextGeneratorServiceProvider);
            final projectPath = Directory.current.path;

            try {
              final prompt = await service.generateContextPrompt(projectPath);
              debugPrint(prompt);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Context generated! Check console.')),
                );
              }
            } catch (e) {
              debugPrint('Error generating context: $e');
            }
          },
          child: const Text('Generate Context'),
        ),
      ),
    );
  }
}
