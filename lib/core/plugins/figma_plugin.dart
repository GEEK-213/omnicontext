import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnicontext/core/plugins/omni_plugin.dart';

// We manage the Figma URL locally in this plugin using SharedPreferences
final figmaUrlProvider = StateProvider<String>((ref) => '');

class FigmaPlugin implements OmniPlugin {
  @override
  String get id => 'core.figma';

  @override
  String get name => 'Figma';

  @override
  IconData get icon => Icons.brush; // Close enough

  @override
  Widget buildPanel(BuildContext context, WidgetRef ref) {
    final url = ref.watch(figmaUrlProvider);
    final controller = TextEditingController(text: url)
      ..selection = TextSelection.collapsed(offset: url.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FIGMA URL',
          style: GoogleFonts.orbitron(color: Colors.white30, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            onChanged: (val) {
              ref.read(figmaUrlProvider.notifier).state = val;
              // Debounce or save to SharedPreferences here if desired
            },
            style: GoogleFonts.firaCode(color: Colors.white, fontSize: 11),
            decoration: InputDecoration(
              hintText: 'Paste frame link...',
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              prefixIcon: const Icon(
                Icons.edit,
                size: 12,
                color: Colors.white30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<String> generateContext(String projectPath) async {
    // Note: To be fully self-contained, this should grab the provider without needing `ref`.
    // Final plugin will load this via SharedPreferences or similar
    // We haven't hooked saving up yet in this snippet, but this is mock behavior for now.
    // In Phase 4 we will actually resolve the Figma API.

    // For now, if the user pasted a link, we inject it into the prompt.
    // We would need a way to read the current URL inside `generateContext`.
    return 'User provided Figma Reference: [UI Link] (Not actually fetched via API yet)';
  }
}
