import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
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
          const AppListCard(),
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

        bool psEnabled = true;
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
      // Ignore
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
      final readRes = await runRootCommandAndWait('cat $_configPath');
      String content = "";
      if (readRes.exitCode == 0) {
        content = readRes.stdout.toString();
      }

      List<String> lines = content.split('\n');

      final newPs = powersave ?? _powersaveScreenOff;
      final newLoop = loop ?? _normalLoopCtrl.text;
      final newLoopOff = loopOff ?? _offLoopCtrl.text;

      void updateKey(String key, String val) {
        int idx = lines.indexWhere((l) => l.startsWith('$key='));
        if (idx != -1) {
          lines[idx] = '$key=$val';
        } else {
          int secIdx = lines.indexWhere((l) => l.trim() == '[HamadaAI]');
          if (secIdx != -1) {
            lines.insert(secIdx + 1, '$key=$val');
          } else {
            lines.add('$key=$val');
          }
        }
      }

      String validate(String v) {
        int? i = int.tryParse(v);
        if (i == null || i < 2) return "2";
        return v;
      }

      updateKey('HAMADA_ENABLE_POWERSAVE', newPs ? '1' : '0');
      updateKey('HAMADA_LOOP', validate(newLoop));
      updateKey('HAMADA_LOOP_OFF', validate(newLoopOff));

      String newContent = lines.join('\n');

      String base64Content = base64Encode(utf8.encode(newContent));
      await runRootCommandAndWait(
        "echo '$base64Content' | base64 -d > $_configPath",
      );

      if (mounted) {
        setState(() {
          _powersaveScreenOff = newPs;
          _normalLoop = validate(newLoop);
          _offLoop = validate(newLoopOff);
          if (_normalLoopCtrl.text != _normalLoop)
            _normalLoopCtrl.text = _normalLoop;
          if (_offLoopCtrl.text != _offLoop) _offLoopCtrl.text = _offLoop;
        });
      }
    } catch (e) {
      // Ignore
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

class AppListCard extends StatelessWidget {
  const AppListCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Note: Use localization keys for "Applist" in future updates.
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
              "Applist",
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Manage apps for performance profile.",
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppListPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.apps),
                label: const Text("Open Applist"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppListPage extends StatefulWidget {
  const AppListPage({Key? key}) : super(key: key);

  @override
  _AppListPageState createState() => _AppListPageState();
}

class _AppListPageState extends State<AppListPage> {
  final String _gameTxtPath = '/data/ProjectRaco/game.txt';
  // Optional: Define a path if you want to load recommended apps from a file
  final String _databasePath = '/data/adb/modules/ProjectRaco/game_list.txt';

  bool _isLoading = true;
  List<AppInfo> _installedApps = [];
  List<AppInfo> _filteredApps = [];
  Set<String> _enabledPackages = {};
  Set<String> _recommendedPackages = {};
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. Load Recommended Database (File based, not hardcoded)
    await _loadRecommendedDb();

    // 2. Load Enabled Packages from game.txt
    await _loadEnabledPackages();

    // 3. Load Installed Apps
    await _loadInstalledApps();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _filterApps();
      });
    }
  }

  Future<void> _loadRecommendedDb() async {
    // Attempt to read a database file if it exists
    try {
      if (await checkRootAccess()) {
        final result = await runRootCommandAndWait('cat $_databasePath');
        if (result.exitCode == 0) {
          final content = result.stdout.toString();
          final lines = content.split('\n');
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty &&
                !trimmed.startsWith('#') &&
                !trimmed.startsWith('[')) {
              _recommendedPackages.add(trimmed);
            }
          }
        }
      }
    } catch (e) {
      // Fail silently or just have empty recommended list
      // debugPrint("Database load error: $e");
    }
  }

  Future<void> _loadEnabledPackages() async {
    try {
      if (!await checkRootAccess()) return;
      final result = await runRootCommandAndWait('cat $_gameTxtPath');
      if (result.exitCode == 0) {
        final content = result.stdout.toString();
        final lines = content.split('\n');
        final enabled = <String>{};
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty &&
              !trimmed.startsWith('#') &&
              !trimmed.startsWith('[')) {
            enabled.add(trimmed);
          }
        }
        _enabledPackages = enabled;
      }
    } catch (e) {
      // debugPrint("Error loading game.txt: $e");
    }
  }

  Future<void> _loadInstalledApps() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      _installedApps = apps;
    } catch (e) {
      // debugPrint("Error loading installed apps: $e");
    }
  }

  void _filterApps() {
    if (_searchQuery.isEmpty) {
      _filteredApps = List.from(_installedApps);
    } else {
      _filteredApps = _installedApps.where((app) {
        final name = app.name?.toLowerCase() ?? "";
        final pkg = app.packageName?.toLowerCase() ?? "";
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || pkg.contains(q);
      }).toList();
    }

    // Sort logic:
    // 1. Enabled (Top priority)
    // 2. Recommended (Secondary priority)
    // 3. Alphabetical
    _filteredApps.sort((a, b) {
      final pkgA = a.packageName ?? "";
      final pkgB = b.packageName ?? "";

      final bool enA = _enabledPackages.contains(pkgA);
      final bool enB = _enabledPackages.contains(pkgB);
      final bool recA = _recommendedPackages.contains(pkgA);
      final bool recB = _recommendedPackages.contains(pkgB);

      if (enA != enB) return enA ? -1 : 1;
      if (recA != recB) return recA ? -1 : 1;

      return (a.name ?? "").toLowerCase().compareTo(
        (b.name ?? "").toLowerCase(),
      );
    });
  }

  Future<void> _toggleApp(String packageName) async {
    setState(() {
      if (_enabledPackages.contains(packageName)) {
        _enabledPackages.remove(packageName);
      } else {
        _enabledPackages.add(packageName);
      }
      _filterApps(); // Re-sort to move enabled items to top if needed
    });

    try {
      final buffer = StringBuffer();
      buffer.writeln("# Generated by Applist Manager");
      buffer.writeln();

      final sortedPackages = _enabledPackages.toList()..sort();
      buffer.writeln(sortedPackages.join('\n'));

      final content = buffer.toString();
      final base64Content = base64Encode(utf8.encode(content));
      await runRootCommandAndWait(
        "echo '$base64Content' | base64 -d > $_gameTxtPath",
      );
    } catch (e) {
      // debugPrint("Error saving game.txt: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Add options like "Reload" here if needed
              _initData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _filterApps();
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final pkg = app.packageName ?? "";
                      final isEnabled = _enabledPackages.contains(pkg);
                      final isRecommended = _recommendedPackages.contains(pkg);

                      return _buildAppCard(app, isEnabled, isRecommended);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showManualAddDialog,
        backgroundColor: colorScheme.primaryContainer,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAppCard(AppInfo app, bool isEnabled, bool isRecommended) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Card(
        // Dark card color (adjust based on your theme, or use surfaceVariant)
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleApp(app.packageName ?? ""),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[800],
                    image: app.icon != null
                        ? DecorationImage(
                            image: MemoryImage(app.icon!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: app.icon == null ? const Icon(Icons.android) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name ?? "Unknown",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Enforce light text
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        app.packageName ?? "",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBadge(
                            text: isEnabled ? "ENABLED" : "DISABLED",
                            color: isEnabled
                                ? const Color(0xFF4CAF50) // Green 500
                                : const Color(0xFFE57373), // Red 300
                            bgColor: isEnabled
                                ? const Color(0xFF1B5E20) // Dark Green bg
                                : const Color(0xFF3E2723), // Dark Red bg
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            _buildBadge(
                              text: "RECOMMENDED",
                              color: const Color(0xFFF06292), // Pink 300
                              bgColor: const Color(0xFF4A1425), // Dark Pink bg
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showManualAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Package Manually'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'com.example.game',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _toggleApp(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
