import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';

class RacoPluginModel {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String path;

  RacoPluginModel({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.path,
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
        throw Exception(result.stderr.toString());
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _loadPlugins() async {
    setState(() => _isLoading = true);
    List<RacoPluginModel> loadedPlugins = [];

    // Check if Plugins directory exists
    await _runRootCommand('mkdir -p $_pluginBasePath');

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

        loadedPlugins.add(
          RacoPluginModel(
            id: props['id'] ?? folderName,
            name: props['name'] ?? folderName,
            description: props['description'] ?? 'No description',
            version: props['version'] ?? '1.0',
            author: props['author'] ?? 'Unknown',
            path: '$_pluginBasePath/$folderName',
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

  // --- Installation Logic (Based on Diagram) ---

  Future<void> _handleInstallFlow(String zipPath) async {
    final loc = AppLocalizations.of(context)!;

    // 1. Prompt User Install Confirmation
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
      // Clean temp
      await _runRootCommand('rm -rf $_tmpInstallPath');
      await _runRootCommand('mkdir -p $_tmpInstallPath');

      // Copy zip to tmp
      await _runRootCommand('cp "$zipPath" $_tmpInstallPath/plugin.zip');

      // Unzip
      await _runRootCommand(
        'unzip -o $_tmpInstallPath/plugin.zip -d $_tmpInstallPath/extracted',
      );

      // 2. Verify RacoPlugin=1 in raco.prop
      final String propContent = await _runRootCommand(
        'cat $_tmpInstallPath/extracted/raco.prop',
      );
      Map<String, String> props = _parseProp(propContent);

      if (props['RacoPlugin'] != '1') {
        // Verification Failed
        Navigator.pop(context); // Close loading
        await _handleInstallError(loc.plugin_verification_failed, props['id']);
        return;
      }

      final String pluginId = props['id'] ?? 'unknown_plugin';

      // 3. Run install.sh
      await _runRootCommand('chmod +x $_tmpInstallPath/extracted/install.sh');
      final ProcessResult installResult = await Process.run('su', [
        '-c',
        'cd $_tmpInstallPath/extracted && ./install.sh',
      ]);

      if (installResult.exitCode != 0) {
        // Script Error
        Navigator.pop(context); // Close loading
        await _handleInstallError(
          "${loc.plugin_script_error}\n${installResult.stderr}",
          pluginId,
        );
        return;
      }

      // 4. Success Flow
      // Add PluginID to Plugin.txt
      // Check if Plugin.txt exists, if not create
      await _runRootCommand('touch $_pluginTxtPath');
      // Append PluginID=1 (as per "Run Plugin" diagram logic requiring "Plugin must defined as 1")
      // We use grep to check if it exists to avoid duplicates, then sed or echo
      String currentPluginTxt = await _runRootCommand('cat $_pluginTxtPath');
      if (!currentPluginTxt.contains('$pluginId=1')) {
        await _runRootCommand('echo "$pluginId=1" >> $_pluginTxtPath');
      }

      // Copy all contents to /data/ProjectRaco/Plugins/(plugin id)
      final String targetPath = '$_pluginBasePath/$pluginId';
      await _runRootCommand('rm -rf $targetPath'); // Clean old if exists
      await _runRootCommand('mkdir -p $targetPath');
      await _runRootCommand('cp -r $_tmpInstallPath/extracted/* $targetPath/');

      // Cleanup
      await _runRootCommand('rm -rf $_tmpInstallPath');

      Navigator.pop(context); // Close loading

      // Done
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.plugin_installed_success)));
      _loadPlugins(); // Refresh list
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _handleInstallError(String errorMsg, String? pluginId) async {
    final loc = AppLocalizations.of(context)!;
    // Prompt: Save Logs?
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
      // Copy Logs
      final String downloadPath = '/sdcard/Download';
      final String logFile =
          '$downloadPath/raco_plugin_error_${pluginId ?? "unknown"}_${DateTime.now().millisecondsSinceEpoch}.txt';
      await _runRootCommand('echo "$errorMsg" > $logFile');
      // If there was an install log in tmp
      await _runRootCommand(
        'cat $_tmpInstallPath/extracted/install.log >> $logFile',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.logs_saved)));
    }

    // Delete folder containing plugin (temp folder in this case)
    await _runRootCommand('rm -rf $_tmpInstallPath');
  }

  // --- Uninstallation Logic (Based on Diagram) ---

  Future<void> _handleUninstallFlow(RacoPluginModel plugin) async {
    final loc = AppLocalizations.of(context)!;

    // 1. Confirm Delete
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
      // 2. Run uninstall.sh
      final String uninstallScript = '${plugin.path}/uninstall.sh';
      await _runRootCommand('chmod +x $uninstallScript');
      // We run it but don't strictly fail if it errors, as we delete files anyway per diagram
      await _runRootCommand('su -c "$uninstallScript"');

      // 3. Delete the PluginID from Plugin.txt
      // We use sed to delete the line containing "PluginID="
      await _runRootCommand("sed -i '/^${plugin.id}=/d' $_pluginTxtPath");

      // 4. Delete the Plugin Directory
      await _runRootCommand('rm -rf "${plugin.path}"');

      Navigator.pop(context); // Close loading
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

  void _openFilePicker() {
    showDialog(
      context: context,
      builder: (context) => SimpleFilePickerDialog(
        rootPath: '/sdcard',
        onFilePicked: (path) {
          Navigator.pop(context);
          _handleInstallFlow(path);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Define the content in a transparent Scaffold
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
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _handleUninstallFlow(plugin),
                    ),
                  ),
                );
              },
            ),
    );

    // Return a Stack with the background layers and the page content on top
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Solid background color (Theme)
        Container(color: Theme.of(context).colorScheme.background),

        // 2. Background Image with Blur (if available)
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

        // 3. Loading or Content
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

// Simple File Picker to avoid external dependencies for zip selection
class SimpleFilePickerDialog extends StatefulWidget {
  final String rootPath;
  final Function(String) onFilePicked;

  const SimpleFilePickerDialog({
    Key? key,
    required this.rootPath,
    required this.onFilePicked,
  }) : super(key: key);

  @override
  _SimpleFilePickerDialogState createState() => _SimpleFilePickerDialogState();
}

class _SimpleFilePickerDialogState extends State<SimpleFilePickerDialog> {
  late Directory _currentDir;
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _currentDir = Directory(widget.rootPath);
    _listDir();
  }

  void _listDir() {
    try {
      final files = _currentDir.listSync()
        ..sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
      setState(() {
        _files = files
            .where((e) => e is Directory || e.path.endsWith('.zip'))
            .toList();
      });
    } catch (e) {
      // Permission denied or other error
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _currentDir.path.split('/').last.isEmpty
            ? "/"
            : _currentDir.path.split('/').last,
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            if (_currentDir.path != '/sdcard')
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text(".."),
                onTap: () {
                  setState(() {
                    _currentDir = _currentDir.parent;
                    _listDir();
                  });
                },
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final entity = _files[index];
                  final name = entity.path.split('/').last;
                  final isDir = entity is Directory;
                  return ListTile(
                    leading: Icon(
                      isDir ? Icons.folder : Icons.description,
                      color: isDir ? Colors.amber : Colors.blue,
                    ),
                    title: Text(name),
                    onTap: () {
                      if (isDir) {
                        setState(() {
                          _currentDir = entity as Directory;
                          _listDir();
                        });
                      } else {
                        widget.onFilePicked(entity.path);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
