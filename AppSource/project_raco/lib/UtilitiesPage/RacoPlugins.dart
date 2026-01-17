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

  // Paths defined in design
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
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      } else {
        // We log stderr but return empty string or throw depending on logic needs
        debugPrint('Root Command Error: ${result.stderr}');
        return '';
      }
    } catch (e) {
      debugPrint('Root Exec Error: $e');
      return '';
    }
  }

  Future<void> _loadPlugins() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    List<RacoPluginModel> loadedPlugins = [];

    // Check if Plugins directory exists
    await _runRootCommand('mkdir -p $_pluginBasePath');

    // Ensure Plugin.txt exists
    await _runRootCommand('touch $_pluginTxtPath');

    // Read Plugin.txt to determine boot status
    // Format: PluginID=1 (Enabled) or PluginID=0 (Disabled)
    final String pluginTxtContent = await _runRootCommand(
      'cat $_pluginTxtPath',
    );
    final Map<String, bool> bootStatusMap = _parsePluginTxt(pluginTxtContent);

    // List directories in Plugins folder
    final String lsResult = await _runRootCommand('ls $_pluginBasePath');
    final List<String> folders = lsResult
        .split('\n')
        .where((s) => s.isNotEmpty)
        .toList();

    for (String folderName in folders) {
      final String propPath = '$_pluginBasePath/$folderName/raco.prop';
      // Read raco.prop
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
            // Default to false if not found in Plugin.txt
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

  // Parse Plugin.txt: PluginID=1 -> true
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

  // --- Features: Toggle Boot & Manual Run ---

  Future<void> _togglePluginBoot(RacoPluginModel plugin, bool newValue) async {
    final int intVal = newValue ? 1 : 0;

    // Logic: Use grep to check if entry exists.
    // If exists: Use sed to replace line.
    // If not exists: Echo new line.
    final String cmd =
        'if grep -q "^${plugin.id}=" $_pluginTxtPath; then '
        'sed -i "s/^${plugin.id}=.*/${plugin.id}=$intVal/" $_pluginTxtPath; '
        'else '
        'echo "${plugin.id}=$intVal" >> $_pluginTxtPath; '
        'fi';

    await _runRootCommand(cmd);

    // Refresh list to update UI
    await _loadPlugins();
  }

  Future<void> _runManualPlugin(RacoPluginModel plugin) async {
    final loc = AppLocalizations.of(context)!;
    _showLoadingDialog(loc.executing_command);

    // Diagram: "Manual -> Run service.sh"
    final String servicePath = '${plugin.path}/service.sh';

    // Ensure executable
    await _runRootCommand('chmod +x $servicePath');

    // Run
    final result = await Process.run('su', ['-c', 'sh $servicePath']);

    if (mounted) {
      Navigator.pop(context); // Close loading
      if (result.exitCode == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.command_executed)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${loc.command_failed}\n${result.stderr}")),
        );
      }
    }
  }

  // --- Installation Logic ---

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
      ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
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

      // Add PluginID=1 to Plugin.txt (Default enabled upon install per diagram implication?)
      // Actually diagram says "Add PluginID to Plugin.txt", usually enabled by default is friendly.
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
      final String downloadPath = '/sdcard/Download';
      final String logFile =
          '$downloadPath/raco_plugin_error_${pluginId ?? "unknown"}_${DateTime.now().millisecondsSinceEpoch}.txt';
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

  // --- Uninstallation Logic ---

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
      final String uninstallScript = '${plugin.path}/uninstall.sh';
      await _runRootCommand('chmod +x $uninstallScript');
      await _runRootCommand('su -c "$uninstallScript"');

      // Delete from Plugin.txt
      await _runRootCommand("sed -i '/^${plugin.id}=/d' $_pluginTxtPath");

      // Delete directory
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

  // --- Helper Widgets ---

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.no_plugins_installed,
                    style: Theme.of(context).textTheme.titleMedium,
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
              padding: const EdgeInsets.all(16),
              itemCount: _plugins.length,
              itemBuilder: (context, index) {
                final plugin = _plugins[index];
                return Card(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.8),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        plugin.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    title: Text(
                      plugin.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plugin.description),
                        const SizedBox(height: 4),
                        Text(
                          "v${plugin.version} • by ${plugin.author}",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    // Updated Trailing: Manual Run, Boot Switch, Delete
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Manual Run Button
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          tooltip: "Run Manual",
                          onPressed: () => _runManualPlugin(plugin),
                        ),
                        // Boot Toggle Switch
                        Switch(
                          value: plugin.isBootEnabled,
                          onChanged: (val) => _togglePluginBoot(plugin, val),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        // Delete Button
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _handleUninstallFlow(plugin),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                errorBuilder: (ctx, err, stack) =>
                    Container(color: Colors.transparent),
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
