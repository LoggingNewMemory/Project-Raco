import 'dart:async';
import 'dart:io';
import 'dart:ui';
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

  RacoPluginModel({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.path,
    required this.isBootEnabled,
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

  // Paths
  final String _pluginBasePath = '/data/ProjectRaco/Plugins';
  final String _pluginTxtPath = '/data/ProjectRaco/Plugin.txt';
  final String _tmpInstallPath = '/data/local/tmp/raco_plugin_install';

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  // --- Root & File Logic ---

  Future<String> _runRootCommand(String command) async {
    try {
      final result = await Process.run('su', ['-c', command]);
      return result.exitCode == 0 ? result.stdout.toString().trim() : '';
    } catch (e) {
      debugPrint('Root Exec Error: $e');
      return '';
    }
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
      final String propPath = '$_pluginBasePath/$folderName/raco.prop';
      final String propContent = await _runRootCommand('cat $propPath');

      if (propContent.isNotEmpty) {
        Map<String, String> props = _parseProp(propContent);
        String id = props['id'] ?? folderName;

        loadedPlugins.add(
          RacoPluginModel(
            id: id,
            name: props['name'] ?? folderName,
            description: props['description'] ?? 'No description',
            version: props['version'] ?? '1.0',
            author: props['author'] ?? 'Unknown',
            path: '$_pluginBasePath/$folderName',
            isBootEnabled: bootStatusMap[id] ?? false,
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

  // --- Actions ---

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
    _showLoadingDialog(loc.executing_command);

    final String servicePath = '${plugin.path}/service.sh';
    await _runRootCommand('chmod +x $servicePath');

    final result = await Process.run('su', ['-c', 'sh $servicePath']);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.exitCode == 0
                ? loc.command_executed
                : "${loc.command_failed}\n${result.stderr}",
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    _showLoadingDialog(loc.executing_command);

    try {
      await _runRootCommand('rm -rf $_tmpInstallPath');
      await _runRootCommand('mkdir -p $_tmpInstallPath');
      await _runRootCommand('cp "$zipPath" $_tmpInstallPath/plugin.zip');
      await _runRootCommand(
        'unzip -o $_tmpInstallPath/plugin.zip -d $_tmpInstallPath/extracted',
      );

      final String propContent = await _runRootCommand(
        'cat $_tmpInstallPath/extracted/raco.prop',
      );
      Map<String, String> props = _parseProp(propContent);

      if (props['RacoPlugin'] != '1') {
        Navigator.pop(context);
        await _handleInstallError(loc.plugin_verification_failed, props['id']);
        return;
      }

      final String pluginId = props['id'] ?? 'unknown_plugin';
      await _runRootCommand('chmod +x $_tmpInstallPath/extracted/install.sh');

      final ProcessResult installResult = await Process.run('su', [
        '-c',
        'cd $_tmpInstallPath/extracted && ./install.sh',
      ]);
      if (installResult.exitCode != 0) {
        Navigator.pop(context);
        await _handleInstallError(
          "${loc.plugin_script_error}\n${installResult.stderr}",
          pluginId,
        );
        return;
      }

      String currentPluginTxt = await _runRootCommand('cat $_pluginTxtPath');
      if (!currentPluginTxt.contains('$pluginId=')) {
        await _runRootCommand('echo "$pluginId=1" >> $_pluginTxtPath');
      }

      final String targetPath = '$_pluginBasePath/$pluginId';
      await _runRootCommand('rm -rf $targetPath');
      await _runRootCommand('mkdir -p $targetPath');
      await _runRootCommand('cp -r $_tmpInstallPath/extracted/* $targetPath/');
      await _runRootCommand('rm -rf $_tmpInstallPath');

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.plugin_installed_success)));
      _loadPlugins();
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _handleInstallError(String errorMsg, String? pluginId) async {
    final loc = AppLocalizations.of(context)!;
    bool? saveLogs = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.command_failed),
        content: Text("$errorMsg\n\nSave Logs?"),
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

    if (saveLogs == true) {
      final String logFile =
          '/sdcard/Download/raco_plugin_error_${pluginId}_${DateTime.now().millisecondsSinceEpoch}.txt';
      await _runRootCommand('echo "$errorMsg" > $logFile');
      await _runRootCommand(
        'cat $_tmpInstallPath/extracted/install.log >> $logFile',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.logs_saved)));
    }
    await _runRootCommand('rm -rf $_tmpInstallPath');
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
    _showLoadingDialog(loc.executing_command);

    try {
      await _runRootCommand('chmod +x ${plugin.path}/uninstall.sh');
      await _runRootCommand('su -c "${plugin.path}/uninstall.sh"');
      await _runRootCommand("sed -i '/^${plugin.id}=/d' $_pluginTxtPath");
      await _runRootCommand('rm -rf "${plugin.path}"');

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.plugin_uninstall_success)));
      _loadPlugins();
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(e.toString());
    }
  }

  void _showLoadingDialog(String message) {
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
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

// --- UPDATED WIDGET: Buttons Always Visible, Text Expands on Click ---

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
        onTap: _toggleExpand, // Tapping anywhere toggles text expansion
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
                // --- Row 1: Icon, Title, Delete ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
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
                    // Title & Version (Expandable)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plugin.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            // If collapsed: 1 line with ellipsis. If expanded: wrap.
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
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: theme.colorScheme.error,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // --- Row 2: Description (Expandable) ---
                Text(
                  plugin.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  // If collapsed: 2 lines. If expanded: wrap.
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

                // --- Row 3: Action Buttons (Always Visible) ---
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
