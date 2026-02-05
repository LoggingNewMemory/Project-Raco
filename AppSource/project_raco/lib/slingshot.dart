import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '/l10n/app_localizations.dart';
import 'topo_background.dart';

class AppItem {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;
  final String? iconPath;

  AppItem({
    required this.name,
    required this.packageName,
    this.iconBytes,
    this.iconPath,
  });
}

class SlingshotPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const SlingshotPage({
    super.key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  });

  @override
  State<SlingshotPage> createState() => _SlingshotPageState();
}

class _SlingshotPageState extends State<SlingshotPage> {
  String _selectedMode = 'n';
  bool _isAngleSupported = false;
  bool _useAngle = false;
  bool _useSkia = false;
  bool _enablePlayboost = false;
  bool _endfieldCollabEnabled = false;

  List<AppItem> _installedApps = [];
  String? _selectedAppPackage;
  bool _isLoadingApps = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  static const String _racoConfigPath = '/data/ProjectRaco/raco.txt';
  static const String _prefsKeyApps = 'preload_cached_apps';
  static const String _prefsKeySelected = 'preload_selected_single_app';
  static const String _prefsKeyMode = 'preload_selected_mode';

  @override
  void initState() {
    super.initState();
    _cleanupAll();
    _checkAngleSupport();
    _initData();
  }

  Future<void> _cleanupAll() async {
    try {
      await Process.run('su', [
        '-c',
        'settings delete global angle_debug_package; '
            'settings delete global angle_gl_driver_all_angle; '
            'settings delete global angle_gl_driver_selection_pkgs; '
            'settings delete global angle_gl_driver_selection_values; '
            'setprop debug.hwui.renderer none',
      ]);
    } catch (e) {
      debugPrint("Cleanup error: $e");
    }
  }

  Future<void> _checkAngleSupport() async {
    try {
      final result = await Process.run('getprop', ['ro.gfx.angle.supported']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (mounted) {
          setState(() {
            _isAngleSupported = output == 'true';
          });
        }
      }
    } catch (e) {
      debugPrint("Angle check error: $e");
    }
  }

  Future<void> _initData() async {
    await _loadFromCache();
    await _loadRacoConfig();
    _fetchInstalledApps(forceRefresh: true);
  }

  Future<void> _loadRacoConfig() async {
    try {
      // Load Skia State
      final skiaResult = await Process.run('su', [
        '-c',
        'grep "^SKIAVK=" $_racoConfigPath | cut -d= -f2',
      ]);
      if (skiaResult.exitCode == 0) {
        final val = skiaResult.stdout.toString().trim();
        if (mounted) {
          setState(() {
            _useSkia = val == '1';
          });
        }
      }

      // Load Angle State
      final angleResult = await Process.run('su', [
        '-c',
        'grep "^ANGLE=" $_racoConfigPath | cut -d= -f2',
      ]);
      if (angleResult.exitCode == 0) {
        final val = angleResult.stdout.toString().trim();
        if (mounted) {
          setState(() {
            _useAngle = val == '1';
          });
        }
      }

      // Load Playboost State
      final playboostResult = await Process.run('su', [
        '-c',
        'grep "^PLAYBOOST=" $_racoConfigPath | cut -d= -f2',
      ]);
      if (playboostResult.exitCode == 0) {
        final val = playboostResult.stdout.toString().trim();
        if (mounted) {
          setState(() {
            _enablePlayboost = val == '1';
          });
        }
      }
    } catch (e) {
      debugPrint("Raco config load error: $e");
    }
  }

  Future<void> _toggleSkia(bool value) async {
    setState(() => _useSkia = value);
    try {
      final int intVal = value ? 1 : 0;
      await Process.run('su', [
        '-c',
        'sed -i "s/^SKIAVK=.*/SKIAVK=$intVal/" $_racoConfigPath',
      ]);

      if (!value) {
        await Process.run('su', ['-c', 'setprop debug.hwui.renderer none']);
      }
    } catch (e) {
      debugPrint("Skia toggle error: $e");
    }
  }

  Future<void> _toggleAngle(bool value) async {
    setState(() => _useAngle = value);
    try {
      final int intVal = value ? 1 : 0;
      await Process.run('su', [
        '-c',
        'sed -i "s/^ANGLE=.*/ANGLE=$intVal/" $_racoConfigPath',
      ]);

      if (!value) {
        await Process.run('su', [
          '-c',
          'settings delete global angle_debug_package; '
              'settings delete global angle_gl_driver_all_angle; '
              'settings delete global angle_gl_driver_selection_pkgs; '
              'settings delete global angle_gl_driver_selection_values',
        ]);
      }
    } catch (e) {
      debugPrint("Angle toggle error: $e");
    }
  }

  Future<void> _togglePlayboost(bool value) async {
    setState(() => _enablePlayboost = value);
    try {
      final int intVal = value ? 1 : 0;
      // Update PLAYBOOST in raco.txt directly
      await Process.run('su', [
        '-c',
        'sed -i "s/^PLAYBOOST=.*/PLAYBOOST=$intVal/" $_racoConfigPath',
      ]);
    } catch (e) {
      debugPrint("Playboost toggle error: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Directory> _getIconCacheDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final iconDir = Directory('${docsDir.path}/app_icons');
    if (!await iconDir.exists()) {
      await iconDir.create(recursive: true);
    }
    return iconDir;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? savedPackage = prefs.getString(_prefsKeySelected);
      final String? savedMode = prefs.getString(_prefsKeyMode);
      final bool endfieldEnabled =
          prefs.getBool('endfield_collab_enabled') ?? false;

      if (mounted) {
        setState(() {
          if (savedPackage != null) _selectedAppPackage = savedPackage;
          if (savedMode != null) _selectedMode = savedMode;
          _endfieldCollabEnabled = endfieldEnabled;
        });
      }

      final String? appsJson = prefs.getString(_prefsKeyApps);
      if (appsJson != null) {
        final List<dynamic> decodedList = jsonDecode(appsJson);
        final iconDir = await _getIconCacheDir();

        final List<AppItem> cachedList = decodedList.map((item) {
          final pkg = item['p'] as String;
          final path = '${iconDir.path}/$pkg.png';
          final fileExists = File(path).existsSync();

          return AppItem(
            name: item['n'] as String,
            packageName: pkg,
            iconBytes: null,
            iconPath: fileExists ? path : null,
          );
        }).toList();

        if (mounted && cachedList.isNotEmpty) {
          setState(() {
            _installedApps = cachedList;
            _isLoadingApps = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  Future<void> _saveToCache(List<AppItem> apps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, String>> tinyList = apps
          .map((app) => {'n': app.name, 'p': app.packageName})
          .toList();

      await prefs.setString(_prefsKeyApps, jsonEncode(tinyList));
    } catch (e) {
      debugPrint("Cache save error: $e");
    }
  }

  Future<void> _saveSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedAppPackage != null) {
        await prefs.setString(_prefsKeySelected, _selectedAppPackage!);
      } else {
        await prefs.remove(_prefsKeySelected);
      }
      await prefs.setString(_prefsKeyMode, _selectedMode);
    } catch (e) {
      debugPrint("Selection save error: $e");
    }
  }

  Future<void> _fetchInstalledApps({bool forceRefresh = false}) async {
    if (_installedApps.isEmpty && mounted) {
      setState(() {
        _isLoadingApps = true;
      });
    }

    List<AppInfo> rawApps = [];
    try {
      rawApps = await InstalledApps.getInstalledApps(true, true);
    } catch (e) {
      if (mounted && _installedApps.isEmpty) {
        setState(() {
          _isLoadingApps = false;
        });
      }
      return;
    }

    List<AppInfo> filteredResult = [];
    try {
      final result = await Process.run('su', ['-c', 'pm list packages -3']);

      if (result.exitCode == 0) {
        final List<String> rootPackageNames = result.stdout
            .toString()
            .split('\n')
            .where((line) => line.startsWith('package:'))
            .map((line) => line.replaceAll('package:', '').trim())
            .toList();

        final Set<String> rootPkgSet = rootPackageNames.toSet();

        filteredResult = rawApps
            .where((app) => rootPkgSet.contains(app.packageName))
            .toList();

        filteredResult.sort((a, b) => (a.name).compareTo(b.name));
      }
    } catch (e) {
      debugPrint("Root filter error: $e");
    }

    if (filteredResult.isEmpty) {
      if (mounted) {
        setState(() => _isLoadingApps = false);
      }
      return;
    }

    final iconDir = await _getIconCacheDir();
    final List<AppItem> finalItems = [];

    for (var info in filteredResult) {
      String? iconPath;
      if (info.icon != null) {
        final file = File('${iconDir.path}/${info.packageName}.png');
        try {
          if (!await file.exists() || forceRefresh) {
            await file.writeAsBytes(info.icon!, flush: true);
          }
          iconPath = file.path;
        } catch (e) {
          debugPrint("Failed to cache icon for ${info.packageName}: $e");
        }
      }

      finalItems.add(
        AppItem(
          name: info.name,
          packageName: info.packageName,
          iconBytes: info.icon,
          iconPath: iconPath,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _installedApps = finalItems;
        _isLoadingApps = false;
      });
      _saveToCache(finalItems);
    }
  }

  Future<void> _applyPlayBoost(String packageName) async {
    try {
      await Future.delayed(const Duration(seconds: 3));

      const String script =
          'pid=\$(pgrep -f %PKG% | head -n 1); '
          'if [ -n "\$pid" ]; then '
          '  for task in /proc/\$pid/task/*; do '
          '    tid=\$(basename \$task); '
          '    taskset -p ffffffff \$tid; '
          '  done; '
          'fi';

      final cmd = script.replaceAll('%PKG%', packageName);

      await Process.run('su', ['-c', cmd]);
    } catch (e) {
      debugPrint("PlayBoost error: $e");
    }
  }

  Future<void> _runSlingshot() async {
    if (!mounted) return;
    final localization = AppLocalizations.of(context)!;

    if (_selectedAppPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.slingshot_no_app_selected)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localization.slingshot_executing(_selectedAppPackage!)),
      ),
    );

    if (_useSkia) {
      await Process.run('su', ['-c', 'setprop debug.hwui.renderer skiavk']);
    }

    if (_useAngle && _isAngleSupported) {
      await Process.run('su', [
        '-c',
        'settings put global angle_gl_driver_selection_pkgs $_selectedAppPackage && settings put global angle_gl_driver_selection_values angle',
      ]);
    }

    await Process.run('su', [
      '-c',
      '/data/adb/modules/ProjectRaco/Binaries/kasane -a $_selectedAppPackage -m $_selectedMode -l',
    ]);

    if (_enablePlayboost) {
      _applyPlayBoost(_selectedAppPackage!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localization.slingshot_complete)));
  }

  // ===========================================
  //        LAYOUT BUILDERS
  // ===========================================

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // Map modes map used by both layouts
    final Map<String, String> modes = {
      'n': localization.slingshot_mode_normal,
      'd': localization.slingshot_mode_deep,
      'x': localization.slingshot_mode_extreme,
      'r': localization.slingshot_mode_recursive,
    };
    if (!modes.containsKey(_selectedMode)) _selectedMode = 'n';

    final filteredApps = _installedApps.where((app) {
      final nameMatch = app.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final pkgMatch = app.packageName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return nameMatch || pkgMatch;
    }).toList();

    // Decide which content to build
    Widget bodyContent;
    if (_endfieldCollabEnabled) {
      bodyContent = _buildEndfieldLayout(
        context,
        filteredApps,
        modes,
        localization,
      );
    } else {
      bodyContent = _buildStandardLayout(
        context,
        filteredApps,
        modes,
        localization,
        colorScheme,
      );
    }

    // Wrap in stack for background
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colorScheme.surface),
        if (_endfieldCollabEnabled)
          Positioned.fill(
            child: TopoBackground(
              color: const Color(0xFF00BFFF).withOpacity(0.1), // Tech blue
              speed: 0.2, // Slightly faster
            ),
          )
        else if (widget.backgroundImagePath != null &&
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
        bodyContent,
      ],
    );
  }

  // --- STANDARD LAYOUT ---
  Widget _buildStandardLayout(
    BuildContext context,
    List<AppItem> filteredApps,
    Map<String, String> modes,
    AppLocalizations localization,
    ColorScheme colorScheme,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.slingshot_title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runSlingshot,
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.rocket_launch),
        label: Text(localization.start_preload),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchInstalledApps(forceRefresh: true);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      color: Colors.black.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          localization.slingshot_description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      localization.preload_mode,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMode,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1E1E),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: modes.entries.map((e) {
                            return DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMode = val);
                              _saveSelection();
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        localization.angle_title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: _isAngleSupported
                          ? null
                          : Text(
                              localization.angle_not_supported,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                      value: _useAngle,
                      onChanged: _isAngleSupported
                          ? (val) {
                              _toggleAngle(val);
                            }
                          : null,
                      activeColor: colorScheme.primary,
                    ),

                    const SizedBox(height: 5),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        localization.skia_title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: _useSkia,
                      onChanged: (val) {
                        _toggleSkia(val);
                      },
                      activeColor: colorScheme.primary,
                    ),

                    const SizedBox(height: 5),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        localization.playboost_title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: _enablePlayboost,
                      onChanged: (val) {
                        _togglePlayboost(val);
                      },
                      activeColor: colorScheme.primary,
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localization.slingshot_graphics_warning,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: localization.slingshot_search_hint,
                              hintStyle: const TextStyle(color: Colors.white54),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white54,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh),
                            color: Colors.white70,
                            tooltip: localization.slingshot_reload_tooltip,
                            onPressed: () {
                              _fetchInstalledApps(forceRefresh: true);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              if (_isLoadingApps && _installedApps.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredApps.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      localization.slingshot_no_apps_found,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final app = filteredApps[index];
                    final pkg = app.packageName;
                    final isSelected = _selectedAppPackage == pkg;

                    return Padding(
                      key: ValueKey(pkg),
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAppPackage = pkg;
                          });
                          _saveSelection();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildAppIcon(app),
                                ),
                              ),
                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      pkg,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white70
                                            : Colors.white38,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: filteredApps.length),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // --- ENDFIELD LAYOUT ---
  Widget _buildEndfieldLayout(
    BuildContext context,
    List<AppItem> filteredApps,
    Map<String, String> modes,
    AppLocalizations localization,
  ) {
    final Color bgDark = const Color(0xFF0D0D0D);
    final Color techYellow = const Color(0xFFFFD700);
    final Color techBlue = const Color(0xFF00BFFF);

    final monoStyle = const TextStyle(
      fontFamily: 'RobotoMono',
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      appBar: AppBar(
        leading: BackButton(color: techBlue),
        title: Text(
          "PAYLOAD // SELECTOR",
          style: monoStyle.copyWith(color: techYellow, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white54),
            onPressed: () => _fetchInstalledApps(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: InkWell(
        onTap: _runSlingshot,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: techYellow,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: techYellow.withOpacity(0.4), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rocket_launch, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text(
                "INITIATE SEQUENCE",
                style: monoStyle.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // -- TOP CONTROL PANEL --
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: techBlue.withOpacity(0.5)),
              color: techBlue.withOpacity(0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "// SYSTEM OVERRIDES",
                  style: monoStyle.copyWith(color: techBlue, fontSize: 10),
                ),
                SizedBox(height: 8),

                // -- 3 ROWS, 1 COLUMN LAYOUT FOR SWITCHES --
                Column(
                  children: [
                    _buildEndfieldSwitch(
                      localization.angle_title,
                      _useAngle,
                      _toggleAngle,
                      active: _isAngleSupported,
                    ),
                    SizedBox(height: 8),
                    _buildEndfieldSwitch(
                      localization.skia_title,
                      _useSkia,
                      _toggleSkia,
                    ),
                    SizedBox(height: 8),
                    _buildEndfieldSwitch(
                      "P-BOOST",
                      _enablePlayboost,
                      _togglePlayboost,
                    ),
                  ],
                ),

                SizedBox(height: 12),
                Text(
                  "// EXECUTION MODE",
                  style: monoStyle.copyWith(color: techBlue, fontSize: 10),
                ),
                SizedBox(height: 4),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    color: Colors.black,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<String>(
                        value: _selectedMode,
                        isExpanded: true,
                        dropdownColor: bgDark,
                        icon: Icon(Icons.arrow_drop_down, color: techYellow),
                        style: monoStyle.copyWith(color: Colors.white),
                        items: modes.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMode = val);
                            _saveSelection();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          // -- SEARCH BAR --
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              style: monoStyle.copyWith(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black54,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: techYellow),
                ),
                prefixIcon: Icon(Icons.search, color: techYellow),
                hintText: "SEARCH_TARGET_PACKAGE...",
                hintStyle: monoStyle.copyWith(
                  color: Colors.white24,
                  fontSize: 12,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          SizedBox(height: 10),

          // -- LIST HEADER --
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.white10,
            child: Text(
              "AVAILABLE TARGETS: ${filteredApps.length}",
              style: monoStyle.copyWith(color: Colors.white54, fontSize: 10),
            ),
          ),

          // -- VERTICAL LIST (1xN LAYOUT) --
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 80, left: 16, right: 16, top: 4),
              itemCount: filteredApps.length,
              itemBuilder: (context, index) {
                final app = filteredApps[index];
                final isSelected = _selectedAppPackage == app.packageName;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAppPackage = app.packageName);
                    _saveSelection();
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? techYellow : Colors.white12,
                      ),
                      color: isSelected
                          ? techYellow.withOpacity(0.1)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // Icon Box
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                          ),
                          padding: EdgeInsets.all(2),
                          child: _buildAppIcon(app),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name.toUpperCase(),
                                style: monoStyle.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                app.packageName,
                                style: monoStyle.copyWith(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            color: techYellow,
                            child: Text(
                              "LOCKED",
                              style: monoStyle.copyWith(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndfieldSwitch(
    String label,
    bool value,
    Function(bool) onChanged, {
    bool active = true,
  }) {
    final Color techYellow = const Color(0xFFFFD700);
    final monoStyle = const TextStyle(
      fontFamily: 'RobotoMono',
      fontWeight: FontWeight.bold,
    );

    return InkWell(
      onTap: active ? () => onChanged(!value) : null,
      child: Container(
        height: 40,
        width: double.infinity, // Full width for vertical stack
        decoration: BoxDecoration(
          color: value ? techYellow : Colors.transparent,
          border: Border.all(
            color: active
                ? (value ? techYellow : Colors.white24)
                : Colors.white10,
          ),
        ),
        alignment: Alignment.centerLeft, // Left aligned for list feel
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: monoStyle.copyWith(
                color: value
                    ? Colors.black
                    : (active ? Colors.white54 : Colors.white10),
                fontSize: 10,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              color: value
                  ? Colors.black
                  : (active ? Colors.white54 : Colors.white10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(AppItem app) {
    if (app.iconBytes != null) {
      return Image.memory(
        app.iconBytes!,
        gaplessPlayback: true,
        fit: BoxFit.cover,
      );
    }

    if (app.iconPath != null) {
      return Image.file(
        File(app.iconPath!),
        gaplessPlayback: true,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.android, color: Colors.white54),
      );
    }

    return const Icon(Icons.android, color: Colors.white54);
  }
}
