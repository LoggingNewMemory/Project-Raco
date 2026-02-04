import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';

class RacoExtraPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const RacoExtraPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _RacoExtraPageState createState() => _RacoExtraPageState();
}

class _RacoExtraPageState extends State<RacoExtraPage> {
  bool _isLoading = true;

  // Config Flags
  bool _includeAnya = false;
  bool _includeKobo = false;
  bool _includeSandev = false;
  bool _includeZetamin = false;

  final String _configPath = '/data/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final result = await Process.run('su', ['-c', 'cat $_configPath']);
      if (result.exitCode == 0) {
        final content = result.stdout.toString();
        if (mounted) {
          setState(() {
            _includeAnya = _parseFlag(content, 'INCLUDE_ANYA');
            _includeKobo = _parseFlag(content, 'INCLUDE_KOBO');
            _includeSandev = _parseFlag(content, 'INCLUDE_SANDEV');
            _includeZetamin = _parseFlag(content, 'INCLUDE_ZETAMIN');
            _isLoading = false;
          });
        }
      } else {
        // Handle file not found or no root
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading raco extra config: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _parseFlag(String content, String key) {
    final regex = RegExp('^$key=(.*)\$', multiLine: true);
    final match = regex.firstMatch(content);
    if (match != null && match.groupCount >= 1) {
      final val = match.group(1)?.trim();
      return val == '1';
    }
    return false;
  }

  Future<void> _updateConfig(String key, bool value) async {
    final intVal = value ? 1 : 0;

    // Update local state first for responsiveness
    setState(() {
      if (key == 'INCLUDE_ANYA')
        _includeAnya = value;
      else if (key == 'INCLUDE_KOBO')
        _includeKobo = value;
      else if (key == 'INCLUDE_SANDEV')
        _includeSandev = value;
      else if (key == 'INCLUDE_ZETAMIN')
        _includeZetamin = value;
    });

    try {
      // Use sed to replace the specific line
      await Process.run('su', [
        '-c',
        "sed -i 's/^$key=.*/$key=$intVal/' $_configPath",
      ]);
    } catch (e) {
      print('Error updating $key: $e');
      // Revert state if failed
      await _loadConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.extra_settings_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          _buildSwitchTile(
            title: localization.anya_installer_title,
            subtitle: localization.anya_installer_desc,
            value: _includeAnya,
            onChanged: (v) => _updateConfig('INCLUDE_ANYA', v),
            icon: Icons.thermostat,
          ),
          _buildSwitchTile(
            title: localization.kobo_title,
            subtitle: localization.kobo_desc,
            value: _includeKobo,
            onChanged: (v) => _updateConfig('INCLUDE_KOBO', v),
            icon: Icons.battery_charging_full,
          ),
          _buildSwitchTile(
            title: localization.zetamin_title,
            subtitle: localization.zetamin_desc,
            value: _includeZetamin,
            onChanged: (v) => _updateConfig('INCLUDE_ZETAMIN', v),
            icon: Icons.display_settings,
          ),
          _buildSwitchTile(
            title: localization.sandev_boot_title,
            subtitle: localization.sandev_boot_desc,
            value: _includeSandev,
            onChanged: (v) => _updateConfig('INCLUDE_SANDEV', v),
            icon: Icons.rocket_launch,
          ),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SwitchListTile(
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      ),
    );
  }
}
