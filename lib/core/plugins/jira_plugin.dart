import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnicontext/core/plugins/omni_plugin.dart';

class JiraPlugin implements OmniPlugin {
  @override
  String get id => 'core.jira';

  @override
  String get name => 'Jira';

  @override
  IconData get icon => Icons.confirmation_number;

  @override
  Widget buildPanel(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'JIRA TICKET',
                style: GoogleFonts.orbitron(
                  color: Colors.white30,
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'COMING SOON',
                style: GoogleFonts.orbitron(fontSize: 8, color: Colors.white38),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: 0.5,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.confirmation_number,
                  size: 12,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Text(
                  'PROJ-123',
                  style: GoogleFonts.firaCode(
                    color: Colors.white30,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<String> generateContext(String projectPath) async {
    // Return empty for now as it's a placeholder
    return '';
  }
}
