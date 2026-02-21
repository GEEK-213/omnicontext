import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:omnicontext/core/services/vector_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A full-page settings screen pushed as a route (or shown as a dialog-sheet).
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  static const _driftIntervals = [10, 30, 60]; // seconds
  static const _driftLabels = ['10s', '30s', '60s'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── State ───────────────────────────────────────────────────────────────
    final selectedModel = useState<String>('qwen2.5-coder:3b');
    final driftInterval = useState<int>(30);
    final deepScanLimit = useState<double>(10.0);
    final isClearingDb = useState(false);
    final snackMsg = useState<String?>(null);

    // ── Load saved prefs once ────────────────────────────────────────────────
    useEffect(() {
      SharedPreferences.getInstance().then((prefs) {
        selectedModel.value =
            prefs.getString('ollama_model') ?? 'qwen2.5-coder:3b';
        driftInterval.value = prefs.getInt('drift_interval_secs') ?? 30;
        deepScanLimit.value = prefs.getDouble('deep_scan_limit') ?? 10.0;
      });
      return null;
    }, const []);

    Future<void> saveAndClose() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ollama_model', selectedModel.value);
      await prefs.setInt('drift_interval_secs', driftInterval.value);
      await prefs.setDouble('deep_scan_limit', deepScanLimit.value);
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
                      value: selectedModel.value,
                      items: const ['qwen2.5-coder:3b', 'qwen2.5-coder:1.5b'],
                      onChanged: (v) => selectedModel.value = v!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Models must be installed in your local Ollama instance.',
                style: GoogleFonts.roboto(color: Colors.white24, fontSize: 11),
              ),
            ]),

            // ── Deep Scan Limit ──────────────────────────────────────────────
            ...section('DEEP SCAN FILE LIMIT', [
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: deepScanLimit.value,
                        min: 5,
                        max: 50,
                        divisions: 45,
                        activeColor: const Color(0xFF00E5FF),
                        inactiveColor: Colors.white10,
                        label: deepScanLimit.value.round().toString(),
                        onChanged: (v) => deepScanLimit.value = v,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${deepScanLimit.value.round()}',
                      style: GoogleFonts.firaCode(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Maximum files processed during a Deep Scan. Higher limits use more memory.',
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
