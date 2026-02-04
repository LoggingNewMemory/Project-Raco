import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/l10n/app_localizations.dart';
import 'utils.dart';

class AppItem {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;
  final String? iconPath;

  AppItem({
    required this.name,
    required this.packageName,
    this.iconBytes,
    this.iconPath,
  });
}

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
  Map<String, bool>? _endfieldEngineState;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, bool>> _loadEndfieldEngineState() async {
    final results = await Future.wait([
      runRootCommandAndWait('pgrep -x Endfield'),
      runRootCommandAndWait('cat /data/adb/modules/ProjectRaco/service.sh'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('Binaries/Endfield'),
    };
  }

  Future<void> _loadData() async {
    final endfieldState = await _loadEndfieldEngineState();

    if (!mounted) return;
    setState(() {
      _endfieldEngineState = endfieldState;
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
          EndfieldEngineCard(
            initialEndfieldEngineEnabled:
                _endfieldEngineState?['enabled'] ?? false,
            initialEndfieldStartOnBoot:
                _endfieldEngineState?['onBoot'] ?? false,
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

class EndfieldEngineCard extends StatefulWidget {
  final bool initialEndfieldEngineEnabled;
  final bool initialEndfieldStartOnBoot;

  const EndfieldEngineCard({
    Key? key,
    required this.initialEndfieldEngineEnabled,
    required this.initialEndfieldStartOnBoot,
  }) : super(key: key);
  @override
  _EndfieldEngineCardState createState() => _EndfieldEngineCardState();
}

class _EndfieldEngineCardState extends State<EndfieldEngineCard>
    with AutomaticKeepAliveClientMixin {
  late bool _endfieldEngineEnabled;
  late bool _endfieldStartOnBoot;

  bool _powersaveScreenOff = true;
  bool _loadingConfig = true;

  bool _isTogglingProcess = false;
  bool _isTogglingBoot = false;
  bool _isSavingConfig = false;

  final String _serviceFilePath = '/data/adb/modules/ProjectRaco/service.sh';
  final String _binaryPath = '/data/adb/modules/ProjectRaco/Binaries/Endfield';
  final String _configPath = '/data/ProjectRaco/raco.txt';

  String get _endfieldStartCommand => 'nohup $_binaryPath > /dev/null 2>&1 &';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _endfieldEngineEnabled = widget.initialEndfieldEngineEnabled;
    _endfieldStartOnBoot = widget.initialEndfieldStartOnBoot;
    _loadConfig();
  }

  @override
  void dispose() {
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

        for (var line in lines) {
          line = line.trim();
          if (line.startsWith('ENDFIELD_ENABLE_POWERSAVE=')) {
            psEnabled = line.split('=')[1].trim() == '1';
          }
        }

        if (mounted) {
          setState(() {
            _powersaveScreenOff = psEnabled;
          });
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _saveConfig({bool? powersave}) async {
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

      void updateKey(String key, String val) {
        int idx = lines.indexWhere((l) => l.startsWith('$key='));
        if (idx != -1) {
          lines[idx] = '$key=$val';
        } else {
          int secIdx = lines.indexWhere((l) => l.trim() == '[EndfieldEngine]');
          if (secIdx != -1) {
            lines.insert(secIdx + 1, '$key=$val');
          } else {
            lines.add('$key=$val');
          }
        }
      }

      updateKey('ENDFIELD_ENABLE_POWERSAVE', newPs ? '1' : '0');

      String newContent = lines.join('\n');

      String base64Content = base64Encode(utf8.encode(newContent));
      await runRootCommandAndWait(
        "echo '$base64Content' | base64 -d > $_configPath",
      );

      if (mounted) {
        setState(() {
          _powersaveScreenOff = newPs;
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
      return {
        'enabled': _endfieldEngineEnabled,
        'onBoot': _endfieldStartOnBoot,
      };
    }
    final results = await Future.wait([
      runRootCommandAndWait('pgrep -x Endfield'),
      runRootCommandAndWait('cat $_serviceFilePath'),
    ]);
    return {
      'enabled': results[0].exitCode == 0,
      'onBoot': results[1].stdout.toString().contains('Binaries/Endfield'),
    };
  }

  Future<void> _refreshState() async {
    final state = await _fetchCurrentState();
    if (mounted) {
      setState(() {
        _endfieldEngineEnabled = state['enabled'] ?? false;
        _endfieldStartOnBoot = state['onBoot'] ?? false;
      });
    }
  }

  Future<void> _toggleEndfieldEngine(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingProcess = true);
    try {
      if (enable) {
        await runRootCommandFireAndForget('su -c "$_endfieldStartCommand"');
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        await runRootCommandAndWait('killall Endfield');
      }
      await _refreshState();
    } finally {
      if (mounted) setState(() => _isTogglingProcess = false);
    }
  }

  Future<void> _setEndfieldStartOnBoot(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isTogglingBoot = true);
    try {
      String content = (await runRootCommandAndWait(
        'cat $_serviceFilePath',
      )).stdout.toString();
      List<String> lines = content.replaceAll('\r\n', '\n').split('\n');

      // Remove any existing binary commands to prevent duplicates
      lines.removeWhere((line) => line.contains(_binaryPath));

      if (enable) {
        // Look for the exact marker '#Endfield Engine'
        int markerIndex = lines.indexWhere(
          (line) => line.trim() == '#Endfield Engine',
        );
        if (markerIndex != -1) {
          lines.insert(markerIndex + 1, _endfieldStartCommand);
        } else {
          // Fallback if marker is missing
          lines.add('#Endfield Engine');
          lines.add(_endfieldStartCommand);
        }
      }

      String newContent = lines.join('\n');
      if (newContent.isNotEmpty && !newContent.endsWith('\n')) {
        newContent += '\n';
      }

      String base64Content = base64Encode(utf8.encode(newContent));
      final writeCmd =
          '''echo '$base64Content' | base64 -d > $_serviceFilePath''';
      await runRootCommandAndWait(writeCmd);

      if (mounted) setState(() => _endfieldStartOnBoot = enable);
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
              localization.endfield_engine,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.endfield_engine_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.endfield_engine_toggle_title),
              value: _endfieldEngineEnabled,
              onChanged: isBusy ? null : _toggleEndfieldEngine,
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
              title: Text(localization.endfield_engine_start_on_boot),
              value: _endfieldStartOnBoot,
              onChanged: isBusy ? null : _setEndfieldStartOnBoot,
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
              title: Text(localization.endfield_powersave_screen_off_title),
              value: _powersaveScreenOff,
              onChanged: isBusy ? null : (val) => _saveConfig(powersave: val),
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
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
  final String _databasePath = '/data/adb/modules/ProjectRaco/game_list.txt';
  static const String _prefsKeyApps = 'applist_cached_apps';

  bool _isLoading = true;
  List<AppItem> _installedApps = [];
  List<AppItem> _filteredApps = [];
  Set<String> _enabledPackages = {};
  Set<String> _recommendedPackages = {};
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadFromCache();
    await Future.wait([_loadRecommendedDb(), _loadEnabledPackages()]);
    _fetchInstalledApps(forceRefresh: false);
  }

  Future<Directory> _getIconCacheDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final iconDir = Directory('${docsDir.path}/app_icons');
    if (!await iconDir.exists()) {
      await iconDir.create(recursive: true);
    }
    return iconDir;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? appsJson = prefs.getString(_prefsKeyApps);

      if (appsJson != null) {
        final List<dynamic> decodedList = jsonDecode(appsJson);
        final iconDir = await _getIconCacheDir();

        final List<AppItem> cachedList = decodedList.map((item) {
          final pkg = item['p'] as String;
          final path = '${iconDir.path}/$pkg.png';
          final fileExists = File(path).existsSync();

          return AppItem(
            name: item['n'] as String,
            packageName: pkg,
            iconBytes: null,
            iconPath: fileExists ? path : null,
          );
        }).toList();

        if (mounted && cachedList.isNotEmpty) {
          setState(() {
            _installedApps = cachedList;
            _isLoading = false;
            _filterApps();
          });
        }
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  Future<void> _saveToCache(List<AppItem> apps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, String>> tinyList = apps
          .map((app) => {'n': app.name, 'p': app.packageName})
          .toList();

      await prefs.setString(_prefsKeyApps, jsonEncode(tinyList));
    } catch (e) {
      debugPrint("Cache save error: $e");
    }
  }

  Future<void> _loadRecommendedDb() async {
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
      // Ignore
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
        if (mounted) {
          setState(() {
            _enabledPackages = enabled;
            if (_installedApps.isNotEmpty) _filterApps();
          });
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchInstalledApps({bool forceRefresh = false}) async {
    if (_installedApps.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      List<AppInfo> rawApps = await InstalledApps.getInstalledApps(true, true);
      final iconDir = await _getIconCacheDir();
      final List<AppItem> finalItems = [];

      for (var info in rawApps) {
        String? iconPath;
        if (info.icon != null) {
          final file = File('${iconDir.path}/${info.packageName}.png');
          try {
            if (!await file.exists() || forceRefresh) {
              await file.writeAsBytes(info.icon!, flush: true);
            }
            iconPath = file.path;
          } catch (e) {
            debugPrint("Failed to cache icon for ${info.packageName}: $e");
          }
        }

        finalItems.add(
          AppItem(
            name: info.name ?? "Unknown",
            packageName: info.packageName ?? "",
            iconBytes: info.icon,
            iconPath: iconPath,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _installedApps = finalItems;
          _isLoading = false;
          _filterApps();
        });
        _saveToCache(finalItems);
      }
    } catch (e) {
      debugPrint("Error loading installed apps: $e");
      if (mounted && _installedApps.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterApps() {
    if (_searchQuery.isEmpty) {
      _filteredApps = List.from(_installedApps);
    } else {
      _filteredApps = _installedApps.where((app) {
        final name = app.name.toLowerCase();
        final pkg = app.packageName.toLowerCase();
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || pkg.contains(q);
      }).toList();
    }

    _filteredApps.sort((a, b) {
      final pkgA = a.packageName;
      final pkgB = b.packageName;

      final bool enA = _enabledPackages.contains(pkgA);
      final bool enB = _enabledPackages.contains(pkgB);
      final bool recA = _recommendedPackages.contains(pkgA);
      final bool recB = _recommendedPackages.contains(pkgB);

      if (enA != enB) return enA ? -1 : 1;
      if (recA != recB) return recA ? -1 : 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> _toggleApp(String packageName) async {
    final bool isEnable = !_enabledPackages.contains(packageName);
    final localization = AppLocalizations.of(context)!;

    setState(() {
      if (isEnable) {
        _enabledPackages.add(packageName);
      } else {
        _enabledPackages.remove(packageName);
      }
      _filterApps();
    });

    try {
      if (isEnable) {
        // Use 'sed' append ($a) to force adding to a new line at the end of the file.
        // This ensures packages are strictly separated by newlines.
        // Note: Escape the $ with \ for Dart string interpolation.
        await runRootCommandAndWait("sed -i '\$a $packageName' $_gameTxtPath");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.added_to_gamelist(packageName)),
              duration: const Duration(milliseconds: 1000),
            ),
          );
        }
      } else {
        // Use 'sed' delete (/.../d) to remove the specific package line.
        final escapedPackage = packageName.replaceAll('.', '\\.');
        await runRootCommandAndWait(
          "sed -i '/^$escapedPackage\$/d' $_gameTxtPath",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.removed_from_gamelist(packageName)),
              duration: const Duration(milliseconds: 1000),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating game.txt: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Apps',
            onPressed: () => _fetchInstalledApps(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Menu options
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
            child: _isLoading && _installedApps.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final pkg = app.packageName;
                      final isEnabled = _enabledPackages.contains(pkg);
                      final isRecommended = _recommendedPackages.contains(pkg);

                      return _buildAppCard(app, isEnabled, isRecommended);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(AppItem app, bool isEnabled, bool isRecommended) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Card(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleApp(app.packageName),
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
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildAppIcon(app),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        app.packageName,
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
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE57373),
                            bgColor: isEnabled
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFF3E2723),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            _buildBadge(
                              text: "RECOMMENDED",
                              color: const Color(0xFFF06292),
                              bgColor: const Color(0xFF4A1425),
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

  Widget _buildAppIcon(AppItem app) {
    if (app.iconPath != null) {
      return Image.file(
        File(app.iconPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.android, color: Colors.white54),
      );
    }
    if (app.iconBytes != null) {
      return Image.memory(app.iconBytes!, fit: BoxFit.cover);
    }
    return const Icon(Icons.android, color: Colors.white54);
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
}
