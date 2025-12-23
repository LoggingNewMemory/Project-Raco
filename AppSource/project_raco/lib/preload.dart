import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '/l10n/app_localizations.dart';

class PreloadPage extends StatefulWidget {
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const PreloadPage({
    Key? key,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _PreloadPageState createState() => _PreloadPageState();
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

  // App List
  // CHANGED: Now stores ApplicationWithIcon objects instead of plain Strings
  List<ApplicationWithIcon> _installedApps = [];
  Map<String, bool> _selectedApps = {};
  bool _isLoadingApps = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRamInfo();
    _fetchInstalledApps();
    // Refresh RAM every 3 seconds
    _ramTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchRamInfo();
    });
  }

  @override
  void dispose() {
    _ramTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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
        final free = parseMem('MemFree');
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
      // Fallback for non-root/simulator environments
      if (mounted) {
        setState(() {
          _freeRam = "2048 MB"; // Mock for display if fetch fails
          _totalRam = "8192 MB";
          _usedRam = "6144 MB";
          _ramProgress = 0.75;
        });
      }
    }
  }

  Future<void> _fetchInstalledApps() async {
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );

      // Filter and cast to ApplicationWithIcon
      final List<ApplicationWithIcon> appsWithIcons = apps
          .whereType<ApplicationWithIcon>()
          .toList();

      // Sort by App Name instead of Package Name
      appsWithIcons.sort(
        (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
      );

      if (mounted) {
        setState(() {
          _installedApps = appsWithIcons;
          _isLoadingApps = false;
        });
      }
    } catch (e) {
      // Fallback if plugin fails (rare on Android)
      if (mounted) {
        setState(() {
          _isLoadingApps = false;
        });
      }
    }
  }

  Future<void> _runKasane() async {
    final selectedPackages = _selectedApps.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedPackages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No apps selected")));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Preloading ${selectedPackages.length} apps...")),
    );

    for (final pkg in selectedPackages) {
      await Process.run('su', ['-c', 'kasane -a $pkg -m $_selectedMode -l']);
    }

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

    // Filter apps by Name OR Package Name
    final filteredApps = _installedApps.where((app) {
      final query = _searchQuery.toLowerCase();
      return app.appName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();

    // The main content of the page
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
            // 1. Info Card (RAM Stats Only)
            Card(
              elevation: 0,
              color: Colors.black.withOpacity(0.3),
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

            // 3. Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search apps...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),

            const SizedBox(height: 16),

            // 4. App List
            Expanded(
              child: _isLoadingApps
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        final isSelected =
                            _selectedApps[app.packageName] ?? false;

                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          // CHANGED: Display Icon using Image.memory
                          secondary: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Image.memory(
                              app.icon,
                              width: 40,
                              height: 40,
                            ),
                          ),
                          // CHANGED: Display App Name as Title
                          title: Text(
                            app.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          // CHANGED: Display Package Name as Subtitle
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 12,
                            ),
                          ),
                          value: isSelected,
                          activeColor: colorScheme.primary,
                          checkColor: colorScheme.onPrimary,
                          side: const BorderSide(color: Colors.white54),
                          onChanged: (val) {
                            setState(() {
                              _selectedApps[app.packageName] = val ?? false;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colorScheme.background),
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
