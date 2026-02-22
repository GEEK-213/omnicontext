import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The core interface that all OmniContext integrations (Plugins) must implement.
abstract class OmniPlugin {
  /// A unique developer identifier for this plugin (e.g., 'omni.figma').
  String get id;

  /// The human-readable name of the plugin (e.g., 'Figma').
  String get name;

  /// The icon representing the plugin in the UI.
  IconData get icon;

  /// Renders the plugin's configuration or status UI inside the Integrations sidebar.
  Widget buildPanel(BuildContext context, WidgetRef ref);

  /// Called when the user clicks 'Generate Context'.
  /// The plugin should fetch and format any relevant data (e.g. Jira tickets, Figma frames)
  /// to be appended to the Ollama system prompt.
  /// If the plugin is inactive or has no data, it should return an empty string.
  Future<String> generateContext(String projectPath);
}
