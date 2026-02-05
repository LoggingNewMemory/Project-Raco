import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:process_run/process_run.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quick_settings/quick_settings.dart';
import 'package:video_player/video_player.dart';
import '/l10n/app_localizations.dart';
import 'about_page.dart';
import 'utilities_page.dart';
import 'slingshot.dart';
import 'qs_menu.dart';
import 'raco.dart';

// --- QUICK SETTINGS HANDLERS ---

@pragma('vm:entry-point')
Tile onTileClicked(Tile tile) {
  try {
    Process.run('su', [
      '-c',
      'am start -a android.intent.action.VIEW -d "raco://qs_launch"',
    ]);
  } catch (e) {
    print("QS Error: $e");
  }

  tile.label = "Raco Mode";
  tile.tileStatus = TileStatus.active;
  tile.subtitle = "Tap for menu";
  return tile;
}

@pragma('vm:entry-point')
Tile onTileAdded(Tile tile) {
  tile.label = "Raco Mode";
  tile.tileStatus = TileStatus.active;
  tile.subtitle = "Tap for menu";
  tile.drawableName = "qs_logo";
  return tile;
}

@pragma('vm:entry-point')
void onTileRemoved() {
  // Cleanup resources if needed
}

// -------------------------------

final themeNotifier = ValueNotifier<Color?>(null);

class Language {
  final String code;
  final String name;
  final String displayName;

  const Language({
    required this.code,
    required this.name,
    required this.displayName,
  });
}

final List<Language> supportedLanguages = [
  const Language(code: 'en', name: 'English', displayName: 'EN'),
  const Language(code: 'id', name: 'Bahasa Indonesia', displayName: 'ID'),
  const Language(code: 'ja', name: '日本語', displayName: 'JP'),
  const Language(code: 'es', name: 'Español', displayName: 'ES'),
  const Language(code: 'ru', name: 'Русский', displayName: 'RU'),
];

class ConfigManager {
  static const String _defaultMode = 'NONE';
  static const String _configPath = '/data/ProjectRaco/raco.txt';

  static Future<Map<String, String>> readConfig() async {
    try {
      final result = await run('su', [
        '-c',
        'grep "^STATE=" $_configPath | cut -d= -f2',
      ], verbose: false);

      if (result.exitCode == 0) {
        String stateValue = result.stdout.toString().trim();
        String currentMode = _mapStateToMode(stateValue);
        return {'current_mode': currentMode};
      } else {
        return {'current_mode': _defaultMode};
      }
    } catch (e) {
      return {'current_mode': _defaultMode};
    }
  }

  static String _mapStateToMode(String stateValue) {
    switch (stateValue) {
      case '1':
        return 'PERFORMANCE';
      case '2':
        return 'BALANCED';
      case '3':
        return 'POWER_SAVE';
      case '4':
        return 'GAMING_PRO';
      case '5':
        return 'COOLDOWN';
      default:
        return _defaultMode;
    }
  }

  static Future<void> saveMode(String mode) async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initRacoVideoCache();

  // --- AUDIO PRELOAD START ---
  // Initialize and play audio immediately before the app widget tree builds.
  // This removes the delay caused by widget mounting and async checks in initState.
  VideoPlayerController? rootAudioController;
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('endfield_collab_enabled') ?? false;

    if (isEnabled) {
      rootAudioController = VideoPlayerController.asset('assets/Endfield.mp3');
      await rootAudioController.initialize();
      await rootAudioController.setLooping(true);
      await rootAudioController.play();
    }
  } catch (e) {
    print("Error preloading audio: $e");
  }
  // --- AUDIO PRELOAD END ---

  try {
    QuickSettings.setup(
      onTileClicked: onTileClicked,
      onTileAdded: onTileAdded,
      onTileRemoved: onTileRemoved,
    );
  } catch (e) {
    print("QS Setup Failed: $e");
  }

  runApp(MyApp(audioController: rootAudioController));
}

class MyApp extends StatefulWidget {
  final VideoPlayerController? audioController;

  const MyApp({Key? key, this.audioController}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  String? _backgroundImagePath;
  double _backgroundOpacity = 0.2;
  double _backgroundBlur = 0.0;
  String? _bannerImagePath;
  Color? _seedColorFromBanner;
  VideoPlayerController? _audioController;

  static final _defaultLightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
  );
  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );

  @override
  void initState() {
    super.initState();
    // Use the controller passed from main(), which is already playing if enabled
    _audioController = widget.audioController;
    _loadAllPreferences();
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _audioController?.dispose();
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _seedColorFromBanner = themeNotifier.value;
      });
    }
  }

  Future<void> _loadAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final int? seedValue = prefs.getInt('banner_seed_color');
    final Color? bannerColor = seedValue != null ? Color(seedValue) : null;

    _seedColorFromBanner = bannerColor;
    themeNotifier.value = bannerColor;

    // Handle case where user might toggle audio in settings page later,
    // though for startup, main() handled it.
    final bool isAudioEnabled =
        prefs.getBool('endfield_collab_enabled') ?? false;

    // If enabled but not playing (e.g. user enabled it in settings after boot)
    if (isAudioEnabled && _audioController == null) {
      _audioController = VideoPlayerController.asset('assets/Endfield.mp3');
      try {
        await _audioController!.initialize();
        await _audioController!.setLooping(true);
        await _audioController!.play();
      } catch (e) {
        print("Error loading audio late: $e");
      }
    }
    // If disabled but currently playing (e.g. user disabled it in settings)
    else if (!isAudioEnabled && _audioController != null) {
      await _audioController!.pause();
      _audioController!.dispose();
      _audioController = null;
    }

    setState(() {
      _locale = Locale(prefs.getString('language_code') ?? 'en');
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
      _backgroundBlur = prefs.getDouble('background_blur') ?? 0.0;
      _bannerImagePath = prefs.getString('banner_image_path');
    });
  }

  Future<void> _updateLocale(Locale locale) async {
    if (!mounted) return;
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (_seedColorFromBanner != null) {
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: _seedColorFromBanner!,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: _seedColorFromBanner!,
            brightness: Brightness.dark,
          );
        } else {
          lightColorScheme =
              lightDynamic?.harmonized() ?? _defaultLightColorScheme;
          darkColorScheme =
              darkDynamic?.harmonized() ?? _defaultDarkColorScheme;
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: _locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routes: {
            '/': (context) => _buildHome(context),
            '/menu': (context) => const QSMenuPage(),
          },
          theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
          ),
          themeMode: ThemeMode.dark,
        );
      },
    );
  }

  Widget _buildHome(BuildContext context) {
    return Builder(
      builder: (context) {
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Theme.of(context).colorScheme.background),
              if (_backgroundImagePath != null &&
                  _backgroundImagePath!.isNotEmpty)
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
              MainScreen(
                onLocaleChange: _updateLocale,
                onSettingsChanged: _loadAllPreferences,
                bannerImagePath: _bannerImagePath,
                backgroundImagePath: _backgroundImagePath,
                backgroundOpacity: _backgroundOpacity,
                backgroundBlur: _backgroundBlur,
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- UPDATED HELPER WIDGET: DELETES THEN TYPES ---
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration typeDuration;
  final Duration deleteDuration;

  const TypewriterText({
    Key? key,
    required this.text,
    this.style,
    this.typeDuration = const Duration(milliseconds: 30),
    this.deleteDuration = const Duration(milliseconds: 20),
  }) : super(key: key);

  @override
  _TypewriterTextState createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initial start: just type
    _startTyping(widget.text);
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // If text changed, Start Deleting first, then type new text
      _startDeleting(widget.text);
    }
  }

  void _startDeleting(String nextText) {
    _timer?.cancel();
    _timer = Timer.periodic(widget.deleteDuration, (timer) {
      if (_displayedText.isNotEmpty) {
        setState(() {
          _displayedText = _displayedText.substring(
            0,
            _displayedText.length - 1,
          );
        });
      } else {
        timer.cancel();
        // Once deletion is done, start typing the new text
        _startTyping(nextText);
      }
    });
  }

  void _startTyping(String textToType) {
    _timer?.cancel();
    _currentIndex = 0;

    if (textToType.isEmpty) {
      setState(() => _displayedText = "");
      return;
    }

    // Reset displayed text if we are starting fresh from empty
    // (Note: if coming from delete, it's already empty)
    if (_displayedText.isNotEmpty && _displayedText != textToType) {
      // Safety net: if we skipped delete logic somehow
      setState(() => _displayedText = "");
    }

    _timer = Timer.periodic(widget.typeDuration, (timer) {
      if (_currentIndex < textToType.length) {
        setState(() {
          _displayedText += textToType[_currentIndex];
          _currentIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}
// -------------------------------------------

class MainScreen extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  final VoidCallback onSettingsChanged;
  final String? bannerImagePath;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double backgroundBlur;

  const MainScreen({
    Key? key,
    required this.onLocaleChange,
    required this.onSettingsChanged,
    required this.bannerImagePath,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _hasRootAccess = false;
  bool _moduleInstalled = false;
  String _moduleVersion = 'Unknown';
  String _currentMode = 'NONE';
  String _selectedLanguage = 'EN';
  String _executingScript = '';
  bool _isLoading = true;
  bool _isEndfieldEngineRunning = false;
  bool _isContentVisible = false;

  int _swipeRightCount = 0;
  Timer? _swipeResetTimer;

  // --- TIPS VARIABLES ---
  Timer? _tipTimer;
  int _currentTipIndex = 0;
  final List<String> _tips = [
    "Swipe 3 times on the left somewhere and you can access the hidden terminal",
    "Swipe 3 times on the left and you can cancel the execution",
    "Official Telegram Channel of Project Raco is on Raco's Page",
    "Tap the Raco image! You will greeted by Raco",
    "Project Raco can't make a potato phone into a gaming phone",
    "Project Raco? GACOR KANG!",
    "Welcome to Project Raco app. Have a nice day!",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTipIndex = Random().nextInt(_tips.length);
    _startTipRotation();
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swipeResetTimer?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _startTipRotation() {
    // Increased duration slightly to allow for delete+type animation
    _tipTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshDynamicState();
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    await _loadSelectedLanguage();
    final rootGranted = await _checkRootAccess();
    if (!rootGranted) {
      if (mounted) {
        setState(() {
          _hasRootAccess = false;
          _moduleInstalled = false;
          _moduleVersion = 'Root Required';
          _currentMode = 'Root Required';
          _isLoading = false;
          _isContentVisible = true;
        });
      }
      return;
    }
    _hasRootAccess = true;
    final moduleIsInstalled = await _checkModuleInstalled();
    _moduleInstalled = moduleIsInstalled;
    await Future.wait([
      if (moduleIsInstalled) _getModuleVersion(),
      _refreshDynamicState(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isContentVisible = true;
      });
    }
  }

  Future<void> _refreshDynamicState() async {
    if (!_hasRootAccess) return;
    final results = await Future.wait([
      ConfigManager.readConfig(),
      _isEndfieldProcessRunning(),
    ]);
    final config = results[0] as Map<String, String>;
    final isRunning = results[1] as bool;
    if (mounted) {
      setState(() {
        _currentMode = config['current_mode'] ?? 'NONE';
        _isEndfieldEngineRunning = isRunning;
      });
    }
  }

  Future<bool> _checkRootAccess() async {
    try {
      var result = await run('su', ['-c', 'id'], verbose: false);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isEndfieldProcessRunning() async {
    if (!_hasRootAccess) return false;
    try {
      final result = await run('su', [
        '-c',
        'pgrep -x Endfield',
      ], verbose: false);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkModuleInstalled() async {
    if (!_hasRootAccess) return false;
    try {
      var result = await run('su', [
        '-c',
        'test -d /data/adb/modules/ProjectRaco && echo "yes"',
      ], verbose: false);
      return result.stdout.toString().trim() == 'yes';
    } catch (e) {
      return false;
    }
  }

  Future<void> _getModuleVersion() async {
    try {
      var result = await run('su', [
        '-c',
        'grep "^version=" /data/adb/modules/ProjectRaco/module.prop',
      ], verbose: false);
      String line = result.stdout.toString().trim();
      String version = line.contains('=')
          ? line.split('=')[1].trim()
          : 'Unknown';
      if (mounted) {
        setState(
          () => _moduleVersion = version.isNotEmpty ? version : 'Unknown',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _moduleVersion = 'Error');
    }
  }

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final languageCode = prefs.getString('language_code') ?? 'en';
    final selectedLang = supportedLanguages.firstWhere(
      (lang) => lang.code == languageCode,
      orElse: () => supportedLanguages.first,
    );
    setState(() {
      _selectedLanguage = selectedLang.displayName;
    });
  }

  Future<void> executeScript(String scriptArg, String modeKey) async {
    if (!_hasRootAccess ||
        !_moduleInstalled ||
        _executingScript.isNotEmpty ||
        _isEndfieldEngineRunning) {
      return;
    }
    String targetMode = (modeKey == 'CLEAR' || modeKey == 'COOLDOWN')
        ? 'NONE'
        : modeKey;
    if (mounted) {
      setState(() {
        _executingScript = scriptArg;
        _currentMode = targetMode;
        _swipeRightCount = 0;
      });
    }
    try {
      await run('su', [
        '-c',
        'sh /data/adb/modules/ProjectRaco/Scripts/Raco.sh $scriptArg > /dev/null 2>&1',
      ], verbose: false);
    } catch (e) {
      await _refreshDynamicState();
    } finally {
      if (mounted) setState(() => _executingScript = '');
      _refreshDynamicState();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_executingScript.isEmpty) return;
    if (details.primaryVelocity! > 500) {
      if (_swipeRightCount == 0) {
        setState(() {
          _swipeRightCount++;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.swipe_again_to_cancel),
            duration: const Duration(seconds: 2),
          ),
        );
        _swipeResetTimer?.cancel();
        _swipeResetTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _swipeRightCount = 0;
            });
          }
        });
      } else {
        _cancelExecution();
      }
    }
  }

  Future<void> _cancelExecution() async {
    _swipeResetTimer?.cancel();
    setState(() {
      _swipeRightCount = 0;
    });
    try {
      await run('su', ['-c', 'pkill -f Raco.sh'], verbose: false);
    } catch (e) {}
    if (mounted) {
      setState(() {
        _executingScript = '';
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.execution_cancelled),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      _refreshDynamicState();
    }
  }

  void _changeLanguage(String newLocaleCode) {
    final newLanguage = supportedLanguages.firstWhere(
      (lang) => lang.code == newLocaleCode,
      orElse: () => supportedLanguages.first,
    );
    final currentLanguage = supportedLanguages.firstWhere(
      (lang) => lang.displayName == _selectedLanguage,
      orElse: () => supportedLanguages.first,
    );
    if (newLocaleCode == currentLanguage.code) return;
    widget.onLocaleChange(Locale(newLocaleCode));
    if (mounted) {
      setState(() => _selectedLanguage = newLanguage.displayName);
    }
  }

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  void _navigateToAboutPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => AboutPage(
          backgroundImagePath: widget.backgroundImagePath,
          backgroundOpacity: widget.backgroundOpacity,
          backgroundBlur: widget.backgroundBlur,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
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
    );
  }

  void _navigateToUtilitiesPage() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => UtilitiesPage(
          initialBackgroundImagePath: widget.backgroundImagePath,
          initialBackgroundOpacity: widget.backgroundOpacity,
          initialBackgroundBlur: widget.backgroundBlur,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
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
    );
    widget.onSettingsChanged();
    _refreshDynamicState();
  }

  void _navigateToSlingshotPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => SlingshotPage(
          backgroundImagePath: widget.backgroundImagePath,
          backgroundOpacity: widget.backgroundOpacity,
          backgroundBlur: widget.backgroundBlur,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
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
    );
  }

  void _navigateToRacoPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RacoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onHorizontalDragEnd: _onHorizontalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.0),
                      child: LinearProgressIndicator(),
                    ),
                  )
                : AnimatedOpacity(
                    opacity: _isContentVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleHeader(colorScheme, localization),
                          const SizedBox(height: 16),
                          _buildBanner(localization),
                          const SizedBox(height: 10),
                          _buildTipsSection(colorScheme),
                          const SizedBox(height: 10),
                          _buildStatusRow(localization),
                          const SizedBox(height: 10),
                          _buildControlRow(
                            localization.power_save_desc,
                            '3',
                            localization.power_save,
                            Icons.battery_saver_outlined,
                            'POWER_SAVE',
                          ),
                          _buildControlRow(
                            localization.balanced_desc,
                            '2',
                            localization.balanced,
                            Icons.balance_outlined,
                            'BALANCED',
                          ),
                          _buildControlRow(
                            localization.performance_desc,
                            '1',
                            localization.performance,
                            Icons.speed_outlined,
                            'PERFORMANCE',
                          ),
                          _buildControlRow(
                            localization.gaming_desc,
                            '4',
                            localization.gaming_pro,
                            Icons.sports_esports_outlined,
                            'GAMING_PRO',
                          ),
                          _buildControlRow(
                            localization.cooldown_desc,
                            '5',
                            localization.cooldown,
                            Icons.ac_unit_outlined,
                            'COOLDOWN',
                          ),
                          _buildControlRow(
                            localization.clear_desc,
                            '6',
                            localization.clear,
                            Icons.clear_all_outlined,
                            'CLEAR',
                          ),
                          _buildSlingshotCard(localization),
                          const SizedBox(height: 10),
                          _buildUtilitiesCard(localization),
                          const SizedBox(height: 10),
                          _buildLanguageSelector(localization),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTipsSection(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "Did You Know?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // WRAPPED IN SIZED BOX FOR FIXED HEIGHT TO PREVENT MISCLICKS
          SizedBox(
            height: 40.0, // Fixed height for approx 2 lines
            child: Align(
              alignment: Alignment.topLeft,
              child: TypewriterText(
                text: _tips[_currentTipIndex],
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleHeader(
    ColorScheme colorScheme,
    AppLocalizations localization,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _navigateToAboutPage,
                child: Text(
                  localization.app_title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Text(
                localization.by,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.telegram,
                color: colorScheme.primary,
              ),
              onPressed: () => _launchURL('https://t.me/KLAGen2'),
              tooltip: 'Telegram',
            ),
            IconButton(
              icon: FaIcon(FontAwesomeIcons.github, color: colorScheme.primary),
              onPressed: () => _launchURL(
                'https://github.com/LoggingNewMemory/Project-Raco',
              ),
              tooltip: 'GitHub',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBanner(AppLocalizations localization) {
    Widget bannerImage;
    if (widget.bannerImagePath != null && widget.bannerImagePath!.isNotEmpty) {
      bannerImage = Image.file(
        File(widget.bannerImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/Raco.png',
            fit: BoxFit.cover,
            width: double.infinity,
          );
        },
      );
    } else {
      bannerImage = Image.asset(
        'assets/Raco.png',
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      );
    }

    String bannerText;
    if (_hasRootAccess) {
      if (_moduleInstalled) {
        bannerText = '${localization.app_title} $_moduleVersion';
      } else {
        bannerText =
            '${localization.app_title} ${localization.module_not_installed}';
      }
    } else {
      bannerText = localization.error_no_root;
    }

    return GestureDetector(
      onTap: _navigateToRacoPage,
      child: Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              bannerImage,
              Container(
                margin: const EdgeInsets.all(12.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  bannerText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(AppLocalizations localization) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            localization.root_access,
            _hasRootAccess ? localization.yes : localization.no,
            Icons.security_outlined,
            _hasRootAccess ? Colors.green : Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusCard(
            localization.mode_status_label,
            _isEndfieldEngineRunning
                ? localization.mode_endfield_engine
                : localization.mode_manual,
            Icons.settings_input_component_outlined,
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String label,
    String value,
    IconData icon,
    Color valueColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2.0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilitiesCard(AppLocalizations localization) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _navigateToUtilitiesPage,
        child: Container(
          height: 56.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localization.utilities,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlingshotCard(AppLocalizations localization) {
    final colorScheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: _isEndfieldEngineRunning ? 0.6 : 1.0,
      child: Card(
        elevation: 2.0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (_isEndfieldEngineRunning) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                      context,
                    )!.please_disable_endfield_engine_first,
                  ),
                ),
              );
            } else {
              _navigateToSlingshotPage();
            }
          },
          child: Container(
            height: 56.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.rocket_launch_outlined,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      localization.slingshot_title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectionDialog(AppLocalizations localization) {
    final currentLang = supportedLanguages.firstWhere(
      (lang) => lang.displayName == _selectedLanguage,
      orElse: () => supportedLanguages.first,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localization.select_language),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: supportedLanguages.map((language) {
                return RadioListTile<String>(
                  title: Text(language.name),
                  value: language.code,
                  groupValue: currentLang.code,
                  onChanged: (String? newLocaleCode) {
                    if (newLocaleCode != null) {
                      _changeLanguage(newLocaleCode);
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSelector(AppLocalizations localization) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showLanguageSelectionDialog(localization),
        child: Container(
          height: 56.0,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localization.select_language,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Row(
                children: [
                  Text(
                    supportedLanguages
                        .firstWhere(
                          (lang) => lang.displayName == _selectedLanguage,
                          orElse: () => supportedLanguages.first,
                        )
                        .name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.language, color: colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlRow(
    String description,
    String scriptArg,
    String buttonText,
    IconData modeIcon,
    String modeKey,
  ) {
    final isCurrentMode = _currentMode == modeKey;
    final isExecutingThis = _executingScript == scriptArg;
    final isEndfieldMode = _isEndfieldEngineRunning;
    final isInteractable = _hasRootAccess && _moduleInstalled;
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: isEndfieldMode ? 0.6 : 1.0,
      child: Card(
        elevation: 2.0,
        color: isCurrentMode && !isEndfieldMode
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: !isInteractable
              ? null
              : () {
                  if (isEndfieldMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          )!.please_disable_endfield_engine_first,
                        ),
                      ),
                    );
                  } else if (_executingScript.isEmpty) {
                    executeScript(scriptArg, modeKey);
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  modeIcon,
                  size: 24,
                  color: isCurrentMode && !isEndfieldMode
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buttonText,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: isCurrentMode && !isEndfieldMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: isCurrentMode && !isEndfieldMode
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: isCurrentMode && !isEndfieldMode
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isCurrentMode && !isEndfieldMode
                              ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                              : colorScheme.onSurfaceVariant.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isExecutingThis)
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCurrentMode && !isEndfieldMode
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.primary,
                      ),
                    ),
                  )
                else if (isCurrentMode && !isEndfieldMode)
                  Icon(
                    Icons.check_circle,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colorScheme.onSurface,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
