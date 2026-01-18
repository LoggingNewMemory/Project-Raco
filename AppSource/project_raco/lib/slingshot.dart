import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/l10n/app_localizations.dart';

class AppItem {
  final String name;
  final String packageName;
  final Uint8List? icon;

  AppItem({required this.name, required this.packageName, this.icon});
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
  final Map<String, String> _modes = {
    'n': 'Normal (fadvise hint)',
    'd': 'Deep (fadvise + dlopen)',
    'x': 'Extreme (mmap + MAP_POPULATE)',
    'r': 'Recursive (looped deep check)',
  };

  bool _isAngleSupported = false;
  bool _useAngle = false;
  bool _useSkia = false;

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
    _cleanupAngleSettings();
    _checkAngleSupport();
    _initData();
  }

  Future<void> _cleanupAngleSettings() async {
    try {
      await Process.run('su', [
        '-c',
        'settings delete global angle_debug_package; '
            'settings delete global angle_gl_driver_all_angle; '
            'settings delete global angle_gl_driver_selection_pkgs; '
            'settings delete global angle_gl_driver_selection_values',
      ]);
    } catch (e) {
      debugPrint("Angle cleanup error: $e");
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
      // Read SKIAVK
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

      // Read ANGLE
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
    } catch (e) {
      debugPrint("Angle toggle error: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? savedPackage = prefs.getString(_prefsKeySelected);
      final String? savedMode = prefs.getString(_prefsKeyMode);

      if (mounted) {
        setState(() {
          if (savedPackage != null) _selectedAppPackage = savedPackage;
          if (savedMode != null && _modes.containsKey(savedMode)) {
            _selectedMode = savedMode;
          }
        });
      }

      final String? appsJson = prefs.getString(_prefsKeyApps);
      if (appsJson != null) {
        final List<dynamic> decodedList = jsonDecode(appsJson);
        final List<AppItem> cachedList = decodedList.map((item) {
          return AppItem(
            name: item['n'] as String,
            packageName: item['p'] as String,
            icon: null,
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
      if (mounted) {
        setState(() {
          _isLoadingApps = false;
        });
      }
      return;
    }

    bool rootFilterSuccess = false;
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
        rootFilterSuccess = true;
      }
    } catch (e) {
      rootFilterSuccess = false;
    }

    if (!rootFilterSuccess) {
      filteredResult = rawApps;
      filteredResult.sort((a, b) => (a.name).compareTo(b.name));
    }

    final List<AppItem> finalItems = filteredResult.map((info) {
      return AppItem(
        name: info.name,
        packageName: info.packageName,
        icon: info.icon,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _installedApps = finalItems;
        _isLoadingApps = false;
      });
      _saveToCache(finalItems);
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

    // Apply SkiaVK setting if enabled
    if (_useSkia) {
      await Process.run('su', ['-c', 'setprop debug.hwui.renderer skiavk']);
    }

    // Apply ANGLE settings if enabled and supported
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

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localization.slingshot_complete)));
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final filteredApps = _installedApps.where((app) {
      final nameMatch = app.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final pkgMatch = app.packageName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return nameMatch || pkgMatch;
    }).toList();

    final Widget pageContent = Scaffold(
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
                      color: Colors.black.withValues(alpha: 0.3),
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
                          items: _modes.entries.map((e) {
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

                    const SizedBox(height: 10),

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

                    const SizedBox(height: 10),

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
                                ? colorScheme.primary.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
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
                                child: app.icon != null && app.icon!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(app.icon!),
                                      )
                                    : const Icon(
                                        Icons.android,
                                        color: Colors.white54,
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colorScheme.surface),
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
        pageContent,
      ],
    );
  }
}
