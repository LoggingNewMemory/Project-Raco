import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isSandevistanIncluded = false;
  Map<String, dynamic>? _bypassChargingState;
  Map<String, dynamic>? _resolutionState;
  Map<String, dynamic>? _screenModifierState;
  int _graphicsDriverValue = 0; // 0: Default, 1: Game, 2: Developer
  int _sandevistanDuration = 10;

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

  Future<Map<String, dynamic>> _loadSandevistanState() async {
    final result = await runRootCommandAndWait(
      'cat /data/ProjectRaco/raco.txt',
    );
    bool included = false;
    int duration = 10;

    if (result.exitCode == 0) {
      final content = result.stdout.toString();
      final includeMatch = RegExp(
        r'^INCLUDE_SANDEV=(\d)',
        multiLine: true,
      ).firstMatch(content);
      included = includeMatch?.group(1) == '1';

      final durMatch = RegExp(
        r'^SANDEV_DUR=(\d+)',
        multiLine: true,
      ).firstMatch(content);
      if (durMatch != null) {
        duration = int.tryParse(durMatch.group(1)!) ?? 10;
      }
    }
    return {'included': included, 'duration': duration};
  }

  Future<Map<String, dynamic>> _loadResolutionState() async {
    final results = await Future.wait([
      runRootCommandAndWait('wm size'),
      runRootCommandAndWait('wm density'),
    ]);
    final sr = results[0];
    final dr = results[1];

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
      originalSize =
          RegExp(
            r'Physical size:\s*([0-9]+x[0-9]+)',
          ).firstMatch(srOutput)?.group(1) ??
          '';
      final overrideMatch = RegExp(
        r'Override size:\s*([0-9]+x[0-9]+)',
      ).firstMatch(srOutput);
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
      _loadSandevistanState(),
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
      final sandevResult = results[7] as Map<String, dynamic>;
      _isSandevistanIncluded = sandevResult['included'];
      _sandevistanDuration = sandevResult['duration'];
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
        children: [
          DndCard(initialDndEnabled: _dndEnabled ?? false),
          if (_isAnyaIncluded)
            AnyaThermalCard(
              initialAnyaThermalEnabled: _anyaThermalEnabled ?? false,
            ),
          if (_isSandevistanIncluded)
            SandevistanDurationCard(initialDuration: _sandevistanDuration),
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
                errorBuilder: (c, e, s) => Container(),
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

// --- SUB-CARDS ---

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
      await runRootCommandAndWait(
        "sed -i 's|^DND=.*|DND=$valueString|' $_configFilePath",
      );
      if (mounted) setState(() => _dndEnabled = enable);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.dnd_title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.dnd_toggle_title),
              value: _dndEnabled,
              onChanged: _isUpdating ? null : _toggleDnd,
              secondary: const Icon(Icons.do_not_disturb_on_outlined),
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
    final script = enable ? 'AnyaMelfissa.sh' : 'AnyaKawaii.sh';

    try {
      await runRootCommandAndWait(
        'sh /data/adb/modules/ProjectRaco/Scripts/$script',
      );
      await runRootCommandAndWait(
        "sed -i 's|^ANYA=.*|ANYA=$valueString|' $_configFilePath",
      );
      if (mounted) setState(() => _isEnabled = enable);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.anya_thermal_title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(localization.anya_thermal_toggle_title),
              value: _isEnabled,
              onChanged: _isUpdating ? null : _toggleAnyaThermal,
              secondary: const Icon(Icons.thermostat_outlined),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class SandevistanDurationCard extends StatefulWidget {
  final int initialDuration;
  const SandevistanDurationCard({Key? key, required this.initialDuration})
    : super(key: key);
  @override
  _SandevistanDurationCardState createState() =>
      _SandevistanDurationCardState();
}

class _SandevistanDurationCardState extends State<SandevistanDurationCard>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _controller;
  bool _isSaving = false;
  String _easterEggMessage = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialDuration.toString(),
    );
    _controller.addListener(_updateEasterEgg);
  }

  void _updateEasterEgg() {
    final value = int.tryParse(_controller.text);
    if (value == null) {
      if (mounted) setState(() => _easterEggMessage = '');
      return;
    }
    final loc = AppLocalizations.of(context)!;
    String msg = '';
    if (value < 10)
      msg = loc.sandev_egg_useless;
    else if (value == 10)
      msg = loc.sandev_egg_original;
    else if (value <= 30)
      msg = loc.sandev_egg_better;
    else if (value <= 60)
      msg = loc.sandev_egg_david;
    else
      msg = loc.sandev_egg_smasher;
    if (mounted) setState(() => _easterEggMessage = msg);
  }

  Future<void> _saveDuration() async {
    final val = int.tryParse(_controller.text);
    if (val == null || val < 0) return;
    if (!await checkRootAccess()) return;
    setState(() => _isSaving = true);
    try {
      final check = await runRootCommandAndWait(
        "grep -q '^SANDEV_DUR=' /data/ProjectRaco/raco.txt",
      );
      if (check.exitCode == 0) {
        await runRootCommandAndWait(
          "sed -i 's|^SANDEV_DUR=.*|SANDEV_DUR=$val|' /data/ProjectRaco/raco.txt",
        );
      } else {
        await runRootCommandAndWait(
          "echo 'SANDEV_DUR=$val' >> /data/ProjectRaco/raco.txt",
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.sandevistan_duration_title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: localization.sandevistan_duration_hint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveDuration,
                  child: const Icon(Icons.save),
                ),
              ],
            ),
            if (_easterEggMessage.isNotEmpty)
              Text(
                _easterEggMessage,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
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
  final String _scriptPath =
      '/data/adb/modules/ProjectRaco/Scripts/raco_bypass_controller.sh';

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
      // 1. Update config file
      await runRootCommandAndWait(
        "sed -i 's|^ENABLE_BYPASS=.*|ENABLE_BYPASS=$value|' $_configFilePath",
      );

      // 2. If disabling, run the hardware command immediately.
      // If enabling, mode switching (Raco.sh) handles it.
      if (!enable) {
        await runRootCommandAndWait('sh $_scriptPath disable');
      }

      if (mounted) setState(() => _isEnabled = enable);
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.bypass_charging_title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.supportStatus,
                style: TextStyle(
                  color: widget.isSupported ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              title: Text(localization.bypass_charging_toggle),
              value: _isEnabled,
              onChanged: (_isToggling || !widget.isSupported)
                  ? null
                  : _toggleBypass,
              secondary: const Icon(Icons.bolt_outlined),
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
    await runRootCommandAndWait(
      'settings put global updatable_driver_all_apps $value',
    );
    setState(() => _currentValue = value);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localization.graphics_driver_title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [0, 1, 2]
                  .map(
                    (v) => ChoiceChip(
                      label: Text(
                        v == 0
                            ? localization.graphics_driver_default
                            : v == 1
                            ? localization.graphics_driver_game
                            : localization.graphics_driver_developer,
                      ),
                      selected: _currentValue == v,
                      onSelected: (s) => _updateDriver(v),
                    ),
                  )
                  .toList(),
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
    if (!widget.isAvailable || widget.originalSize.isEmpty) {
      _currentValue = 5.0;
      return;
    }
    try {
      final ow = int.parse(widget.originalSize.split('x')[0]);
      final cw = int.parse(widget.currentSize.split('x')[0]);
      final pct = ((cw / ow) * 100).round();
      final closest = _percentages.reduce(
        (a, b) => (a - pct).abs() < (b - pct).abs() ? a : b,
      );
      _currentValue = _percentages.indexOf(closest).toDouble();
    } catch (e) {
      _currentValue = 5.0;
    }
  }

  Future<void> _apply(double value) async {
    setState(() => _isChanging = true);
    final pct = _percentages[value.round()];
    final parts = widget.originalSize.split('x');
    final nw = (int.parse(parts[0]) * pct / 100).floor();
    final nh = (int.parse(parts[1]) * pct / 100).floor();
    final nd = (widget.originalDensity * pct / 100).floor();
    await runRootCommandAndWait('wm size ${nw}x$nh');
    await runRootCommandAndWait('wm density $nd');
    setState(() {
      _currentValue = value;
      _isChanging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              localization.downscale_resolution,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Slider(
              value: _currentValue,
              min: 0,
              max: 5,
              divisions: 5,
              label: '${_percentages[_currentValue.round()]}%',
              onChanged: _isChanging
                  ? null
                  : (v) => setState(() => _currentValue = v),
              onChangeEnd: _apply,
            ),
            ElevatedButton(
              onPressed: () => _apply(5.0),
              child: Text(localization.reset_resolution),
            ),
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
  late double _r, _g, _b, _s;
  late bool _boot;
  bool _updating = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _r = widget.initialValues['red'];
    _g = widget.initialValues['green'];
    _b = widget.initialValues['blue'];
    _s = widget.initialValues['saturation'];
    _boot = widget.initialValues['applyOnBoot'];
  }

  Future<void> _apply() async {
    setState(() => _updating = true);
    final rf = _r / 1000, gf = _g / 1000, bf = _b / 1000, sf = _s / 1000;
    await runRootCommandAndWait(
      'service call SurfaceFlinger 1015 i32 1 f $rf f 0 f 0 f 0 f 0 f $gf f 0 f 0 f 0 f 0 f $bf f 0 f 0 f 0 f 0 f 1',
    );
    await runRootCommandAndWait('service call SurfaceFlinger 1022 f $sf');
    final valStr =
        '${_r.round()},${_g.round()},${_b.round()},${_s.round()},${_boot ? "Yes" : "No"}';
    await runRootCommandAndWait(
      "sed -i 's|^AYUNDA_RUSDI=.*|AYUNDA_RUSDI=$valStr|' /data/ProjectRaco/raco.txt",
    );

    // Update service.sh
    await runRootCommandAndWait(
      "sed -i '/AyundaRusdi.sh/d' /data/adb/modules/ProjectRaco/service.sh",
    );
    if (_boot) {
      final script =
          "cat <<'EOF' > /data/adb/modules/ProjectRaco/Scripts/AyundaRusdi.sh\n#!/system/bin/sh\nservice call SurfaceFlinger 1015 i32 1 f $rf f 0 f 0 f 0 f 0 f $gf f 0 f 0 f 0 f 0 f $bf f 0 f 0 f 0 f 0 f 1\nservice call SurfaceFlinger 1022 f $sf\nEOF";
      await runRootCommandAndWait(script);
      await runRootCommandAndWait(
        'chmod +x /data/adb/modules/ProjectRaco/Scripts/AyundaRusdi.sh',
      );
      await runRootCommandAndWait(
        "sed -i '/# Ayunda Rusdi/a sh /data/adb/modules/ProjectRaco/Scripts/AyundaRusdi.sh' /data/adb/modules/ProjectRaco/service.sh",
      );
    }
    setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              localization.screen_modifier_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Slider(
              value: _r,
              min: 100,
              max: 1000,
              onChanged: (v) => setState(() => _r = v),
              onChangeEnd: (v) => _apply(),
            ),
            Slider(
              value: _g,
              min: 100,
              max: 1000,
              onChanged: (v) => setState(() => _g = v),
              onChangeEnd: (v) => _apply(),
            ),
            Slider(
              value: _b,
              min: 100,
              max: 1000,
              onChanged: (v) => setState(() => _b = v),
              onChangeEnd: (v) => _apply(),
            ),
            Slider(
              value: _s,
              min: 100,
              max: 2000,
              onChanged: (v) => setState(() => _s = v),
              onChangeEnd: (v) => _apply(),
            ),
            SwitchListTile(
              title: Text(localization.screen_modifier_apply_on_boot),
              value: _boot,
              onChanged: (v) {
                setState(() => _boot = v);
                _apply();
              },
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
  bool _fstrim = false, _cache = false;
  @override
  bool get wantKeepAlive => true;
  Future<void> _run(String cmd, Function(bool) setL) async {
    setState(() => setL(true));
    await runRootCommandAndWait(
      'sh /data/adb/modules/ProjectRaco/Scripts/$cmd',
    );
    setState(() => setL(false));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final localization = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          ListTile(
            title: Text(localization.fstrim_title),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _fstrim
                  ? null
                  : () => _run('Fstrim.sh', (v) => _fstrim = v),
            ),
          ),
          ListTile(
            title: Text(localization.clear_cache_title),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _cache
                  ? null
                  : () => _run('Clear_cache.sh', (v) => _cache = v),
            ),
          ),
        ],
      ),
    );
  }
}
