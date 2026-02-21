import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'template_service.g.dart';

enum ContextTemplateType {
  general,
  bugReport,
  prReview,
  architectureOverview,
  onboardingBrief,
}

class ContextTemplate {
  final String name;
  final String description;
  final ContextTemplateType type;
  final String icon;

  const ContextTemplate({
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
  });

  String apply(String rawContext) {
    switch (type) {
      case ContextTemplateType.bugReport:
        return '''
# Bug Report Context 🐛

## Issue Context Scope
The following codebase snippet has been gathered to assist in debugging the current issue. Please analyze the context and suggest potential root causes and fixes.

## Raw Context Dump
```dart
$rawContext
```
''';
      case ContextTemplateType.prReview:
        return '''
# PR Review Context 🔍

## Objective
The following snippets represent active changes or contextual files relevant to a Pull Request. Please review for best practices, potential bugs, and architectural consistency.

## Raw Context Dump
```dart
$rawContext
```
''';
      case ContextTemplateType.architectureOverview:
        return '''
# Architecture Overview 🏗️

## Objective
Analyze the provided codebase files to outline the current architectural patterns, state management, and overall structural integrity.

## Raw Context Dump
```dart
$rawContext
```
''';
      case ContextTemplateType.onboardingBrief:
        return '''
# Onboarding Brief 🚀

## Objective
Summarize the core concepts, entry points, and primary data flow of the provided codebase for a new developer joining the team.

## Raw Context Dump
```dart
$rawContext
```
''';
      case ContextTemplateType.general:
        return '''
# OmniContext Snapshot ⚡

## Raw Context Dump
```dart
$rawContext
```
''';
    }
  }
}

@riverpod
class TemplateService extends _$TemplateService {
  @override
  List<ContextTemplate> build() {
    return const [
      ContextTemplate(
        name: 'General Context',
        description: 'Standard contextual dump for open-ended AI prompting.',
        type: ContextTemplateType.general,
        icon: '⚡',
      ),
      ContextTemplate(
        name: 'Bug Report',
        description: 'Diagnose and track down elusive bugs in specific files.',
        type: ContextTemplateType.bugReport,
        icon: '🐛',
      ),
      ContextTemplate(
        name: 'PR Review',
        description: 'Lint and review codebase changes for best practices.',
        type: ContextTemplateType.prReview,
        icon: '🔍',
      ),
      ContextTemplate(
        name: 'Architecture',
        description: 'Map out the structural overview of the project setup.',
        type: ContextTemplateType.architectureOverview,
        icon: '🏗️',
      ),
      ContextTemplate(
        name: 'Onboarding',
        description: 'Onboard new devs by summarizing core domain concepts.',
        type: ContextTemplateType.onboardingBrief,
        icon: '🚀',
      ),
    ];
  }
}
