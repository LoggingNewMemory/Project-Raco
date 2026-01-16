import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'onBoot': results[1].stdout.toString().contains('Binaries/HamadaAI'),
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

  // Config states
  bool _powersaveScreenOff = true;
  String _normalLoop = "5";
  String _offLoop = "7";
  bool _loadingConfig = true;

  bool _isTogglingProcess = false;
  bool _isTogglingBoot = false;
  bool _isSavingConfig = false;

  final String _serviceFilePath = '/data/adb/modules/ProjectRaco/service.sh';
  final String _binaryPath = '/data/adb/modules/ProjectRaco/Binaries/HamadaAI';
  final String _configPath = '/data/ProjectRaco/raco.txt';

  String get _hamadaStartCommand => 'nohup $_binaryPath > /dev/null 2>&1 &';

  final TextEditingController _normalLoopCtrl = TextEditingController();
  final TextEditingController _offLoopCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hamadaAiEnabled = widget.initialHamadaAiEnabled;
    _hamadaStartOnBoot = widget.initialHamadaStartOnBoot;
    _loadConfig();
  }

  @override
  void dispose() {
    _normalLoopCtrl.dispose();
    _offLoopCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    if (!await checkRootAccess()) {
      setState(() => _loadingConfig = false);
      return;
    }

    try {
      final result = await runRootCommandAndWait('cat $_configPath');
      if (result.exitCode == 0) {
        final content = result.stdout.toString();
        final lines = content.split('\n');

        bool psEnabled = true; // Default 1
        String loop = "5";
        String loopOff = "7";

        for (var line in lines) {
          line = line.trim();
          if (line.startsWith('HAMADA_ENABLE_POWERSAVE=')) {
            psEnabled = line.split('=')[1].trim() == '1';
          } else if (line.startsWith('HAMADA_LOOP=')) {
            loop = line.split('=')[1].trim();
          } else if (line.startsWith('HAMADA_LOOP_OFF=')) {
            loopOff = line.split('=')[1].trim();
          }
        }

        if (mounted) {
          setState(() {
            _powersaveScreenOff = psEnabled;
            _normalLoop = loop;
            _offLoop = loopOff;
            _normalLoopCtrl.text = _normalLoop;
            _offLoopCtrl.text = _offLoop;
          });
        }
      }
    } catch (e) {
      // debugPrint('Error reading raco.txt: $e');
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _saveConfig({
    bool? powersave,
    String? loop,
    String? loopOff,
  }) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isSavingConfig = true);

    try {
      // 1. Read existing
      final readRes = await runRootCommandAndWait('cat $_configPath');
      String content = "";
      if (readRes.exitCode == 0) {
        content = readRes.stdout.toString();
      }

      List<String> lines = content.split('\n');

      // Update values
      final newPs = powersave ?? _powersaveScreenOff;
      final newLoop = loop ?? _normalLoopCtrl.text;
      final newLoopOff = loopOff ?? _offLoopCtrl.text;

      // Helper to update or append key
      void updateKey(String key, String val) {
        int idx = lines.indexWhere((l) => l.startsWith('$key='));
        if (idx != -1) {
          lines[idx] = '$key=$val';
        } else {
          // If [HamadaAI] section exists, append there, else append end
          int secIdx = lines.indexWhere((l) => l.trim() == '[HamadaAI]');
          if (secIdx != -1) {
            lines.insert(secIdx + 1, '$key=$val');
          } else {
            lines.add('$key=$val');
          }
        }
      }

      // Ensure min value 2
      String validate(String v) {
        int? i = int.tryParse(v);
        if (i == null || i < 2) return "2";
        return v;
      }

      updateKey('HAMADA_ENABLE_POWERSAVE', newPs ? '1' : '0');
      updateKey('HAMADA_LOOP', validate(newLoop));
      updateKey('HAMADA_LOOP_OFF', validate(newLoopOff));

      // Reconstruct
      String newContent = lines.join('\n');

      // Write back
      String base64Content = base64Encode(utf8.encode(newContent));
      await runRootCommandAndWait(
        "echo '$base64Content' | base64 -d > $_configPath",
      );

      // Update local state
      if (mounted) {
        setState(() {
          _powersaveScreenOff = newPs;
          _normalLoop = validate(newLoop);
          _offLoop = validate(newLoopOff);
          // Sync text fields if validation changed values
          if (_normalLoopCtrl.text != _normalLoop)
            _normalLoopCtrl.text = _normalLoop;
          if (_offLoopCtrl.text != _offLoop) _offLoopCtrl.text = _offLoop;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
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
      'onBoot': results[1].stdout.toString().contains('Binaries/HamadaAI'),
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
        await runRootCommandFireAndForget('su -c "$_hamadaStartCommand"');
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
      lines.removeWhere((line) => line.contains(_binaryPath));

      if (enable) {
        int markerIndex = lines.indexWhere(
          (line) => line.trim() == '# HamadaAI',
        );
        if (markerIndex != -1) {
          lines.insert(markerIndex + 1, _hamadaStartCommand);
        } else {
          lines.add('# HamadaAI');
          lines.add(_hamadaStartCommand);
        }
      }

      String newContent = lines.join('\n');
      if (newContent.isNotEmpty && !newContent.endsWith('\n'))
        newContent += '\n';

      String base64Content = base64Encode(utf8.encode(newContent));
      final writeCmd =
          '''echo '$base64Content' | base64 -d > $_serviceFilePath''';
      await runRootCommandAndWait(writeCmd);

      if (mounted) setState(() => _hamadaStartOnBoot = enable);
    } catch (e) {
      if (mounted) await _refreshState();
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
    final isBusy =
        _isTogglingProcess ||
        _isTogglingBoot ||
        _isSavingConfig ||
        _loadingConfig;

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
            const Divider(),
            // --- New Config Controls ---
            SwitchListTile(
              title: Text(localization.hamada_powersave_screen_off_title),
              value: _powersaveScreenOff,
              onChanged: isBusy ? null : (val) => _saveConfig(powersave: val),
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _normalLoopCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: localization.hamada_normal_interval_title,
                      hintText: "Min 2",
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (val) => _saveConfig(loop: val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _offLoopCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: localization.hamada_screen_off_interval_title,
                      hintText: "Min 2",
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (val) => _saveConfig(loopOff: val),
                  ),
                ),
              ],
            ),
            if (!_isSavingConfig)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  localization.hamada_interval_hint,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_isSavingConfig) const LinearProgressIndicator(),
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
          maxLines: null,
          expands: true,
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

  Future<void> _editGameTxt() async {
    if (!await checkRootAccess()) {
      return;
    }
    if (!mounted) return;
    setState(() => _isBusy = true);

    String originalContent = '';
    try {
      final result = await runRootCommandAndWait('cat $_originalFilePath');

      if (result.exitCode == 0) {
        originalContent = result.stdout.toString();
      } else if (!result.stderr.toString().contains(
        'No such file or directory',
      )) {
        throw Exception('Failed to read file: ${result.stderr}');
      }

      if (!mounted) return;

      final newContent = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) =>
              GameTxtEditorPage(initialContent: originalContent),
        ),
      );

      if (newContent != null && newContent != originalContent) {
        await _saveGameTxt(newContent);
      }
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveGameTxt(String content) async {
    try {
      final base64Content = base64Encode(utf8.encode(content));
      final writeCmd = "echo '$base64Content' | base64 -d > $_originalFilePath";
      final result = await runRootCommandAndWait(writeCmd);

      if (result.exitCode != 0) {
        throw Exception('Failed to write to file: ${result.stderr}');
      }
    } catch (e) {
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
