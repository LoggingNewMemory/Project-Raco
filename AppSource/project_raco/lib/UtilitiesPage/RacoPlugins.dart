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

  RacoPluginModel({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.path,
    required this.isBootEnabled,
    this.logoBytes,
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

  // --- Helper Methods ---

  Future<String> _runRootCommand(String command) async {
    try {
      final result = await Process.run('su', ['-c', command]);
      return result.exitCode == 0 ? result.stdout.toString().trim() : '';
    } catch (e) {
      debugPrint('Root Exec Error: $e');
      return '';
    }
  }

  // New Helper: Runs a command and streams output to a log callback
  Future<int> _runLiveRootCommand(
    String command,
    Function(String) logCallback,
  ) async {
    try {
      final process = await Process.start('su', ['-c', command]);

      // Pipe stdout and stderr to the log
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

  // --- Logic Actions ---

  Future<void> _togglePluginBoot(RacoPluginModel plugin, bool newValue) async {
    final int intVal = newValue ? 1 : 0;
    final String cmd =
        'if grep -q "^${plugin.id}=" $_pluginTxtPath; then '
        'sed -i "s/^${plugin.id}=.*/${plugin.id}=$intVal/" $_pluginTxtPath; '
        'else '
        'echo "${plugin.id}=$intVal" >> $_pluginTxtPath; '
        'fi';

    await _runRootCommand(cmd);
    await _loadPlugins();
  }

  Future<void> _runManualPlugin(RacoPluginModel plugin) async {
    final loc = AppLocalizations.of(context)!;
    // We can also use the TerminalDialog for manual runs if desired,
    // but for now keeping "Run" simple or redirecting to dialog?
    // Let's use the new Terminal Dialog for "Run" as well to show output!

    _showTerminalDialog(
      context: context,
      title: "Executing ${plugin.name}...",
      task: (log) async {
        log("Checking service script...");
        final String servicePath = '${plugin.path}/service.sh';
        await _runRootCommand('chmod +x $servicePath');

        log("Executing service.sh...");
        log("--------------------------------------------------");
        int code = await _runLiveRootCommand('sh $servicePath', log);
        log("--------------------------------------------------");

        if (code == 0) {
          log("Success: Command executed.");
        } else {
          log("Error: Process exited with code $code");
        }
      },
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // --- Install Flow with Terminal Log ---
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

    // Show Terminal Dialog and run logic inside it
    await _showTerminalDialog(
      context: context,
      title: "Installing Module",
      task: (log) async {
        try {
          log("- Preparing temporary directory...");
          await _runRootCommand('rm -rf $_tmpInstallPath');
          await _runRootCommand('mkdir -p $_tmpInstallPath');

          log("- Copying zip file...");
          await _runRootCommand('cp "$zipPath" $_tmpInstallPath/plugin.zip');

          log("- Extracting...");
          // Using runLive mainly to show if unzip throws verbose errors,
          // or just simple run is enough. Let's use live for detailed feel.
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
          log("You may need to reboot for some changes to take effect.");

          // Refresh UI list in background
          _loadPlugins();
        } catch (e) {
          log("! INSTALLATION FAILED");
          log(e.toString());
          // We assume the dialog stays open so user can see the error
        }
      },
    );
  }

  // --- Uninstall Flow with Terminal Log ---
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

    await _showTerminalDialog(
      context: context,
      title: "Uninstalling ${plugin.name}",
      task: (log) async {
        try {
          log("- Running uninstall script...");
          await _runRootCommand('chmod +x ${plugin.path}/uninstall.sh');

          log("**************************************************");
          await _runLiveRootCommand('su -c "${plugin.path}/uninstall.sh"', log);
          log("**************************************************");

          log("- Removing from registry...");
          await _runRootCommand("sed -i '/^${plugin.id}=/d' $_pluginTxtPath");

          log("- Deleting files...");
          await _runRootCommand('rm -rf "${plugin.path}"');

          log("- Success!");
          _loadPlugins();
        } catch (e) {
          log("! Error removing plugin: $e");
        }
      },
    );
  }

  // --- UI Methods ---

  Future<void> _showTerminalDialog({
    required BuildContext context,
    required String title,
    required Future<void> Function(Function(String) log) task,
  }) {
    return showDialog(
      context: context,
      barrierDismissible:
          false, // User must wait or use the close button when done
      builder: (ctx) => TerminalDialog(title: title, task: task),
    );
  }

  void _showLoadingDialog(String message) {
    // Kept for legacy uses if any, but mostly replaced by TerminalDialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
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
                  onRun: () => _runManualPlugin(plugin),
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

// --- WIDGETS ---

class _PluginCard extends StatefulWidget {
  final RacoPluginModel plugin;
  final VoidCallback onRun;
  final ValueChanged<bool> onBootToggle;
  final VoidCallback onDelete;

  const _PluginCard({
    Key? key,
    required this.plugin,
    required this.onRun,
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
                            "v${plugin.version} • ${plugin.author}",
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
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: widget.onRun,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text("Run"),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          "Boot",
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

// --- NEW WIDGET: Terminal Style Dialog ---

class TerminalDialog extends StatefulWidget {
  final String title;
  final Future<void> Function(Function(String) log) task;

  const TerminalDialog({Key? key, required this.title, required this.task})
    : super(key: key);

  @override
  _TerminalDialogState createState() => _TerminalDialogState();
}

class _TerminalDialogState extends State<TerminalDialog> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    // Start the task immediately
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
    // Auto scroll to bottom
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
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E), // Dark terminal bg
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.grey),

          // Terminal Output
          SizedBox(
            height: 300, // Fixed height for log area
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(
                      fontFamily: 'monospace', // Terminal look
                      color: Color(0xFF00FF00), // Green text
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer / Close Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isFinished)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 16, bottom: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
