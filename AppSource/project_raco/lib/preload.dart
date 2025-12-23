import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/l10n/app_localizations.dart';

// 1. Custom Class to handle data safely (Fixes AppInfo constructor error)
class AppItem {
  final String name;
  final String packageName;
  final Uint8List? icon;

  AppItem({required this.name, required this.packageName, this.icon});
}

class PreloadPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const PreloadPage({
    super.key, // Fixed: Use super parameter
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  });

  @override
  State<PreloadPage> createState() => _PreloadPageState(); // Fixed: Public state type
}

class _PreloadPageState extends State<PreloadPage> {
  // RAM Stats
  String _freeRam = "...";
  String _usedRam = "...";
  String _totalRam = "...";
  double _ramProgress = 0.0;
  Timer? _ramTimer;

  // Kasane Settings
  String _selectedMode = 'n';
  final Map<String, String> _modes = {
    'n': 'Normal (fadvise hint)',
    'd': 'Deep (fadvise + dlopen)',
    'x': 'Extreme (mmap + MAP_POPULATE)',
    'r': 'Recursive (looped deep check)',
  };

  // App List Cache & State
  List<AppItem> _installedApps = [];
  Map<String, bool> _selectedApps = {};
  bool _isLoadingApps = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Persistence keys
  static const String _prefsKeyApps = 'preload_cached_apps';
  static const String _prefsKeySelected = 'preload_selected_apps';

  @override
  void initState() {
    super.initState();
    _fetchRamInfo();
    _initData();

    // Refresh RAM every 3 seconds
    _ramTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchRamInfo();
    });
  }

  Future<void> _initData() async {
    await _loadFromCache();
    // Fetch fresh data in background
    _fetchInstalledApps(forceRefresh: true);
  }

  @override
  void dispose() {
    _ramTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- Persistence Logic ---

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Selected Apps
      final String? selectedJson = prefs.getString(_prefsKeySelected);
      if (selectedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(selectedJson);
        setState(() {
          _selectedApps = decoded.map((k, v) => MapEntry(k, v as bool));
        });
      }

      // Load App List
      final String? appsJson = prefs.getString(_prefsKeyApps);
      if (appsJson != null) {
        final List<dynamic> decodedList = jsonDecode(appsJson);

        // Map to our custom AppItem class
        final List<AppItem> cachedList = decodedList.map((item) {
          return AppItem(
            name: item['n'] as String,
            packageName: item['p'] as String,
            icon: null, // Icons are not cached to save space
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

      // Save minimal data (Name & Package only)
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
      await prefs.setString(_prefsKeySelected, jsonEncode(_selectedApps));
    } catch (e) {
      debugPrint("Selection save error: $e");
    }
  }

  // --- Core Logic ---

  Future<void> _fetchRamInfo() async {
    try {
      final result = await Process.run('cat', ['/proc/meminfo']);
      if (result.exitCode == 0) {
        final content = result.stdout.toString();

        int parseMem(String key) {
          final regex = RegExp('$key:\\s+(\\d+)\\s+kB');
          final match = regex.firstMatch(content);
          return match != null ? int.parse(match.group(1)!) : 0;
        }

        final total = parseMem('MemTotal');
        final available = parseMem('MemAvailable');
        // Fixed: Removed unused 'free' variable
        final used = total - available;

        if (mounted) {
          setState(() {
            _totalRam = "${(total / 1024).toStringAsFixed(0)} MB";
            _freeRam = "${(available / 1024).toStringAsFixed(0)} MB";
            _usedRam = "${(used / 1024).toStringAsFixed(0)} MB";
            _ramProgress = total > 0 ? used / total : 0.0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _freeRam = "Unknown";
          _totalRam = "Unknown";
          _usedRam = "Unknown";
          _ramProgress = 0.0;
        });
      }
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
      // Get real apps from plugin
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

    // Filter using Root (su)
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

        // Fixed: Removed dead null check (?? "")
        filteredResult.sort((a, b) => (a.name).compareTo(b.name));
        rootFilterSuccess = true;
      }
    } catch (e) {
      rootFilterSuccess = false;
    }

    if (!rootFilterSuccess) {
      filteredResult = rawApps;
      // Fixed: Removed dead null check
      filteredResult.sort((a, b) => (a.name).compareTo(b.name));
    }

    // Convert AppInfo to our custom AppItem
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

  Future<void> _runKasane() async {
    final selectedPackages = _selectedApps.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedPackages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No apps selected")));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Preloading ${selectedPackages.length} apps...")),
    );

    for (final pkg in selectedPackages) {
      await Process.run('su', ['-c', 'kasane -a $pkg -m $_selectedMode -l']);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Preload Complete")));
    _fetchRamInfo();
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
        title: Text(localization.kasane_title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runKasane,
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.rocket_launch),
        label: Text(localization.start_preload),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Info Card
            Card(
              elevation: 0,
              color: Colors.black.withValues(
                alpha: 0.3,
              ), // Fixed deprecated .withOpacity
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Free RAM:",
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          _freeRam,
                          style: const TextStyle(
                            color: Color(0xFFE5AA70),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _ramProgress,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        "$_usedRam / $_totalRam",
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Preload Mode Selector
            Text(
              "Preload Mode",
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
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
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMode = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Search Bar & Refresh Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search apps...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      suffixIcon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
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
                    tooltip: "Reload App List",
                    onPressed: () {
                      _fetchInstalledApps(forceRefresh: true);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 4. App List
            Expanded(
              child: _isLoadingApps && _installedApps.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredApps.isEmpty
                  ? const Center(
                      child: Text(
                        "No apps found",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _fetchInstalledApps(forceRefresh: true);
                      },
                      child: ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final pkg = app.packageName;
                          final isSelected = _selectedApps[pkg] ?? false;

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: SizedBox(
                              width: 40,
                              height: 40,
                              child: app.icon != null && app.icon!.isNotEmpty
                                  ? Image.memory(app.icon!)
                                  : const Icon(
                                      Icons.android,
                                      color: Colors.white54,
                                    ),
                            ),
                            title: Text(
                              app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              pkg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            value: isSelected,
                            activeColor: colorScheme.primary,
                            checkColor: colorScheme.onPrimary,
                            side: const BorderSide(color: Colors.white54),
                            onChanged: (val) {
                              setState(() {
                                _selectedApps[pkg] = val ?? false;
                              });
                              _saveSelection();
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colorScheme.surface), // Fixed deprecated background
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
