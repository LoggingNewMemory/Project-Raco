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
  // Hardcoded _modes map removed from here

  String _selectedMode = 'n';
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
  static const String _prefsKeyIcons = 'preload_cached_icons';
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
          if (savedMode != null) {
            _selectedMode = savedMode;
          }
        });
      }

      final String? appsJson = prefs.getString(_prefsKeyApps);
      final String? iconsJson = prefs.getString(_prefsKeyIcons);

      if (appsJson != null) {
        final List<dynamic> decodedList = jsonDecode(appsJson);

        // Load cached icons
        Map<String, String> iconCache = {};
        if (iconsJson != null) {
          try {
            iconCache = Map<String, String>.from(jsonDecode(iconsJson));
          } catch (e) {
            debugPrint("Icon cache decode error: $e");
          }
        }

        final List<AppItem> cachedList = decodedList.map((item) {
          final packageName = item['p'] as String;
          Uint8List? iconData;

          // Load icon from cache if available
          if (iconCache.containsKey(packageName)) {
            try {
              iconData = base64Decode(iconCache[packageName]!);
            } catch (e) {
              debugPrint("Icon decode error for $packageName: $e");
            }
          }

          return AppItem(
            name: item['n'] as String,
            packageName: packageName,
            icon: iconData,
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

      // Save app metadata
      final List<Map<String, String>> tinyList = apps
          .map((app) => {'n': app.name, 'p': app.packageName})
          .toList();

      await prefs.setString(_prefsKeyApps, jsonEncode(tinyList));

      // Save app icons as base64
      final Map<String, String> iconCache = {};
      for (final app in apps) {
        if (app.icon != null && app.icon!.isNotEmpty) {
          try {
            iconCache[app.packageName] = base64Encode(app.icon!);
          } catch (e) {
            debugPrint("Icon encode error for ${app.packageName}: $e");
          }
        }
      }

      if (iconCache.isNotEmpty) {
        await prefs.setString(_prefsKeyIcons, jsonEncode(iconCache));
      }
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
    if (!forceRefresh && _installedApps.isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingApps = true;
      });
    }

    try {
      List<AppInfo> allApps = await InstalledApps.getInstalledApps(true, true);
      allApps.sort((a, b) => a.name.compareTo(b.name));

      // Create initial list without icons for instant display
      final List<AppItem> appsWithoutIcons = allApps.map((appInfo) {
        // Check if we have cached icon
        final cachedApp = _installedApps.firstWhere(
          (cached) => cached.packageName == appInfo.packageName,
          orElse: () => AppItem(name: '', packageName: '', icon: null),
        );

        return AppItem(
          name: appInfo.name,
          packageName: appInfo.packageName,
          icon: cachedApp.icon, // Use cached icon if available
        );
      }).toList();

      if (mounted) {
        setState(() {
          _installedApps = appsWithoutIcons;
          _isLoadingApps = false;
        });
      }

      // Load icons asynchronously in batches
      await _loadIconsInBackground(allApps);
    } catch (e) {
      debugPrint("Fetch apps error: $e");
      if (mounted) {
        setState(() {
          _isLoadingApps = false;
        });
      }
    }
  }

  Future<void> _loadIconsInBackground(List<AppInfo> allApps) async {
    const int batchSize = 10;

    for (int i = 0; i < allApps.length; i += batchSize) {
      final int end = (i + batchSize < allApps.length)
          ? i + batchSize
          : allApps.length;
      final batch = allApps.sublist(i, end);

      // Load icons for this batch
      for (final appInfo in batch) {
        if (!mounted) break;

        // Skip if we already have the icon
        final existingApp = _installedApps.firstWhere(
          (app) => app.packageName == appInfo.packageName,
          orElse: () => AppItem(name: '', packageName: '', icon: null),
        );

        if (existingApp.icon != null && existingApp.icon!.isNotEmpty) {
          continue;
        }

        try {
          Uint8List? iconData = appInfo.icon;

          if (mounted && iconData != null && iconData.isNotEmpty) {
            setState(() {
              final index = _installedApps.indexWhere(
                (app) => app.packageName == appInfo.packageName,
              );

              if (index != -1) {
                _installedApps[index] = AppItem(
                  name: appInfo.name,
                  packageName: appInfo.packageName,
                  icon: iconData,
                );
              }
            });
          }
        } catch (e) {
          debugPrint("Icon load error for ${appInfo.packageName}: $e");
        }
      }

      // Small delay between batches to avoid overwhelming the UI
      if (i + batchSize < allApps.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // Save everything to cache after all icons are loaded
    if (mounted) {
      await _saveToCache(_installedApps);
    }
  }

  Future<void> _launchSelectedApp() async {
    if (_selectedAppPackage == null) {
      _showSnackBar(AppLocalizations.of(context)!.slingshot_no_app_selected);
      return;
    }

    try {
      await _writeToRaco(_selectedAppPackage!, _selectedMode);
      _showSnackBar(
        AppLocalizations.of(context)!.slingshot_executing(_selectedAppPackage!),
      );

      final resultShow = await Process.run('su', [
        '-c',
        'am start --user 0 -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n $_selectedAppPackage',
      ]);

      if (resultShow.exitCode == 0) {
        _showSnackBar(AppLocalizations.of(context)!.slingshot_complete);
      } else {
        _showSnackBar(AppLocalizations.of(context)!.command_failed);
      }
    } catch (e) {
      debugPrint("Launch error: $e");
      _showSnackBar(AppLocalizations.of(context)!.command_failed);
    }
  }

  Future<void> _writeToRaco(String packageName, String modeVal) async {
    try {
      final String line = "$packageName:$modeVal";
      await Process.run('su', ['-c', 'echo "$line" > $_racoConfigPath']);
    } catch (e) {
      debugPrint("Raco write error: $e");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localization = AppLocalizations.of(context)!;

    final Map<String, String> _modes = {
      'n': localization.slingshot_mode_normal,
      'l': localization.slingshot_mode_deep,
      'm': localization.slingshot_mode_extreme,
      'h': localization.slingshot_mode_recursive,
    };

    final List<AppItem> filteredApps = _installedApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _launchSelectedApp,
        label: Text(localization.start_preload),
        icon: const Icon(Icons.rocket_launch),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localization.slingshot_title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localization.slingshot_description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      localization.preload_mode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMode,
                          dropdownColor: colorScheme.surface,
                          isExpanded: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          items: _modes.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMode = val;
                              });
                              _saveSelection();
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

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
                                color: Colors.redAccent,
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
                                        child: Image.memory(
                                          app.icon!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const Icon(
                                                  Icons.android,
                                                  color: Colors.white54,
                                                );
                                              },
                                        ),
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
