import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';

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

    await _runRootCommand('mkdir -p $_pluginBasePath');
    await _runRootCommand('touch $_pluginTxtPath');

    final String pluginTxtContent = await _runRootCommand(
      'cat $_pluginTxtPath',
    );
    final Map<String, bool> bootStatusMap = _parsePluginTxt(pluginTxtContent);

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

        // 2. Check for local webroot (folder/index.html)
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

  Future<void> _openWebUI(RacoPluginModel plugin) async {
    try {
      if (plugin.webUiUrl != null) {
        // Option 1: URL defined in raco.prop
        await _runRootCommand(
          'am start -a android.intent.action.VIEW -d "${plugin.webUiUrl}"',
        );
      } else if (plugin.hasWebRoot) {
        // Option 2: Local webroot exists
        // We attempt to open the index.html file directly via Android intent.
        // Note: For advanced usage (like KernelSU), this usually requires
        // starting a local HTTP server because many browsers block file:// access
        // to /data directories due to permissions.
        final String localPath = "file://${plugin.path}/webroot/index.html";
        await _runRootCommand(
          'am start -a android.intent.action.VIEW -d "$localPath" -t "text/html"',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WebUI: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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

class _PluginCard extends StatefulWidget {
  final RacoPluginModel plugin;
  final Future<void> Function() onRunService;
  final Future<void> Function() onRunAction;
  final Future<void> Function() onOpenWebUI;
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

class _PluginCardState extends State<_PluginCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plugin = widget.plugin;

    // Determine if WebUI button should show
    final bool showWebUi = (plugin.webUiUrl != null) || plugin.hasWebRoot;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: _toggleExpand,
        highlightColor: theme.colorScheme.primary.withOpacity(0.1),
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: plugin.logoBytes != null
                          ? Image.memory(plugin.logoBytes!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                plugin.name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plugin.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: _isExpanded ? null : 1,
                            overflow: _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          Text(
                            "${plugin.version} • ${plugin.author}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: _isExpanded ? null : 1,
                            overflow: _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: theme.colorScheme.error,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plugin.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  children: [
                    // WebUI Button
                    if (showWebUi) ...[
                      IconButton.filledTonal(
                        onPressed: widget.onOpenWebUI,
                        icon: const Icon(Icons.language),
                        tooltip: 'Open WebUI',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                          foregroundColor:
                              theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Action.sh Button
                    if (plugin.hasActionScript) ...[
                      IconButton.filledTonal(
                        onPressed: widget.onRunAction,
                        icon: const Icon(Icons.build),
                        tooltip: 'Run Action',
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Standard Service Run Button
                    FilledButton.tonalIcon(
                      onPressed: widget.onRunService,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(AppLocalizations.of(context)!.plugin_run),
                    ),

                    const Spacer(),

                    // Boot Toggle
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.plugin_boot,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: plugin.isBootEnabled,
                          onChanged: widget.onBootToggle,
                          activeColor: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
