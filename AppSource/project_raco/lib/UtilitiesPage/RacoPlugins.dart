import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '/l10n/app_localizations.dart';

// =========================================================
//  DATA MODELS
// =========================================================

class RacoPluginModel {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String path;
  final bool isBootEnabled;
  final Uint8List? logoBytes;
  final String? webUiUrl;
  final bool hasActionScript;
  final bool hasWebRoot;

  RacoPluginModel({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.path,
    required this.isBootEnabled,
    this.logoBytes,
    this.webUiUrl,
    required this.hasActionScript,
    required this.hasWebRoot,
  });
}

// =========================================================
//  MAIN PLUGINS LIST PAGE
// =========================================================

class RacoPluginsPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const RacoPluginsPage({
    Key? key,
    this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _RacoPluginsPageState createState() => _RacoPluginsPageState();
}

class _RacoPluginsPageState extends State<RacoPluginsPage> {
  bool _isLoading = true;
  List<RacoPluginModel> _plugins = [];

  final String _pluginBasePath = '/data/ProjectRaco/Plugins';
  final String _pluginTxtPath = '/data/ProjectRaco/Plugin.txt';
  final String _tmpInstallPath = '/data/local/tmp/raco_plugin_install';

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  Future<String> _runRootCommand(String command) async {
    try {
      final result = await Process.run('su', ['-c', command]);
      return result.exitCode == 0 ? result.stdout.toString().trim() : '';
    } catch (e) {
      debugPrint('Root Exec Error: $e');
      return '';
    }
  }

  Future<int> _runLiveRootCommand(
    String command,
    Function(String) logCallback,
  ) async {
    try {
      final process = await Process.start('su', ['-c', command]);

      process.stdout.transform(utf8.decoder).listen((data) {
        logCallback(data.trimRight());
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        logCallback("ERROR: ${data.trimRight()}");
      });

      return await process.exitCode;
    } catch (e) {
      logCallback("EXCEPTION: $e");
      return -1;
    }
  }

  Future<Uint8List?> _readRootFileBytes(String path) async {
    try {
      final result = await Process.run('su', [
        '-c',
        'cat "$path"',
      ], stdoutEncoding: null);
      if (result.exitCode == 0 && result.stdout != null) {
        List<int> data = result.stdout as List<int>;
        if (data.isNotEmpty) return Uint8List.fromList(data);
      }
    } catch (e) {
      debugPrint('Error reading logo bytes: $e');
    }
    return null;
  }

  Future<void> _loadPlugins() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    List<RacoPluginModel> loadedPlugins = [];

    // Ensure directory exists
    await _runRootCommand('mkdir -p $_pluginBasePath');
    await _runRootCommand('touch $_pluginTxtPath');

    // Read enabled/disabled status
    final String pluginTxtContent = await _runRootCommand(
      'cat $_pluginTxtPath',
    );
    final Map<String, bool> bootStatusMap = _parsePluginTxt(pluginTxtContent);

    // List plugins
    final String lsResult = await _runRootCommand('ls $_pluginBasePath');
    final List<String> folders = lsResult
        .split('\n')
        .where((s) => s.isNotEmpty)
        .toList();

    for (String folderName in folders) {
      final String currentPath = '$_pluginBasePath/$folderName';
      final String propPath = '$currentPath/raco.prop';
      final String propContent = await _runRootCommand('cat $propPath');

      if (propContent.isNotEmpty) {
        Map<String, String> props = _parseProp(propContent);
        String id = props['id'] ?? folderName;
        Uint8List? logoBytes = await _readRootFileBytes(
          '$currentPath/Logo.png',
        );

        // 1. Check for remote WebUI URL in props
        String? webUi = props['web_ui'];
        if (webUi != null && webUi.isEmpty) webUi = null;

        // 2. Check for local webroot (folder/webroot/index.html)
        final String webRootCheck = await _runRootCommand(
          '[ -f "$currentPath/webroot/index.html" ] && echo 1 || echo 0',
        );
        final bool hasWebRoot = webRootCheck == '1';

        // 3. Check for Action.sh
        final String actionCheck = await _runRootCommand(
          '[ -f "$currentPath/action.sh" ] && echo 1 || echo 0',
        );
        final bool hasAction = actionCheck == '1';

        loadedPlugins.add(
          RacoPluginModel(
            id: id,
            name: props['name'] ?? folderName,
            description: props['description'] ?? 'No description',
            version: props['version'] ?? '1.0',
            author: props['author'] ?? 'Unknown',
            path: currentPath,
            isBootEnabled: bootStatusMap[id] ?? false,
            logoBytes: logoBytes,
            webUiUrl: webUi,
            hasActionScript: hasAction,
            hasWebRoot: hasWebRoot,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _plugins = loadedPlugins;
        _isLoading = false;
      });
    }
  }

  Map<String, String> _parseProp(String content) {
    Map<String, String> props = {};
    List<String> lines = content.split('\n');
    for (var line in lines) {
      if (line.contains('=')) {
        var parts = line.split('=');
        if (parts.length >= 2) {
          props[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
    }
    return props;
  }

  Map<String, bool> _parsePluginTxt(String content) {
    Map<String, bool> status = {};
    List<String> lines = content.split('\n');
    for (var line in lines) {
      if (line.contains('=')) {
        var parts = line.split('=');
        if (parts.length >= 2) {
          String key = parts[0].trim();
          String val = parts[1].trim();
          status[key] = (val == '1');
        }
      }
    }
    return status;
  }

  Future<void> _togglePluginBoot(RacoPluginModel plugin, bool newValue) async {
    final int intVal = newValue ? 1 : 0;
    // Safe sed command to update or append the config line
    final String cmd =
        'if grep -q "^${plugin.id}=" $_pluginTxtPath; then '
        'sed -i "s/^${plugin.id}=.*/${plugin.id}=$intVal/" $_pluginTxtPath; '
        'else '
        'echo "${plugin.id}=$intVal" >> $_pluginTxtPath; '
        'fi';

    await _runRootCommand(cmd);

    setState(() {
      final index = _plugins.indexWhere((p) => p.id == plugin.id);
      if (index != -1) {
        _plugins[index] = RacoPluginModel(
          id: plugin.id,
          name: plugin.name,
          description: plugin.description,
          version: plugin.version,
          author: plugin.author,
          path: plugin.path,
          isBootEnabled: newValue,
          logoBytes: plugin.logoBytes,
          webUiUrl: plugin.webUiUrl,
          hasActionScript: plugin.hasActionScript,
          hasWebRoot: plugin.hasWebRoot,
        );
      }
    });
  }

  Future<void> _runManualPlugin(RacoPluginModel plugin) async {
    try {
      final String servicePath = '${plugin.path}/service.sh';
      await _runRootCommand('chmod +x $servicePath');

      // Execute in background using nohup
      await _runRootCommand('(nohup sh "$servicePath" > /dev/null 2>&1 &)');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.plugin_manually_executed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error executing ${plugin.name}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _runActionScript(RacoPluginModel plugin) async {
    await _showTerminalDialog(
      context: context,
      title: '${plugin.name} Action',
      task: (log) async {
        try {
          final String actionPath = '${plugin.path}/action.sh';
          log("- Setting permissions...");
          await _runRootCommand('chmod +x "$actionPath"');

          log("- Executing action.sh...");
          log("**************************************************");
          int exitCode = await _runLiveRootCommand('sh "$actionPath"', log);
          log("**************************************************");

          if (exitCode == 0) {
            log("- Action completed successfully.");
          } else {
            log("! Action failed with exit code: $exitCode");
          }
        } catch (e) {
          log("! Error executing action: $e");
        }
      },
    );
  }

  void _openWebUI(RacoPluginModel plugin) {
    if (plugin.webUiUrl != null && plugin.webUiUrl!.isNotEmpty) {
      // Remote URL
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PluginWebUiPage(
            title: plugin.name,
            remoteUrl: plugin.webUiUrl,
            pluginPath: plugin.path,
          ),
        ),
      );
    } else if (plugin.hasWebRoot) {
      // Local WebRoot - Points to the webroot folder inside the plugin
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PluginWebUiPage(
            title: plugin.name,
            localWebRoot: "${plugin.path}/webroot",
            pluginPath: plugin.path,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No WebUI configuration found.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _openFilePicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result != null && result.files.single.path != null) {
        _handleInstallFlow(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _handleInstallFlow(String zipPath) async {
    final loc = AppLocalizations.of(context)!;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.plugin_installer),
        content: Text(loc.install_question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.yes),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _showTerminalDialog(
      context: context,
      title: loc.installing_module,
      task: (log) async {
        try {
          log("- Preparing temporary directory...");
          await _runRootCommand('rm -rf $_tmpInstallPath');
          await _runRootCommand('mkdir -p $_tmpInstallPath');

          log("- Copying zip file...");
          await _runRootCommand('cp "$zipPath" $_tmpInstallPath/plugin.zip');

          log("- Extracting...");
          await _runLiveRootCommand(
            'unzip -o $_tmpInstallPath/plugin.zip -d $_tmpInstallPath/extracted',
            log,
          );

          log("- Verifying config...");
          final String propContent = await _runRootCommand(
            'cat $_tmpInstallPath/extracted/raco.prop',
          );

          if (propContent.isEmpty) {
            log("! Error: raco.prop not found.");
            throw Exception("Invalid Plugin: raco.prop missing");
          }

          Map<String, String> props = _parseProp(propContent);
          if (props['RacoPlugin'] != '1') {
            log("! Error: RacoPlugin flag missing or invalid.");
            throw Exception("Verification failed");
          }

          final String pluginId = props['id'] ?? 'unknown_plugin';
          final String pluginName = props['name'] ?? 'Unknown';
          log("- Plugin: $pluginName (ID: $pluginId)");

          log("- Setting permissions...");
          await _runRootCommand(
            'chmod +x $_tmpInstallPath/extracted/install.sh',
          );

          log("- Running install script...");
          log("**************************************************");
          int installCode = await _runLiveRootCommand(
            'cd $_tmpInstallPath/extracted && sh ./install.sh',
            log,
          );
          log("**************************************************");

          if (installCode != 0) {
            log("! Installation script failed (Exit Code: $installCode)");
            throw Exception("Script Error");
          }

          log("- Finalizing installation...");
          String currentPluginTxt = await _runRootCommand(
            'cat $_pluginTxtPath',
          );
          if (!currentPluginTxt.contains('$pluginId=')) {
            await _runRootCommand('echo "$pluginId=1" >> $_pluginTxtPath');
            log("- Plugin enabled by default.");
          }

          log("- Installing files to $_pluginBasePath/$pluginId...");
          final String targetPath = '$_pluginBasePath/$pluginId';
          await _runRootCommand('rm -rf $targetPath');
          await _runRootCommand('mkdir -p $targetPath');
          await _runRootCommand(
            'cp -r $_tmpInstallPath/extracted/* $targetPath/',
          );
          await _runRootCommand('rm -rf $_tmpInstallPath');

          log("- Done!");
          _loadPlugins();
        } catch (e) {
          log("! INSTALLATION FAILED");
          log(e.toString());
        }
      },
    );
  }

  Future<void> _handleUninstallFlow(RacoPluginModel plugin) async {
    final loc = AppLocalizations.of(context)!;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.delete_plugin_title),
        content: Text(loc.delete_plugin_confirm(plugin.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.yes),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _runRootCommand('chmod +x ${plugin.path}/uninstall.sh');
    await _runRootCommand('sh "${plugin.path}/uninstall.sh"');
    await _runRootCommand("sed -i '/^${plugin.id}=/d' $_pluginTxtPath");
    await _runRootCommand('rm -rf "${plugin.path}"');

    _loadPlugins();
  }

  Future<void> _showTerminalDialog({
    required BuildContext context,
    required String title,
    required Future<void> Function(Function(String) log) task,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => TerminalPage(title: title, task: task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(loc.plugins_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: loc.install_plugin,
            onPressed: _openFilePicker,
          ),
        ],
      ),
      body: _plugins.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.extension_off_outlined,
                    size: 64,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.no_plugins_installed,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openFilePicker,
                    icon: const Icon(Icons.upload_file),
                    label: Text(loc.install_plugin),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _plugins.length,
              itemBuilder: (context, index) {
                final plugin = _plugins[index];
                return _PluginCard(
                  plugin: plugin,
                  onRunService: () => _runManualPlugin(plugin),
                  onRunAction: () => _runActionScript(plugin),
                  onOpenWebUI: () => _openWebUI(plugin),
                  onBootToggle: (val) => _togglePluginBoot(plugin, val),
                  onDelete: () => _handleUninstallFlow(plugin),
                );
              },
            ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: theme.colorScheme.background),
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
                errorBuilder: (_, __, ___) => Container(),
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

// =========================================================
//  PLUGIN CARD WIDGET
// =========================================================

class _PluginCard extends StatefulWidget {
  final RacoPluginModel plugin;
  final Future<void> Function() onRunService;
  final Future<void> Function() onRunAction;
  final VoidCallback onOpenWebUI;
  final ValueChanged<bool> onBootToggle;
  final VoidCallback onDelete;

  const _PluginCard({
    Key? key,
    required this.plugin,
    required this.onRunService,
    required this.onRunAction,
    required this.onOpenWebUI,
    required this.onBootToggle,
    required this.onDelete,
  }) : super(key: key);

  @override
  _PluginCardState createState() => _PluginCardState();
}

class _PluginCardState extends State<_PluginCard> {
  static const Color _webUiColor = Color(0xFF1E3A3A); // Dark Teal/Green
  static const Color _webUiIconColor = Color(0xFF80CBC4); // Light Teal
  static const Color _actionColor = Color(0xFF333D29); // Dark Olive
  static const Color _actionIconColor = Color(0xFFA5D6A7); // Light Green
  static const Color _runColor = Color(0xFF2E4F3E); // Dark Green Pill
  static const Color _runTextColor = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plugin = widget.plugin;
    final bool showWebUi = (plugin.webUiUrl != null) || plugin.hasWebRoot;

    return Card(
      color: const Color(0xFF1A1C19), // Dark background card
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                // Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: plugin.logoBytes != null
                      ? Image.memory(plugin.logoBytes!, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            plugin.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "v${plugin.version} • ${plugin.author}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),

                // Delete Icon
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFFEF9A9A),
                  onPressed: widget.onDelete,
                ),
              ],
            ),

            // --- DESCRIPTION ---
            const SizedBox(height: 12),
            Text(
              plugin.description,
              style: TextStyle(fontSize: 14, color: Colors.grey[300]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),

            // --- ACTION ROW ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // WebUI Button
                  if (showWebUi) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _webUiColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.language),
                        color: _webUiIconColor,
                        onPressed: widget.onOpenWebUI,
                        tooltip: 'Web UI',
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Action.sh Button
                  if (plugin.hasActionScript) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _actionColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.build),
                        color: _actionIconColor,
                        onPressed: widget.onRunAction,
                        tooltip: 'Action',
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Run Button
                  Material(
                    color: _runColor,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: widget.onRunService,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_arrow,
                              size: 20,
                              color: _runTextColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.plugin_run,
                              style: TextStyle(
                                color: _runTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Boot Toggle
                  Text(
                    AppLocalizations.of(context)!.plugin_boot,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: plugin.isBootEnabled,
                    onChanged: widget.onBootToggle,
                    activeColor: Colors.greenAccent,
                    trackColor: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.green[900];
                      }
                      return Colors.grey[700];
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
//  TERMINAL LOG DIALOG
// =========================================================

class TerminalPage extends StatefulWidget {
  final String title;
  final Future<void> Function(Function(String) log) task;

  const TerminalPage({Key? key, required this.title, required this.task})
    : super(key: key);

  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    widget.task(_addLog).then((_) {
      if (mounted) {
        setState(() => _isFinished = true);
      }
    });
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.add(message);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (_isFinished)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
//  WEB UI PAGE (KSU Compatible + Localhost Server)
// =========================================================

class PluginWebUiPage extends StatefulWidget {
  final String title;
  final String? remoteUrl;
  final String? localWebRoot; // Original Path in /data
  final String pluginPath;

  const PluginWebUiPage({
    Key? key,
    required this.title,
    this.remoteUrl,
    this.localWebRoot,
    required this.pluginPath,
  }) : super(key: key);

  @override
  State<PluginWebUiPage> createState() => _PluginWebUiPageState();
}

class _PluginWebUiPageState extends State<PluginWebUiPage> {
  InAppWebViewController? _controller;
  HttpServer? _server;
  bool _isLoading = true;
  String? _errorMessage;
  String? _targetUrl;
  String? _webCachePath;

  @override
  void initState() {
    super.initState();
    _initWebUI();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _initWebUI() async {
    // 1. If Remote URL, just use it
    if (widget.remoteUrl != null) {
      setState(() {
        _targetUrl = widget.remoteUrl;
        _isLoading = false;
      });
      return;
    }

    // 2. If Local WebRoot, set up Localhost Server
    if (widget.localWebRoot != null) {
      try {
        await _setupLocalServer();
      } catch (e) {
        setState(() {
          _errorMessage = "Failed to start local server: $e";
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = "Invalid WebUI Configuration";
        _isLoading = false;
      });
    }
  }

  Future<void> _setupLocalServer() async {
    // A. Prepare Cache Directory
    final Directory cacheDir = await getApplicationSupportDirectory();
    final String folderName =
        widget.pluginPath.hashCode.toRadixString(16) + "_webroot";
    _webCachePath = '${cacheDir.path}/web_cache/$folderName';

    // Cleanup old cache
    await Process.run('su', ['-c', 'rm -rf "$_webCachePath"']);
    await Process.run('su', ['-c', 'mkdir -p "$_webCachePath"']);

    // Copy files recursively to preserve structure (assets/ etc)
    final copyResult = await Process.run('su', [
      '-c',
      'cp -r "${widget.localWebRoot}"/* "$_webCachePath/" && chmod -R 777 "$_webCachePath"',
    ]);

    if (copyResult.exitCode != 0) {
      throw Exception("Failed to stage files. Check root permissions.");
    }

    // B. Start Http Server on Ephemeral Port
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final int port = _server!.port;

    _server!.listen((HttpRequest request) {
      _handleRequest(request);
    });

    setState(() {
      _targetUrl = 'http://127.0.0.1:$port/index.html';
      _isLoading = false;
    });
  }

  void _handleRequest(HttpRequest request) async {
    // 1. Clean Path
    String cleanPath = request.uri.path;
    if (cleanPath == '/') cleanPath = '/index.html';

    // 2. Resolve File
    final File file = File('$_webCachePath$cleanPath');

    // 3. Serve
    if (await file.exists()) {
      request.response.headers.contentType = _getContentType(cleanPath);
      // Disable caching for development/tweak purposes
      request.response.headers.add(
        "Cache-Control",
        "no-cache, no-store, must-revalidate",
      );
      await file.openRead().pipe(request.response);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('404 Not Found: $cleanPath');
      request.response.close();
    }
  }

  ContentType _getContentType(String path) {
    if (path.endsWith('.html')) return ContentType.html;
    if (path.endsWith('.css')) return ContentType('text', 'css');
    if (path.endsWith('.js')) return ContentType('application', 'javascript');
    if (path.endsWith('.json')) return ContentType.json;
    if (path.endsWith('.png')) return ContentType('image', 'png');
    if (path.endsWith('.jpg') || path.endsWith('.jpeg'))
      return ContentType('image', 'jpeg');
    if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (path.endsWith('.gif')) return ContentType('image', 'gif');
    if (path.endsWith('.ttf')) return ContentType('font', 'ttf');
    if (path.endsWith('.woff')) return ContentType('font', 'woff');
    if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
    return ContentType.binary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_targetUrl != null)
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_targetUrl!)),
              initialSettings: InAppWebViewSettings(
                allowFileAccess: true,
                allowContentAccess: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                domStorageEnabled: true,
                javaScriptEnabled: true,
                displayZoomControls: false,
                // mixedContentMode handles http://localhost images loading in https context if needed
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              // Inject KSU API Standard (Compatible with PingPimp)
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source: """
                    (function() {
                      if (window.ksu) return;
                      window.ksu = {
                          // Standard KSU exec: command, options, callback(errno, stdout, stderr)
                          // Note: The script.js provided uses ksu.exec(cmd, "{}", "callbackName")
                          exec: function(command, options, callbackOrName) {
                              
                              // Handle both function callback and string name callback
                              let cbName = null;
                              if (typeof callbackOrName === 'string') {
                                  cbName = callbackOrName;
                              }

                              // Call Flutter Handler
                              window.flutter_inappwebview.callHandler('ksuExec', command, options)
                              .then(result => {
                                  if (cbName) {
                                      // If callback was passed as a global window function name (PingPimp style)
                                      if (typeof window[cbName] === 'function') {
                                          window[cbName](result.errno, result.stdout, result.stderr);
                                      }
                                  } else if (typeof callbackOrName === 'function') {
                                      // If callback was passed as a function (Standard KSU style)
                                      callbackOrName(result.errno, result.stdout, result.stderr);
                                  }
                              })
                              .catch(error => {
                                  console.error("KSU Bridge Error: " + error);
                                  // Try to report error to callback if possible
                                  if (cbName && typeof window[cbName] === 'function') {
                                      window[cbName](-1, "", error.toString());
                                  }
                              });
                          },
                          toast: function(message) {
                              window.flutter_inappwebview.callHandler('ksuToast', message);
                          },
                          fullScreen: function(enable) {
                              window.flutter_inappwebview.callHandler('ksuFullScreen', enable);
                          }
                      };
                      // try to make it immutable
                      try { Object.defineProperty(window, 'ksu', { writable: false }); } catch (e) {}
                    })();
                  """,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              onWebViewCreated: (controller) {
                _controller = controller;

                // 1. KSU Exec Handler
                controller.addJavaScriptHandler(
                  handlerName: 'ksuExec',
                  callback: (args) async {
                    if (args.isEmpty) return null;
                    String cmd = args[0].toString();
                    debugPrint("KSU Exec: $cmd");
                    try {
                      // Execute command as root within the plugin directory context
                      // We must wrap in 'sh -c' or just pass to 'su -c'
                      final String fullCmd =
                          'cd "${widget.pluginPath}" && $cmd';
                      final result = await Process.run('su', ['-c', fullCmd]);
                      return {
                        'errno': result.exitCode,
                        'stdout': result.stdout.toString(),
                        'stderr': result.stderr.toString(),
                      };
                    } catch (e) {
                      return {
                        'errno': -1,
                        'stdout': '',
                        'stderr': e.toString(),
                      };
                    }
                  },
                );

                // 2. KSU Toast Handler
                controller.addJavaScriptHandler(
                  handlerName: 'ksuToast',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      String msg = args[0].toString();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                );

                // 3. KSU FullScreen Handler
                controller.addJavaScriptHandler(
                  handlerName: 'ksuFullScreen',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      bool enable = args[0] == true;
                      if (enable) {
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.immersiveSticky,
                        );
                      } else {
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                        );
                      }
                    }
                  },
                );
              },
              onLoadStart: (controller, url) {
                setState(() => _isLoading = true);
              },
              onLoadStop: (controller, url) {
                setState(() => _isLoading = false);
              },
              onReceivedError: (controller, request, error) {
                debugPrint("WebView Error: ${error.description}");
              },
            ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
