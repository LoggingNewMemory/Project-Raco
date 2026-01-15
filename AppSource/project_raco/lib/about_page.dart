import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';
import '/l10n/app_localizations.dart';
import 'dart:io';
import 'dart:ui';

class AboutPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const AboutPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _deviceModel = '';
  String _cpuInfo = '';
  String _ramInfo = '';
  String _storageInfo = '';
  String _batteryInfo = '';
  bool _isLoading = true;
  bool _deviceInfoAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadDeviceInfo();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkRootAccessInAbout() async {
    try {
      var result = await run('su', ['-c', 'id'], verbose: false);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadDeviceInfo() async {
    final rootGranted = await _checkRootAccessInAbout();

    String deviceModel = '';
    String cpuInfo = '';
    String ramInfo = '';
    String storageInfo = '';
    String batteryInfo = '';
    bool isSuccess = false;

    if (rootGranted) {
      try {
        final results = await Future.wait([
          run('su', ['-c', 'getprop ro.product.model'], verbose: false),
          run('su', ['-c', 'getprop ro.board.platform'], verbose: false),
          run('su', ['-c', 'getprop ro.hardware'], verbose: false),
          run('su', [
            '-c',
            'cat /proc/cpuinfo | grep Hardware | cut -d: -f2',
          ], verbose: false),
          run('su', [
            '-c',
            'cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq | sort -nr | head -n 1',
          ], verbose: false),
          run('su', [
            '-c',
            r"cat /proc/meminfo | grep MemTotal | awk '{print $2}'",
          ], verbose: false),
          run('su', [
            '-c',
            r"df /data | tail -n 1 | awk '{print $2}'",
          ], verbose: false),
          run('su', [
            '-c',
            'cat /sys/class/power_supply/battery/charge_full_design',
          ], verbose: false),
        ]);

        deviceModel = results[0].stdout.toString().trim();

        String cpuName = results[1].stdout.toString().trim();
        if (cpuName.isEmpty || cpuName.toLowerCase() == 'unknown') {
          cpuName = results[2].stdout.toString().trim();
        }
        if (cpuName.isEmpty || cpuName.toLowerCase() == 'unknown') {
          cpuName = results[3].stdout.toString().trim();
        }

        String cpuFreq = results[4].stdout.toString().trim();
        if (cpuFreq.isNotEmpty && int.tryParse(cpuFreq) != null) {
          double freqGhz = int.parse(cpuFreq) / 1000000;
          cpuInfo = '${freqGhz.toStringAsFixed(2)}GHz $cpuName';
        } else {
          cpuInfo = cpuName;
        }

        String totalRamKb = results[5].stdout.toString().trim();
        if (totalRamKb.isNotEmpty && int.tryParse(totalRamKb) != null) {
          double totalRamGb = int.parse(totalRamKb) / (1024 * 1024);
          ramInfo = '${totalRamGb.ceil()} GB';
        }

        String totalStorageKb = results[6].stdout.toString().trim();
        if (totalStorageKb.isNotEmpty && int.tryParse(totalStorageKb) != null) {
          double totalStorageGb = int.parse(totalStorageKb) / (1024 * 1024);
          if (totalStorageGb > 500) {
            storageInfo = '1 TB';
          } else if (totalStorageGb > 240) {
            storageInfo = '512 GB';
          } else if (totalStorageGb > 200) {
            storageInfo = '256 GB';
          } else if (totalStorageGb > 100) {
            storageInfo = '128 GB';
          } else if (totalStorageGb > 50) {
            storageInfo = '64 GB';
          } else {
            storageInfo = '${totalStorageGb.round()} GB';
          }
        }

        String batteryUah = results[7].stdout.toString().trim();
        if (batteryUah.isNotEmpty && int.tryParse(batteryUah) != null) {
          int mah = (int.parse(batteryUah) / 1000).round();
          if (mah < 1000) {
            mah *= 10;
          }
          batteryInfo = '${mah}mAh';
        }

        if (deviceModel.isNotEmpty && cpuInfo.isNotEmpty) {
          isSuccess = true;
        }
      } catch (e) {
        isSuccess = false;
      }
    }

    if (mounted) {
      setState(() {
        _deviceInfoAvailable = isSuccess;
        if (isSuccess) {
          _deviceModel = deviceModel;
          _cpuInfo = cpuInfo;
          _ramInfo = ramInfo;
          _storageInfo = storageInfo;
          _batteryInfo = batteryInfo;
        }
      });
    }
  }

  List<String> _getCredits(AppLocalizations localization) {
    return [
      "Rem01 Gaming",
      "MiAzami",
      "Kazuyoo",
      "RiProG",
      "HoyoSlave",
      "Koneko_dev",
      "Not_ValentineSTCV",
      "Andreyka4_45",
      "Zexshia",
      "Java_nih_deks",
      "KanaDev_IS",
      localization.credits_11,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final credits = _getCredits(localization);
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final separator = Text(
      '|',
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 18,
        fontWeight: FontWeight.w200,
      ),
    );

    final Widget pageContent = Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: AnimatedOpacity(
            opacity: _isLoading ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_deviceInfoAvailable)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(_deviceModel, style: valueStyle),
                              const SizedBox(width: 8),
                              Text(localization.device_name, style: labelStyle),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(_cpuInfo, style: valueStyle),
                              const SizedBox(width: 8),
                              Text(localization.processor, style: labelStyle),
                              const SizedBox(width: 8),
                              separator,
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(_ramInfo, style: valueStyle),
                              const SizedBox(width: 8),
                              Text(localization.ram, style: labelStyle),
                              const SizedBox(width: 8),
                              separator,
                              const SizedBox(width: 16),
                              Text(_storageInfo, style: valueStyle),
                              const SizedBox(width: 8),
                              Text(
                                localization.phone_storage,
                                style: labelStyle,
                              ),
                              const SizedBox(width: 8),
                              separator,
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(_batteryInfo, style: valueStyle),
                              const SizedBox(width: 8),
                              Text(
                                localization.battery_capacity,
                                style: labelStyle,
                              ),
                              const SizedBox(width: 8),
                              separator,
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  Text(
                    localization.about_title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...credits.map(
                    (creditText) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '• $creditText',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    localization.about_note,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      localization.about_quote,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
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
