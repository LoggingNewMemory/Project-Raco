import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:project_raco/terminal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/l10n/app_localizations.dart';
import 'UtilitiesPage/appearance.dart';
import 'UtilitiesPage/automation.dart';
import 'UtilitiesPage/core_tweaks.dart';
import 'UtilitiesPage/system.dart';
import 'UtilitiesPage/utils.dart';

//region Models for Search and Navigation
class UtilityCategory {
  final String title;
  final IconData icon;
  final Widget page;

  UtilityCategory({
    required this.title,
    required this.icon,
    required this.page,
  });
}

class SearchResultItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget navigationTarget;
  final String searchKeywords;

  SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.navigationTarget,
    required this.searchKeywords,
  });
}
//endregion

class UtilitiesPage extends StatefulWidget {
  final String? initialBackgroundImagePath;
  final double initialBackgroundOpacity;
  final double initialBackgroundBlur;

  const UtilitiesPage({
    Key? key,
    required this.initialBackgroundImagePath,
    required this.initialBackgroundOpacity,
    required this.initialBackgroundBlur,
  }) : super(key: key);

  @override
  _UtilitiesPageState createState() => _UtilitiesPageState();
}

class _UtilitiesPageState extends State<UtilitiesPage> {
  bool _isLoading = true;
  bool _hasRootAccess = false;
  bool _isContentVisible = false;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;
  double _backgroundBlur = 0.0;
  String? _buildType;
  String? _buildBy;

  final TextEditingController _searchController = TextEditingController();

  List<UtilityCategory> _allCategories = [];
  List<SearchResultItem> _allSearchableItems = [];
  List<SearchResultItem> _filteredSearchResults = [];

  // State for swipe detection
  int _swipeCount = 0;
  Timer? _swipeResetTimer;

  @override
  void initState() {
    super.initState();
    _backgroundImagePath = widget.initialBackgroundImagePath;
    _backgroundOpacity = widget.initialBackgroundOpacity;
    _backgroundBlur = widget.initialBackgroundBlur;

    _initializePage();
    _searchController.addListener(_updateSearchResults);
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearchResults);
    _searchController.dispose();
    _swipeResetTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  /// Handles the logic for the secret swipe gesture on the build info card.
  void _handleCardSwipe() {
    _swipeResetTimer?.cancel(); // Cancel any previous timer
    _swipeCount++;

    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(); // Hide previous snackbar

    if (_swipeCount == 3) {
      _swipeCount = 0; // Reset for next time
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HackerStartupScreen()),
      );
    } else {
      // Reset the count if the user doesn't swipe again within 2 seconds
      _swipeResetTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _swipeCount = 0;
          });
        }
      });
    }
  }

  Future<void> _loadBackgroundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
      _backgroundBlur = prefs.getDouble('background_blur') ?? 0.0;
    });
  }

  Future<void> _loadBuildInfo() async {
    const String path = '/data/adb/modules/ProjectRaco/';
    final List<String> buildFiles = ['Official', 'Canary', 'CBT'];
    String? foundBuildType;
    String? foundBuildBy;

    for (String fileName in buildFiles) {
      final filePath = '$path$fileName';
      try {
        // Use root to check if file exists
        final fileExistsResult = await Process.run('su', [
          '-c',
          'test -f $filePath && echo "exists"',
        ]);

        if (fileExistsResult.exitCode == 0 &&
            (fileExistsResult.stdout as String).trim() == 'exists') {
          // If it exists, use root to read the file content
          final readFileResult = await Process.run('su', [
            '-c',
            'cat $filePath',
          ]);
          if (readFileResult.exitCode == 0) {
            foundBuildType = fileName;
            foundBuildBy = readFileResult.stdout as String;
            break; // Stop after finding the first valid file
          }
        }
      } catch (e) {
        // Handle potential errors if 'su' command fails
        print('Error running root command for $fileName: $e');
      }
    }

    if (mounted) {
      setState(() {
        _buildType = foundBuildType;
        _buildBy = foundBuildBy?.trim();
      });
    }
  }

  Future<void> _initializePage() async {
    await _loadBuildInfo(); // Load build info first
    final bool hasRoot = await checkRootAccess();

    if (!mounted) return;
    setState(() {
      _hasRootAccess = hasRoot;
      _isLoading = false;
      _isContentVisible = true;
    });
  }

  void _setupData(AppLocalizations localization) {
    _allCategories = [];
    _allSearchableItems = [];

    final coreTweaksPage = CoreTweaksPage(
      backgroundImagePath: _backgroundImagePath,
      backgroundOpacity: _backgroundOpacity,
      backgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.core_tweaks_title,
        icon: Icons.tune,
        page: coreTweaksPage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.device_mitigation_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.security_update_warning_outlined,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'device mitigation fix tweak encore',
      ),
      SearchResultItem(
        title: localization.lite_mode_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.energy_savings_leaf_outlined,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'lite mode battery power savings',
      ),
      SearchResultItem(
        title: localization.custom_governor_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.speed,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'custom governor cpu performance',
      ),
      SearchResultItem(
        title: localization.better_powersave_title,
        subtitle: localization.core_tweaks_title,
        icon: Icons.battery_saver_outlined,
        navigationTarget: coreTweaksPage,
        searchKeywords: 'better powersave battery cpu frequency half minimum',
      ),
    ]);

    final automationPage = AutomationPage(
      backgroundImagePath: _backgroundImagePath,
      backgroundOpacity: _backgroundOpacity,
      backgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.automation_title,
        icon: Icons.smart_toy_outlined,
        page: automationPage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.hamada_ai,
        subtitle: localization.automation_title,
        icon: Icons.smart_toy_outlined,
        navigationTarget: automationPage,
        searchKeywords: 'hamada ai automation bot',
      ),
      SearchResultItem(
        title: localization.edit_game_txt_title,
        subtitle: localization.automation_title,
        icon: Icons.edit_note,
        navigationTarget: automationPage,
        searchKeywords: 'edit game txt list apps',
      ),
    ]);

    final systemPage = SystemPage(
      backgroundImagePath: _backgroundImagePath,
      backgroundOpacity: _backgroundOpacity,
      backgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.system_title,
        icon: Icons.settings_system_daydream,
        page: systemPage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.dnd_title,
        subtitle: localization.system_title,
        icon: Icons.do_not_disturb_on_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'dnd do not disturb notifications silence',
      ),
      SearchResultItem(
        title: localization.anya_thermal_title,
        subtitle: localization.system_title,
        icon: Icons.thermostat_outlined,
        navigationTarget: systemPage,
        searchKeywords:
            'anya melfissa thermal temperature heat throttle flowstate',
      ),
      SearchResultItem(
        title: localization.bypass_charging_title,
        subtitle: localization.system_title,
        icon: Icons.bolt_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'bypass charging battery power',
      ),
      SearchResultItem(
        title: localization.downscale_resolution,
        subtitle: localization.system_title,
        icon: Icons.aspect_ratio_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'downscale resolution screen density display',
      ),
      SearchResultItem(
        title: localization.fstrim_title,
        subtitle: localization.system_title,
        icon: Icons.cleaning_services_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'fstrim trim storage system maintenance clean',
      ),
      SearchResultItem(
        title: localization.clear_cache_title,
        subtitle: localization.system_title,
        icon: Icons.delete_sweep_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'clear cache temporary files system maintenance clean',
      ),
      SearchResultItem(
        title: localization.screen_modifier_title,
        subtitle: localization.system_title,
        icon: Icons.palette_outlined,
        navigationTarget: systemPage,
        searchKeywords: 'screen modifier color saturation display rgb adjust',
      ),
    ]);

    final appearancePage = AppearancePage(
      initialBackgroundImagePath: _backgroundImagePath,
      initialBackgroundOpacity: _backgroundOpacity,
      initialBackgroundBlur: _backgroundBlur,
    );
    _allCategories.add(
      UtilityCategory(
        title: localization.appearance_title,
        icon: Icons.color_lens_outlined,
        page: appearancePage,
      ),
    );
    _allSearchableItems.addAll([
      SearchResultItem(
        title: localization.background_settings_title,
        subtitle: localization.appearance_title,
        icon: Icons.image_outlined,
        navigationTarget: appearancePage,
        searchKeywords: 'background image wallpaper opacity theme blur',
      ),
      SearchResultItem(
        title: localization.banner_settings_title,
        subtitle: localization.appearance_title,
        icon: Icons.panorama_outlined,
        navigationTarget: appearancePage,
        searchKeywords: 'banner image header theme color',
      ),
    ]);
  }

  void _updateSearchResults() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _filteredSearchResults = [];
        });
      }
    } else {
      final queryTerms = query.split(' ').where((t) => t.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _filteredSearchResults = _allSearchableItems.where((item) {
            final itemKeywords = item.searchKeywords.toLowerCase().split(' ');
            return queryTerms.every(
              (term) => itemKeywords.any((keyword) => keyword.startsWith(term)),
            );
          }).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    if (_allCategories.isEmpty && !_isLoading) {
      _setupData(localization);
    }
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSearching = _searchController.text.isNotEmpty;

    final Widget pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.utilities_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_hasRootAccess
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  localization.error_no_root,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            )
          : AnimatedOpacity(
              opacity: _isContentVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  if (_buildType != null &&
                      _buildBy != null &&
                      _buildBy!.isNotEmpty)
                    GestureDetector(
                      onHorizontalDragEnd: (details) {
                        // Detect a swipe from left to right with sufficient velocity
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! > 100) {
                          _handleCardSwipe();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Card(
                          elevation: 2.0,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localization.build_version_title(
                                          _buildType!,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        localization.build_by_title(_buildBy!),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: localization.search_utilities,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Expanded(
                    child: isSearching
                        ? _buildSearchResultsList()
                        : _buildCategoryList(),
                  ),
                ],
              ),
            ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Theme.of(context).colorScheme.background),
        if (_backgroundImagePath != null && _backgroundImagePath!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _backgroundBlur,
              sigmaY: _backgroundBlur,
            ),
            child: Opacity(
              opacity: _backgroundOpacity,
              child: Image.file(
                File(_backgroundImagePath!),
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

  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: _allCategories.length,
      itemBuilder: (context, index) {
        final category = _allCategories[index];
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: Icon(
              category.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              category.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      category.page,
                  transitionDuration: const Duration(milliseconds: 300),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: child,
                        );
                      },
                ),
              ).then((_) => _loadBackgroundPreferences());
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    if (_filteredSearchResults.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      itemCount: _filteredSearchResults.length,
      itemBuilder: (context, index) {
        final item = _filteredSearchResults[index];
        return ListTile(
          leading: Icon(item.icon),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    item.navigationTarget,
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
              ),
            ).then((_) => _loadBackgroundPreferences());
          },
        );
      },
    );
  }
}
