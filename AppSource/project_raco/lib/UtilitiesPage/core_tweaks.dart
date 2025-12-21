import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';
import 'utils.dart';

class CoreTweaksPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const CoreTweaksPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _CoreTweaksPageState createState() => _CoreTweaksPageState();
}

class _CoreTweaksPageState extends State<CoreTweaksPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _encoreState;
  Map<String, dynamic>? _governorState;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Map<String, dynamic>> _loadEncoreSwitchState() async {
    final result = await runRootCommandAndWait(
      'cat /data/ProjectRaco/raco.txt',
    );
    if (result.exitCode == 0) {
      final content = result.stdout.toString();

      // For Carlotta CPU Mitigation:
      // Switch ON (Enabled) means KCPU_MITIGATE=0
      // Switch OFF (Disabled/Mitigation Active) means KCPU_MITIGATE=1
      final kcpuMitigateVal = RegExp(
        r'^KCPU_MITIGATE=(\d)',
        multiLine: true,
      ).firstMatch(content)?.group(1);

      final carlottaCpuEnabled = kcpuMitigateVal == '0';

      return {
        'deviceMitigation':
            RegExp(
              r'^DEVICE_MITIGATION=(\d)',
              multiLine: true,
            ).firstMatch(content)?.group(1) ==
            '1',
        'liteMode':
            RegExp(
              r'^LITE_MODE=(\d)',
              multiLine: true,
            ).firstMatch(content)?.group(1) ==
            '1',
        'betterPowersave':
            RegExp(
              r'^BETTER_POWERAVE=(\d)',
              multiLine: true,
            ).firstMatch(content)?.group(1) ==
            '1',
        'carlottaCpu': carlottaCpuEnabled,
      };
    }
    return {
      'deviceMitigation': false,
      'liteMode': false,
      'betterPowersave': false,
      'carlottaCpu': false,
    };
  }

  Future<Map<String, dynamic>> _loadGovernorState() async {
    final results = await Future.wait([
      runRootCommandAndWait(
        'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors',
      ),
      runRootCommandAndWait('cat /data/ProjectRaco/raco.txt'),
    ]);
    final governorsResult = results[0];
    final configResult = results[1];
    List<String> available =
        (governorsResult.exitCode == 0 &&
            governorsResult.stdout.toString().isNotEmpty)
        ? governorsResult.stdout.toString().trim().split(' ')
        : [];
    String? selected;
    if (configResult.exitCode == 0) {
      selected = RegExp(
        r'^GOV=(.*)$',
        multiLine: true,
      ).firstMatch(configResult.stdout.toString())?.group(1)?.trim();
    }
    return {'available': available, 'selected': selected};
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _loadEncoreSwitchState(),
      _loadGovernorState(),
    ]);

    if (!mounted) return;
    setState(() {
      _encoreState = results[0];
      _governorState = results[1];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.core_tweaks_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          FixAndTweakCard(
            initialDeviceMitigationValue:
                _encoreState?['deviceMitigation'] ?? false,
            initialLiteModeValue: _encoreState?['liteMode'] ?? false,
            initialBetterPowersaveValue:
                _encoreState?['betterPowersave'] ?? false,
            initialCarlottaCpuValue: _encoreState?['carlottaCpu'] ?? false,
          ),
          GovernorCard(
            initialAvailableGovernors: _governorState?['available'] ?? [],
            initialSelectedGovernor: _governorState?['selected'],
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
}

class FixAndTweakCard extends StatefulWidget {
  final bool initialDeviceMitigationValue;
  final bool initialLiteModeValue;
  final bool initialBetterPowersaveValue;
  final bool initialCarlottaCpuValue;

  const FixAndTweakCard({
    Key? key,
    required this.initialDeviceMitigationValue,
    required this.initialLiteModeValue,
    required this.initialBetterPowersaveValue,
    required this.initialCarlottaCpuValue,
  }) : super(key: key);

  @override
  _FixAndTweakCardState createState() => _FixAndTweakCardState();
}

class _FixAndTweakCardState extends State<FixAndTweakCard> {
  late bool _deviceMitigationEnabled;
  late bool _liteModeEnabled;
  late bool _betterPowersaveEnabled;
  late bool _carlottaCpuEnabled;

  bool _isUpdatingMitigation = false;
  bool _isUpdatingLiteMode = false;
  bool _isUpdatingBetterPowersave = false;
  bool _isUpdatingCarlottaCpu = false;

  final String _racoConfigFilePath = '/data/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _deviceMitigationEnabled = widget.initialDeviceMitigationValue;
    _liteModeEnabled = widget.initialLiteModeValue;
    _betterPowersaveEnabled = widget.initialBetterPowersaveValue;
    _carlottaCpuEnabled = widget.initialCarlottaCpuValue;
  }

  Future<void> _updateTweak({
    required String key,
    required bool enable,
    required Function(bool) stateSetter,
    required Function(bool) isUpdatingSetter,
    required bool initialValue,
    bool invertLogic = false,
  }) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => isUpdatingSetter(true));

    try {
      // If invertLogic is true: Enable(true) writes '0', Disable(false) writes '1'
      // If invertLogic is false: Enable(true) writes '1', Disable(false) writes '0'
      final value = invertLogic ? (enable ? '0' : '1') : (enable ? '1' : '0');

      final sedCommand =
          "sed -i 's|^$key=.*|$key=$value|' $_racoConfigFilePath";
      final result = await runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => stateSetter(enable));
      } else {
        throw Exception('Failed to write to the config file.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
        setState(() => stateSetter(initialValue));
      }
    } finally {
      if (mounted) setState(() => isUpdatingSetter(false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isBusy =
        _isUpdatingMitigation ||
        _isUpdatingLiteMode ||
        _isUpdatingBetterPowersave ||
        _isUpdatingCarlottaCpu;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.fix_and_tweak_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              title: Text(
                localization.device_mitigation_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.device_mitigation_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              value: _deviceMitigationEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'DEVICE_MITIGATION',
                      enable: enable,
                      stateSetter: (val) => _deviceMitigationEnabled = val,
                      isUpdatingSetter: (val) => _isUpdatingMitigation = val,
                      initialValue: widget.initialDeviceMitigationValue,
                    ),
              secondary: _isUpdatingMitigation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.security_update_warning_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(
                localization.lite_mode_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.lite_mode_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              value: _liteModeEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'LITE_MODE',
                      enable: enable,
                      stateSetter: (val) => _liteModeEnabled = val,
                      isUpdatingSetter: (val) => _isUpdatingLiteMode = val,
                      initialValue: widget.initialLiteModeValue,
                    ),
              secondary: _isUpdatingLiteMode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.energy_savings_leaf_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(
                localization.better_powersave_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.better_powersave_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              value: _betterPowersaveEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'BETTER_POWERAVE',
                      enable: enable,
                      stateSetter: (val) => _betterPowersaveEnabled = val,
                      isUpdatingSetter: (val) =>
                          _isUpdatingBetterPowersave = val,
                      initialValue: widget.initialBetterPowersaveValue,
                    ),
              secondary: _isUpdatingBetterPowersave
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.battery_saver_outlined),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: Text(
                localization.carlotta_cpu_title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                localization.carlotta_cpu_description,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
              value: _carlottaCpuEnabled,
              onChanged: isBusy
                  ? null
                  : (bool enable) => _updateTweak(
                      key: 'KCPU_MITIGATE',
                      enable: enable,
                      stateSetter: (val) => _carlottaCpuEnabled = val,
                      isUpdatingSetter: (val) => _isUpdatingCarlottaCpu = val,
                      initialValue: widget.initialCarlottaCpuValue,
                      invertLogic: true, // Enable writes 0, Disable writes 1
                    ),
              secondary: _isUpdatingCarlottaCpu
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.warning_amber_rounded),
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class GovernorCard extends StatefulWidget {
  final List<String> initialAvailableGovernors;
  final String? initialSelectedGovernor;

  const GovernorCard({
    Key? key,
    required this.initialAvailableGovernors,
    this.initialSelectedGovernor,
  }) : super(key: key);
  @override
  _GovernorCardState createState() => _GovernorCardState();
}

class _GovernorCardState extends State<GovernorCard> {
  late List<String> _availableGovernors;
  String? _selectedGovernor;
  bool _isSaving = false;
  final String _configFilePath = '/data/ProjectRaco/raco.txt';

  @override
  void initState() {
    super.initState();
    _availableGovernors = widget.initialAvailableGovernors;
    _selectedGovernor = widget.initialSelectedGovernor;
  }

  Future<void> _saveGovernor(String? governor) async {
    if (!await checkRootAccess()) return;
    if (mounted) setState(() => _isSaving = true);
    final valueString = governor ?? '';

    try {
      final sedCommand =
          "sed -i 's|^GOV=.*|GOV=$valueString|' $_configFilePath";
      final result = await runRootCommandAndWait(sedCommand);

      if (result.exitCode == 0) {
        if (mounted) setState(() => _selectedGovernor = governor);
      } else {
        throw Exception('Failed to write to config file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save governor: $e')));
        setState(() => _selectedGovernor = widget.initialSelectedGovernor);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              localization.custom_governor_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.custom_governor_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            if (_availableGovernors.isEmpty)
              Center(
                child: Text(
                  'No governors found or root access denied.',
                  style: TextStyle(color: colorScheme.error),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _availableGovernors.contains(_selectedGovernor)
                    ? _selectedGovernor
                    : null,
                hint: Text(localization.no_governor_selected),
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _isSaving ? null : _saveGovernor,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(localization.no_governor_selected),
                  ),
                  ..._availableGovernors.map<DropdownMenuItem<String>>(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
