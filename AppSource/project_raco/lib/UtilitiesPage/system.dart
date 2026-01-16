import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';
import 'utils.dart';

class SystemPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const SystemPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _SystemPageState createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  bool _isLoading = true;
  bool? _dndEnabled;
  bool? _anyaThermalEnabled;
  bool _isAnyaIncluded = true;
  Map<String, dynamic>? _bypassChargingState;
  Map<String, dynamic>? _resolutionState;
  Map<String, dynamic>? _screenModifierState;
  int _graphicsDriverValue = 0; // 0: Default, 1: Game, 2: Developer

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<bool> _loadDndState() async {
    final result = await runRootCommandAndWait(
      'cat /data/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final match = RegExp(
        r'^DND=(.*)$',
        multiLine: true,
      ).firstMatch(result.stdout.toString());
      return match?.group(1)?.trim().toLowerCase() == 'yes';
    }
    return false;
  }

  Future<bool> _loadAnyaThermalState() async {
    final result = await runRootCommandAndWait(
      'cat /data/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final match = RegExp(
        r'^ANYA=(\d)',
        multiLine: true,
      ).firstMatch(result.stdout.toString());
      return match?.group(1) == '1';
    }
    return false;
  }

  Future<bool> _loadAnyaInclusionState() async {
    final result = await runRootCommandAndWait(
      'cat /data/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final content = result.stdout.toString();
      final match = RegExp(
        r'^INCLUDE_ANYA=(\d)',
        multiLine: true,
      ).firstMatch(content);
      return match?.group(1) != '0';
    }
    return true;
  }

  Future<Map<String, dynamic>> _loadResolutionState() async {
    final results = await Future.wait([
      runRootCommandAndWait('wm size'),
      runRootCommandAndWait('wm density'),
    ]);
    final sr = results[0];
    final dr = results[1];

    // Check basic availability based on Physical size/density presence
    bool available =
        sr.exitCode == 0 &&
        sr.stdout.toString().contains('Physical size:') &&
        dr.exitCode == 0 &&
        (dr.stdout.toString().contains('Physical density:') ||
            dr.stdout.toString().contains('Override density:'));

    String originalSize = '';
    String currentSize = '';
    int originalDensity = 0;

    if (available) {
      final srOutput = sr.stdout.toString();

      // Parse Physical Size (Original)
      originalSize =
          RegExp(
            r'Physical size:\s*([0-9]+x[0-9]+)',
          ).firstMatch(srOutput)?.group(1) ??
          '';

      // Parse Override Size (Current - if modified)
      final overrideMatch = RegExp(
        r'Override size:\s*([0-9]+x[0-9]+)',
      ).firstMatch(srOutput);

      // If override exists, that is the current size. Otherwise, current is original.
      currentSize = overrideMatch?.group(1) ?? originalSize;

      originalDensity =
          int.tryParse(
            RegExp(
                  r'(?:Physical|Override) density:\s*([0-9]+)',
                ).firstMatch(dr.stdout.toString())?.group(1) ??
                '',
          ) ??
          0;

      if (originalSize.isEmpty || originalDensity == 0) available = false;
    }

    return {
      'isAvailable': available,
      'originalSize': originalSize,
      'currentSize': currentSize,
      'originalDensity': originalDensity,
    };
  }

  Future<Map<String, dynamic>> _loadBypassChargingState() async {
    final results = await Future.wait([
      runRootCommandAndWait(
        'sh /data/adb/modules/ProjectRaco/Scripts/raco_bypass_controller.sh test',
      ),
      runRootCommandAndWait('cat /data/ProjectRaco/raco.txt'),
    ]);
    final supportResult = results[0];
    final configResult = results[1];
    bool isSupported = supportResult.stdout.toString().toLowerCase().contains(
      'supported',
    );
    bool isEnabled = false;
    if (configResult.exitCode == 0) {
      isEnabled =
          RegExp(r'^ENABLE_BYPASS=(Yes|No)', multiLine: true)
              .firstMatch(configResult.stdout.toString())
              ?.group(1)
              ?.toLowerCase() ==
          'yes';
    }
    return {'isSupported': isSupported, 'isEnabled': isEnabled};
  }

  Future<Map<String, dynamic>> _loadScreenModifierState() async {
    double red = 1000.0, green = 1000.0, blue = 1000.0, saturation = 1000.0;
    bool applyOnBoot = false;

    final serviceFileCheckCommand =
        'grep -q "AyundaRusdi.sh" /data/adb/modules/ProjectRaco/service.sh';
    final results = await Future.wait([
      runRootCommandAndWait('cat /data/ProjectRaco/raco.txt'),
      runRootCommandAndWait(serviceFileCheckCommand),
    ]);

    final racoResult = results[0];
    final serviceCheckResult = results[1];

    applyOnBoot = serviceCheckResult.exitCode == 0;

    if (racoResult.exitCode == 0) {
      final match = RegExp(
        r'^AYUNDA_RUSDI=([\d,]+,(?:Yes|No))$',
        multiLine: true,
      ).firstMatch(racoResult.stdout.toString());

      if (match != null) {
        final parts = match.group(1)!.split(',');
        if (parts.length >= 4) {
          red = double.tryParse(parts[0]) ?? 1000.0;
          green = double.tryParse(parts[1]) ?? 1000.0;
          blue = double.tryParse(parts[2]) ?? 1000.0;
          saturation = double.tryParse(parts[3]) ?? 1000.0;
        }
      }
    }

    final valuesString =
        '${red.round()},${green.round()},${blue.round()},${saturation.round()},${applyOnBoot ? "Yes" : "No"}';
    final sedCheckCommand =
        "grep -q '^AYUNDA_RUSDI=' /data/ProjectRaco/raco.txt";
    final checkResult = await runRootCommandAndWait(sedCheckCommand);
    if (checkResult.exitCode == 0) {
      await runRootCommandAndWait(
        "sed -i 's|^AYUNDA_RUSDI=.*|AYUNDA_RUSDI=$valuesString|' /data/ProjectRaco/raco.txt",
      );
    } else {
      await runRootCommandAndWait(
        "echo 'AYUNDA_RUSDI=$valuesString' >> /data/ProjectRaco/raco.txt",
      );
    }

    return {
      'red': red,
      'green': green,
      'blue': blue,
      'saturation': saturation,
      'applyOnBoot': applyOnBoot,
    };
  }

  Future<int> _loadGraphicsDriverState() async {
    final result = await runRootCommandAndWait(
      'settings get global updatable_driver_all_apps',
    );
    if (result.exitCode == 0) {
      return int.tryParse(result.stdout.toString().trim()) ?? 0;
    }
    return 0;
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _loadDndState(),
      _loadAnyaThermalState(),
      _loadAnyaInclusionState(),
      _loadBypassChargingState(),
      _loadResolutionState(),
      _loadScreenModifierState(),
      _loadGraphicsDriverState(),
    ]);

    if (!mounted) return;
    setState(() {
      _dndEnabled = results[0] as bool;
      _anyaThermalEnabled = results[1] as bool;
      _isAnyaIncluded = results[2] as bool;
      _bypassChargingState = results[3] as Map<String, dynamic>;
      _resolutionState = results[4] as Map<String, dynamic>;
      _screenModifierState = results[5] as Map<String, dynamic>;
      _graphicsDriverValue = results[6] as int;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.system_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        cacheExtent: 1000,
        children: [
          DndCard(initialDndEnabled: _dndEnabled ?? false),
          if (_isAnyaIncluded)
            AnyaThermalCard(
              initialAnyaThermalEnabled: _anyaThermalEnabled ?? false,
            ),
          BypassChargingCard(
            isSupported: _bypassChargingState?['isSupported'] ?? false,
            isEnabled: _bypassChargingState?['isEnabled'] ?? false,
            supportStatus: _bypassChargingState?['isSupported'] ?? false
                ? localization.bypass_charging_supported
                : localization.bypass_charging_unsupported,
          ),
          GraphicsDriverCard(initialValue: _graphicsDriverValue),
          ResolutionCard(
            isAvailable: _resolutionState?['isAvailable'] ?? false,
            originalSize: _resolutionState?['originalSize'] ?? '',
            currentSize: _resolutionState?['currentSize'] ?? '',
            originalDensity: _resolutionState?['originalDensity'] ?? 0,
          ),
          ScreenModifierCard(
            initialValues:
                _screenModifierState ??
                {
                  'red': 1000.0,
                  'green': 1000.0,
                  'blue': 1000.0,
                  'saturation': 1000.0,
                  'applyOnBoot': false,
                },
          ),
          const SystemActionsCard(),
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

class DndCard extends StatefulWidget {
  final bool initialDndEnabled;
  const DndCard({Key? key, required this.initialDndEnabled}) : super(key: key);
  @override
  _DndCardState createState() => _DndCardState();
}

class _DndCardState extends State<DndCard> with AutomaticKeepAliveClientMixin {
  late bool _dndEnabled;
  bool _isUpdating = false;
  final String _configFilePath = '/data/ProjectRaco/raco.txt';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dndEnabled = widget.initialDndEnabled;
  }

  Future<void> _toggleDnd(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isUpdating = true);
    final valueString = enable ? 'Yes' : 'No';

    try {
      final sedCommand =
          "sed -i 's|^DND=.*|DND=$valueString|' $_configFilePath";
      final result = await runRootCommandAndWait(sedCommand);
      if (result.exitCode == 0) {
        if (mounted) setState(() => _dndEnabled = enable);
      } else {
        throw Exception('Failed to write to config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update DND setting: $e')),
        );
        setState(() => _dndEnabled = widget.initialDndEnabled);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for KeepAlive
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
              localization.dnd_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.dnd_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.dnd_toggle_title),
              value: _dndEnabled,
              onChanged: _isUpdating ? null : _toggleDnd,
              secondary: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.do_not_disturb_on_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class AnyaThermalCard extends StatefulWidget {
  final bool initialAnyaThermalEnabled;
  const AnyaThermalCard({Key? key, required this.initialAnyaThermalEnabled})
    : super(key: key);
  @override
  _AnyaThermalCardState createState() => _AnyaThermalCardState();
}

class _AnyaThermalCardState extends State<AnyaThermalCard>
    with AutomaticKeepAliveClientMixin {
  late bool _isEnabled;
  bool _isUpdating = false;
  final String _configFilePath = '/data/ProjectRaco/raco.txt';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialAnyaThermalEnabled;
  }

  Future<void> _toggleAnyaThermal(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isUpdating = true);

    final valueString = enable ? '1' : '0';
    final scriptPath = enable
        ? '/data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh'
        : '/data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh';

    try {
      await runRootCommandAndWait(scriptPath);
      final sedCommand =
          "sed -i 's|^ANYA=.*|ANYA=$valueString|' $_configFilePath";
      final result = await runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _isEnabled = enable);
      } else {
        throw Exception('Failed to write to config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update thermal setting: $e')),
        );
        setState(() => _isEnabled = widget.initialAnyaThermalEnabled);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
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
              localization.anya_thermal_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.anya_thermal_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.anya_thermal_toggle_title),
              value: _isEnabled,
              onChanged: _isUpdating ? null : _toggleAnyaThermal,
              secondary: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.thermostat_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class BypassChargingCard extends StatefulWidget {
  final bool isSupported;
  final bool isEnabled;
  final String supportStatus;
  const BypassChargingCard({
    Key? key,
    required this.isSupported,
    required this.isEnabled,
    required this.supportStatus,
  }) : super(key: key);
  @override
  _BypassChargingCardState createState() => _BypassChargingCardState();
}

class _BypassChargingCardState extends State<BypassChargingCard>
    with AutomaticKeepAliveClientMixin {
  late bool _isEnabled;
  bool _isToggling = false;

  final String _configFilePath = '/data/ProjectRaco/raco.txt';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.isEnabled;
  }

  Future<void> _toggleBypass(bool enable) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isToggling = true);

    try {
      final value = enable ? 'Yes' : 'No';
      final sedCommand =
          "sed -i 's|^ENABLE_BYPASS=.*|ENABLE_BYPASS=$value|' $_configFilePath";
      await runRootCommandAndWait(sedCommand);

      if (mounted) setState(() => _isEnabled = enable);
    } finally {
      if (mounted) setState(() => _isToggling = false);
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
              localization.bypass_charging_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.bypass_charging_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.supportStatus,
                style: textTheme.bodyMedium?.copyWith(
                  color: widget.isSupported ? Colors.green : colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(localization.bypass_charging_toggle),
              value: _isEnabled,
              onChanged: (_isToggling || !widget.isSupported)
                  ? null
                  : _toggleBypass,
              secondary: _isToggling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class GraphicsDriverCard extends StatefulWidget {
  final int initialValue;
  const GraphicsDriverCard({Key? key, required this.initialValue})
    : super(key: key);

  @override
  _GraphicsDriverCardState createState() => _GraphicsDriverCardState();
}

class _GraphicsDriverCardState extends State<GraphicsDriverCard>
    with AutomaticKeepAliveClientMixin {
  late int _currentValue;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  Future<void> _updateDriver(int value) async {
    if (!await checkRootAccess()) return;
    try {
      await runRootCommandAndWait(
        'settings put global updatable_driver_all_apps $value',
      );
      if (mounted) setState(() => _currentValue = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update driver setting: $e')),
        );
      }
    }
  }

  String _getDriverName(int value, AppLocalizations localization) {
    switch (value) {
      case 1:
        return localization.graphics_driver_game;
      case 2:
        return localization.graphics_driver_developer;
      case 0:
      default:
        return localization.graphics_driver_default;
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
              localization.graphics_driver_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.graphics_driver_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              "${localization.current_driver} ${_getDriverName(_currentValue, localization)}",
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  onPressed: () => _updateDriver(0),
                  child: Text(localization.graphics_driver_default),
                  style: _currentValue == 0
                      ? OutlinedButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _updateDriver(1),
                  child: Text(localization.graphics_driver_game),
                  style: _currentValue == 1
                      ? OutlinedButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _updateDriver(2),
                  child: Text(localization.graphics_driver_developer),
                  style: _currentValue == 2
                      ? OutlinedButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResolutionCard extends StatefulWidget {
  final bool isAvailable;
  final String originalSize;
  final String currentSize;
  final int originalDensity;
  const ResolutionCard({
    Key? key,
    required this.isAvailable,
    required this.originalSize,
    required this.currentSize,
    required this.originalDensity,
  }) : super(key: key);
  @override
  _ResolutionCardState createState() => _ResolutionCardState();
}

class _ResolutionCardState extends State<ResolutionCard>
    with AutomaticKeepAliveClientMixin {
  bool _isChanging = false;
  late double _currentValue;
  final List<int> _percentages = [50, 60, 70, 80, 90, 100];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _calculateInitialValue();
  }

  void _calculateInitialValue() {
    // Default to max if data invalid
    if (!widget.isAvailable ||
        widget.originalSize.isEmpty ||
        widget.currentSize.isEmpty) {
      _currentValue = (_percentages.length - 1).toDouble();
      return;
    }

    try {
      // Parse width from strings "WxH"
      final originalWidth = int.parse(widget.originalSize.split('x')[0]);
      final currentWidth = int.parse(widget.currentSize.split('x')[0]);

      // Calculate current percentage
      final currentPct = ((currentWidth / originalWidth) * 100).round();

      // Find the closest supported percentage in our list
      final closestPct = _percentages.reduce((a, b) {
        return (a - currentPct).abs() < (b - currentPct).abs() ? a : b;
      });

      final index = _percentages.indexOf(closestPct);
      _currentValue = index >= 0
          ? index.toDouble()
          : (_percentages.length - 1).toDouble();
    } catch (e) {
      _currentValue = (_percentages.length - 1).toDouble();
    }
  }

  String _getCurrentPercentageLabel() {
    int idx = _currentValue.round().clamp(0, _percentages.length - 1);
    return '${_percentages[idx]}%';
  }

  Future<void> _applyResolution(double value) async {
    if (!widget.isAvailable ||
        widget.originalSize.isEmpty ||
        widget.originalDensity <= 0)
      return;
    if (mounted) setState(() => _isChanging = true);

    final idx = value.round().clamp(0, _percentages.length - 1);
    final pct = _percentages[idx];

    try {
      final parts = widget.originalSize.split('x');
      final newW = (int.parse(parts[0]) * pct / 100).floor();
      final newH = (int.parse(parts[1]) * pct / 100).floor();
      final newD = (widget.originalDensity * pct / 100).floor();

      if (newW <= 0 || newH <= 0 || newD <= 0) throw Exception('Invalid dims');

      await runRootCommandAndWait('wm size ${newW}x$newH');
      await runRootCommandAndWait('wm density $newD');

      if (mounted) setState(() => _currentValue = value);
    } catch (e) {
      await _resetResolution();
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  Future<void> _resetResolution({bool showSnackbar = true}) async {
    if (!widget.isAvailable) return;
    if (mounted) setState(() => _isChanging = true);
    try {
      await runRootCommandAndWait('wm size reset');
      await runRootCommandAndWait('wm density reset');
      if (mounted) {
        setState(() => _currentValue = (_percentages.length - 1).toDouble());
      }
    } finally {
      if (mounted) setState(() => _isChanging = false);
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
              localization.downscale_resolution,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!widget.isAvailable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  localization.resolution_unavailable_message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              Row(
                children: [
                  Icon(
                    Icons.aspect_ratio_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: _currentValue,
                      min: 0,
                      max: (_percentages.length - 1).toDouble(),
                      divisions: _percentages.length - 1,
                      label: _getCurrentPercentageLabel(),
                      onChanged: _isChanging
                          ? null
                          : (double value) {
                              if (mounted) {
                                setState(() => _currentValue = value);
                              }
                            },
                      onChangeEnd: _isChanging ? null : _applyResolution,
                    ),
                  ),
                  Text(
                    _getCurrentPercentageLabel(),
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChanging ? null : _resetResolution,
                  icon: _isChanging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(localization.reset_resolution),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ScreenModifierCard extends StatefulWidget {
  final Map<String, dynamic> initialValues;
  const ScreenModifierCard({Key? key, required this.initialValues})
    : super(key: key);

  @override
  _ScreenModifierCardState createState() => _ScreenModifierCardState();
}

class _ScreenModifierCardState extends State<ScreenModifierCard>
    with AutomaticKeepAliveClientMixin {
  late double _redValue;
  late double _greenValue;
  late double _blueValue;
  late double _saturationValue;
  late bool _applyOnBoot;
  bool _isUpdating = false;

  final String _configFilePath = '/data/ProjectRaco/raco.txt';
  final String _serviceFilePath = '/data/adb/modules/ProjectRaco/service.sh';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _redValue = widget.initialValues['red'] as double;
    _greenValue = widget.initialValues['green'] as double;
    _blueValue = widget.initialValues['blue'] as double;
    _saturationValue = widget.initialValues['saturation'] as double;
    _applyOnBoot = widget.initialValues['applyOnBoot'] as bool;
  }

  Future<void> _applyAndSaveChanges() async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isUpdating = true);

    try {
      // Apply live changes
      final r = _redValue / 1000.0;
      final g = _greenValue / 1000.0;
      final b = _blueValue / 1000.0;
      final s = _saturationValue / 1000.0;

      await runRootCommandAndWait(
        'service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1',
      );
      await runRootCommandAndWait('service call SurfaceFlinger 1022 f $s');

      // Save settings to raco.txt
      final valuesString =
          '${_redValue.round()},${_greenValue.round()},${_blueValue.round()},${_saturationValue.round()},${_applyOnBoot ? "Yes" : "No"}';
      final sedCheckCommand = "grep -q '^AYUNDA_RUSDI=' $_configFilePath";
      final checkResult = await runRootCommandAndWait(sedCheckCommand);

      if (checkResult.exitCode == 0) {
        // Line exists, so replace it
        await runRootCommandAndWait(
          "sed -i 's|^AYUNDA_RUSDI=.*|AYUNDA_RUSDI=$valuesString|' $_configFilePath",
        );
      } else {
        // Line doesn't exist, so add it
        await runRootCommandAndWait(
          "echo 'AYUNDA_RUSDI=$valuesString' >> $_configFilePath",
        );
      }

      // Update service.sh for boot settings
      await _updateBootScript();
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateBootScript() async {
    final ayundaScriptPath =
        '/data/adb/modules/ProjectRaco/Scripts/AyundaRusdi.sh';

    // To ensure idempotency, always remove the old execution line first.
    final removeExecutionLineCommand =
        "sed -i '/AyundaRusdi.sh/d' $_serviceFilePath";
    await runRootCommandAndWait(removeExecutionLineCommand);

    if (_applyOnBoot) {
      // If the toggle is ON, recreate AyundaRusdi.sh with current values...
      final r = _redValue / 1000.0;
      final g = _greenValue / 1000.0;
      final b = _blueValue / 1000.0;
      final s = _saturationValue / 1000.0;

      // 1. Create or overwrite AyundaRusdi.sh with the current color values.
      final createAyundaScriptCommand =
          '''
cat <<'EOF' > $ayundaScriptPath
#!/system/bin/sh
# Project Raco - Screen Modifier Boot Settings
# This file is automatically generated by the app. Do not edit manually.

# Apply Screen Color Matrix (RGB)
service call SurfaceFlinger 1015 i32 1 f $r f 0 f 0 f 0 f 0 f $g f 0 f 0 f 0 f 0 f $b f 0 f 0 f 0 f 0 f 1

# Apply Screen Saturation
service call SurfaceFlinger 1022 f $s
EOF
''';
      await runRootCommandAndWait(createAyundaScriptCommand);

      // Make the script executable
      await runRootCommandAndWait('chmod +x $ayundaScriptPath');

      // 2. ...and then insert a line into service.sh to execute it on boot.
      final addExecutionLineCommand =
          "sed -i '/# Ayunda Rusdi/a sh $ayundaScriptPath' $_serviceFilePath";
      await runRootCommandAndWait(addExecutionLineCommand);
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      _redValue = 1000.0;
      _greenValue = 1000.0;
      _blueValue = 1000.0;
      _saturationValue = 1000.0;
    });
    await _applyAndSaveChanges();
  }

  Widget _buildSlider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 100,
            max: max,
            divisions: ((max - 100) / 10).round(),
            label: value.round().toString(),
            onChanged: (newValue) {
              setState(() {
                if (label == AppLocalizations.of(context)!.screen_modifier_red)
                  _redValue = newValue;
                if (label ==
                    AppLocalizations.of(context)!.screen_modifier_green)
                  _greenValue = newValue;
                if (label == AppLocalizations.of(context)!.screen_modifier_blue)
                  _blueValue = newValue;
                if (label ==
                    AppLocalizations.of(context)!.screen_modifier_saturation)
                  _saturationValue = newValue;
              });
            },
            onChangeEnd: (newValue) => _applyAndSaveChanges(),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(value.round().toString(), textAlign: TextAlign.end),
        ),
      ],
    );
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
              localization.screen_modifier_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.screen_modifier_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              localization.screen_modifier_red,
              _redValue,
              1000,
              (v) => setState(() => _redValue = v),
            ),
            _buildSlider(
              localization.screen_modifier_green,
              _greenValue,
              1000,
              (v) => setState(() => _greenValue = v),
            ),
            _buildSlider(
              localization.screen_modifier_blue,
              _blueValue,
              1000,
              (v) => setState(() => _blueValue = v),
            ),
            _buildSlider(
              localization.screen_modifier_saturation,
              _saturationValue,
              2000,
              (v) => setState(() => _saturationValue = v),
            ),
            const Divider(height: 24),
            SwitchListTile(
              title: Text(localization.screen_modifier_apply_on_boot),
              value: _applyOnBoot,
              onChanged: _isUpdating
                  ? null
                  : (value) {
                      setState(() => _applyOnBoot = value);
                      _applyAndSaveChanges();
                    },
              secondary: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.power_settings_new_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _resetToDefaults,
                icon: const Icon(Icons.refresh),
                label: Text(localization.screen_modifier_reset),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SystemActionsCard extends StatefulWidget {
  const SystemActionsCard({Key? key}) : super(key: key);

  @override
  _SystemActionsCardState createState() => _SystemActionsCardState();
}

class _SystemActionsCardState extends State<SystemActionsCard>
    with AutomaticKeepAliveClientMixin {
  bool _isFstrimRunning = false;
  bool _isClearCacheRunning = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _runAction({
    required String command,
    required Function(bool) setLoadingState,
  }) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => setLoadingState(true));

    try {
      final result = await runRootCommandAndWait(command);
      if (result.exitCode != 0) {
        throw Exception(result.stderr);
      }
    } catch (e) {
      // Errors can be logged or handled here if necessary.
    } finally {
      if (mounted) setState(() => setLoadingState(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isBusy = _isFstrimRunning || _isClearCacheRunning;

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
              localization.system_actions_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Fstrim Action
            ListTile(
              leading: _isFstrimRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              title: Text(localization.fstrim_title),
              subtitle: Text(
                localization.fstrim_description,
                style: textTheme.bodySmall,
              ),
              trailing: ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () => _runAction(
                        command:
                            'su -c sh /data/adb/modules/ProjectRaco/Scripts/Fstrim.sh',
                        setLoadingState: (val) => _isFstrimRunning = val,
                      ),
                child: const Icon(Icons.play_arrow),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            // Clear Cache Action
            ListTile(
              leading: _isClearCacheRunning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
              title: Text(localization.clear_cache_title),
              trailing: ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () => _runAction(
                        command:
                            'su -c sh /data/adb/modules/ProjectRaco/Scripts/Clear_cache.sh',
                        setLoadingState: (val) => _isClearCacheRunning = val,
                      ),
                child: const Icon(Icons.play_arrow),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
