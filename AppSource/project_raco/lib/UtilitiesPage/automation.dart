import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';
import 'utils.dart';

class AutomationPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const AutomationPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _AutomationPageState createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  bool _isLoading = true;
  Map<String, bool>? _hamadaAiState;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, bool>> _loadHamadaAiState() async {
    final results = await Future.wait([
      runRootCommandAndWait('pgrep -x HamadaAI'),
      runRootCommandAndWait('cat /data/adb/modules/ProjectRaco/service.sh'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('HamadaAI'),
    };
  }

  Future<void> _loadData() async {
    final hamadaState = await _loadHamadaAiState();

    if (!mounted) return;
    setState(() {
      _hamadaAiState = hamadaState;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.automation_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          HamadaAiCard(
            initialHamadaAiEnabled: _hamadaAiState?['enabled'] ?? false,
            initialHamadaStartOnBoot: _hamadaAiState?['onBoot'] ?? false,
          ),
          const GameTxtCard(),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Theme.of(context).colorScheme.background),
        if (widget.backgroundImagePath != null &&
            widget.backgroundImagePath!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: widget.backgroundBlur,
              sigmaY: widget.backgroundBlur,
            ),
            child: Opacity(
              opacity: widget.backgroundOpacity,
              child: Image.file(
                File(widget.backgroundImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.transparent);
                },
              ),
            ),
          ),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: LinearProgressIndicator(),
            ),
          )
        else
          pageContent,
      ],
    );
  }
}

class HamadaAiCard extends StatefulWidget {
  final bool initialHamadaAiEnabled;
  final bool initialHamadaStartOnBoot;

  const HamadaAiCard({
    Key? key,
    required this.initialHamadaAiEnabled,
    required this.initialHamadaStartOnBoot,
  }) : super(key: key);
  @override
  _HamadaAiCardState createState() => _HamadaAiCardState();
}

class _HamadaAiCardState extends State<HamadaAiCard>
    with AutomaticKeepAliveClientMixin {
  late bool _hamadaAiEnabled;
  late bool _hamadaStartOnBoot;
  bool _isTogglingProcess = false;
  bool _isTogglingBoot = false;

  final String _serviceFilePath = '/data/adb/modules/ProjectRaco/service.sh';
  final String _hamadaStartCommand = 'su -c /system/bin/HamadaAI';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hamadaAiEnabled = widget.initialHamadaAiEnabled;
    _hamadaStartOnBoot = widget.initialHamadaStartOnBoot;
  }

  Future<Map<String, bool>> _fetchCurrentState() async {
    if (!await checkRootAccess()) {
      return {'enabled': _hamadaAiEnabled, 'onBoot': _hamadaStartOnBoot};
    }
    final results = await Future.wait([
      runRootCommandAndWait('pgrep -x HamadaAI'),
      runRootCommandAndWait('cat $_serviceFilePath'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('HamadaAI'),
    };
  }

  Future<void> _refreshState() async {
    final state = await _fetchCurrentState();
    if (mounted) {
      setState(() {
        _hamadaAiEnabled = state['enabled'] ?? false;
        _hamadaStartOnBoot = state['onBoot'] ?? false;
      });
    }
  }

  Future<void> _toggleHamadaAI(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingProcess = true);
    try {
      if (enable) {
        await runRootCommandFireAndForget(_hamadaStartCommand);
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        await runRootCommandAndWait('killall HamadaAI');
      }
      await _refreshState();
    } finally {
      if (mounted) setState(() => _isTogglingProcess = false);
    }
  }

  Future<void> _setHamadaStartOnBoot(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingBoot = true);
    try {
      String content = (await runRootCommandAndWait(
        'cat $_serviceFilePath',
      )).stdout.toString();
      List<String> lines = content.replaceAll('\r\n', '\n').split('\n');
      lines.removeWhere((line) => line.trim() == _hamadaStartCommand);

      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }

      if (enable) {
        lines.add(_hamadaStartCommand);
      }

      String newContent = lines.join('\n');
      if (newContent.isNotEmpty && !newContent.endsWith('\n')) {
        newContent += '\n';
      }

      String base64Content = base64Encode(utf8.encode(newContent));
      final writeCmd =
          '''echo '$base64Content' | base64 -d > $_serviceFilePath''';
      final result = await runRootCommandAndWait(writeCmd);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _hamadaStartOnBoot = enable);
      } else {
        throw Exception('Failed to write to service file');
      }
    } catch (e) {
      if (mounted) {
        await _refreshState();
      }
    } finally {
      if (mounted) setState(() => _isTogglingBoot = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isBusy = _isTogglingProcess || _isTogglingBoot;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.hamada_ai,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.hamada_ai_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.hamada_ai_toggle_title),
              value: _hamadaAiEnabled,
              onChanged: isBusy ? null : _toggleHamadaAI,
              secondary: _isTogglingProcess
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.smart_toy_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(localization.hamada_ai_start_on_boot),
              value: _hamadaStartOnBoot,
              onChanged: isBusy ? null : _setHamadaStartOnBoot,
              secondary: _isTogglingBoot
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.power_settings_new),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple, full-screen text editor page.
class GameTxtEditorPage extends StatefulWidget {
  final String initialContent;

  const GameTxtEditorPage({Key? key, required this.initialContent})
    : super(key: key);

  @override
  _GameTxtEditorPageState createState() => _GameTxtEditorPageState();
}

class _GameTxtEditorPageState extends State<GameTxtEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pops the navigator, returning the current text to the previous screen.
  void _saveAndExit() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('game.txt'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save & Close',
            onPressed: _saveAndExit,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _controller,
          maxLines: null, // Allows for unlimited lines
          expands: true, // Expands to fill the available space
          keyboardType: TextInputType.multiline,
          autofocus: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Add package names, one per line...',
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
      ),
    );
  }
}

class GameTxtCard extends StatefulWidget {
  const GameTxtCard({Key? key}) : super(key: key);
  @override
  _GameTxtCardState createState() => _GameTxtCardState();
}

class _GameTxtCardState extends State<GameTxtCard>
    with AutomaticKeepAliveClientMixin {
  bool _isBusy = false;

  static const String _originalFilePath = '/data/ProjectRaco/game.txt';

  @override
  bool get wantKeepAlive => true;

  /// Reads the content of game.txt, navigates to the built-in editor,
  /// and saves the content back if it was changed.
  Future<void> _editGameTxt() async {
    if (!await checkRootAccess()) {
      // You can show a SnackBar here to inform the user about root access.
      return;
    }
    if (!mounted) return;
    setState(() => _isBusy = true);

    String originalContent = '';
    try {
      // 1. Read the original file using a root command.
      final result = await runRootCommandAndWait('cat $_originalFilePath');

      // If the file doesn't exist, we start with an empty string.
      // Otherwise, we populate with the file's content.
      if (result.exitCode == 0) {
        originalContent = result.stdout.toString();
      } else if (!result.stderr.toString().contains(
        'No such file or directory',
      )) {
        // If there's an error other than "file not found", throw it.
        throw Exception('Failed to read file: ${result.stderr}');
      }

      if (!mounted) return;

      // 2. Navigate to the editor page and wait for it to be closed.
      // The result will be the new text content, or null if nothing was returned.
      final newContent = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true, // Presents as a modal page for better UX
          builder: (context) =>
              GameTxtEditorPage(initialContent: originalContent),
        ),
      );

      // 3. If new content was returned and it's different from the original, save it.
      if (newContent != null && newContent != originalContent) {
        await _saveGameTxt(newContent);
        // Optionally show a "Saved successfully" SnackBar here.
      }
    } catch (e) {
      // Optionally show an error SnackBar here.
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Writes the given string content to the original game.txt file using root.
  Future<void> _saveGameTxt(String content) async {
    try {
      // Use Base64 to safely handle special characters, newlines, and permissions.
      final base64Content = base64Encode(utf8.encode(content));
      final writeCmd = "echo '$base64Content' | base64 -d > $_originalFilePath";
      final result = await runRootCommandAndWait(writeCmd);

      if (result.exitCode != 0) {
        throw Exception('Failed to write to file: ${result.stderr}');
      }
    } catch (e) {
      // Rethrow to be caught by the calling function's error handler.
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.edit_game_txt_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.game_txt_hint,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBusy ? null : _editGameTxt,
                icon: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note),
                label: Text(localization.edit_game_txt_title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
