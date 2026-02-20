import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:omnicontext/core/services/vector_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A full-page settings screen pushed as a route (or shown as a dialog-sheet).
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  static const _driftIntervals = [10, 30, 60, 300]; // seconds
  static const _driftLabels = ['10s', '30s', '1 min', '5 min'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── State ───────────────────────────────────────────────────────────────
    final availableModels = useState<List<String>>([]);
    final selectedModel = useState<String>('qwen2.5-coder:3b');
    final driftInterval = useState<int>(30);
    final isLoadingModels = useState(false);
    final isClearingDb = useState(false);
    final snackMsg = useState<String?>(null);

    // ── Load saved prefs once ────────────────────────────────────────────────
    useEffect(() {
      SharedPreferences.getInstance().then((prefs) {
        selectedModel.value =
            prefs.getString('ollama_model') ?? 'qwen2.5-coder:3b';
        driftInterval.value = prefs.getInt('drift_interval_secs') ?? 30;
      });
      return null;
    }, const []);

    Future<void> fetchModels() async {
      isLoadingModels.value = true;
      try {
        final res = await http
            .get(Uri.parse('http://localhost:11434/api/tags'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final models = (body['models'] as List<dynamic>?) ?? [];
          availableModels.value = models
              .map((m) => (m as Map)['name'] as String)
              .toList();
        } else {
          snackMsg.value = 'Ollama returned ${res.statusCode}';
        }
      } catch (_) {
        snackMsg.value = 'Could not reach Ollama. Is it running?';
      } finally {
        isLoadingModels.value = false;
      }
    }

    Future<void> saveAndClose() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ollama_model', selectedModel.value);
      await prefs.setInt('drift_interval_secs', driftInterval.value);
      if (context.mounted) Navigator.of(context).pop();
    }

    // Show snack if message posted
    useEffect(() {
      if (snackMsg.value != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackMsg.value!),
            behavior: SnackBarBehavior.floating,
          ),
        );
        snackMsg.value = null;
      }
      return null;
    }, [snackMsg.value]);

    // ── Section helper ───────────────────────────────────────────────────────
    List<Widget> section(String title, List<Widget> children) {
      return [
        const SizedBox(height: 20),
        Text(
          title,
          style: GoogleFonts.orbitron(
            color: Colors.white38,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 12),
        ...children,
      ];
    }

    // ── Build ────────────────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white54,
            size: 16,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SYSTEM CONFIGURATION',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: saveAndClose,
            child: Text(
              'SAVE',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF00E5FF),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── AI Model ─────────────────────────────────────────────────────
            ...section('AI MODEL (OLLAMA)', [
              Row(
                children: [
                  Expanded(
                    child: _SettingsDropdown<String>(
                      value: availableModels.value.contains(selectedModel.value)
                          ? selectedModel.value
                          : null,
                      hint: selectedModel.value,
                      items: availableModels.value.isNotEmpty
                          ? availableModels.value
                          : [selectedModel.value],
                      onChanged: (v) => selectedModel.value = v!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isLoadingModels.value ? null : fetchModels,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      side: const BorderSide(color: Colors.cyanAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: isLoadingModels.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.cyanAccent,
                            ),
                          )
                        : Text(
                            'FETCH',
                            style: GoogleFonts.orbitron(fontSize: 10),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fetches installed models from http://localhost:11434',
                style: GoogleFonts.roboto(color: Colors.white24, fontSize: 11),
              ),
            ]),

            // ── Drift Polling ─────────────────────────────────────────────────
            ...section('GIT DRIFT POLLING', [
              _SettingsDropdown<int>(
                value: driftInterval.value,
                items: _driftIntervals,
                labels: _driftLabels,
                onChanged: (v) => driftInterval.value = v!,
              ),
              const SizedBox(height: 4),
              Text(
                'How often OmniContext runs git fetch + rev-list in the background.',
                style: GoogleFonts.roboto(color: Colors.white24, fontSize: 11),
              ),
            ]),

            // ── Vector DB ────────────────────────────────────────────────────
            ...section('VECTOR DATABASE', [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Clear the local semantic search index.\nRe-index after clearing.',
                      style: GoogleFonts.roboto(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: isClearingDb.value
                        ? null
                        : () async {
                            isClearingDb.value = true;
                            try {
                              await ref
                                  .read(vectorDbServiceProvider.future)
                                  .then(
                                    (_) => ref
                                        .read(vectorDbServiceProvider.notifier)
                                        .clear(),
                                  );
                              snackMsg.value = '✅ Vector DB cleared';
                            } catch (e) {
                              snackMsg.value = 'Error: $e';
                            } finally {
                              isClearingDb.value = false;
                            }
                          },
                    icon: isClearingDb.value
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                        : const Icon(Icons.delete_sweep, size: 16),
                    label: Text(
                      'CLEAR DB',
                      style: GoogleFonts.orbitron(fontSize: 10),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Generic dropdown widget ───────────────────────────────────────────────────

class _SettingsDropdown<T> extends StatelessWidget {
  final T? value;
  final String? hint;
  final List<T> items;
  final List<String>? labels;
  final ValueChanged<T?> onChanged;

  const _SettingsDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.labels,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint != null
              ? Text(
                  hint!,
                  style: GoogleFonts.firaCode(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                )
              : null,
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          style: GoogleFonts.firaCode(color: Colors.white, fontSize: 12),
          onChanged: onChanged,
          items: items.asMap().entries.map((e) {
            final label = labels?[e.key] ?? e.value.toString();
            return DropdownMenuItem<T>(value: e.value, child: Text(label));
          }).toList(),
        ),
      ),
    );
  }
}
