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
import 'topo_background.dart';

const String _expectedOfficialDev = "Kanagawa Yamada";
const String _expectedOfficialHash =
    "a03f3cc1ed8f803f0c8077e9af8c6ba0bdfe9c0798628a18698d076b6f7ca2d5fc498402c74515d7e64eda9391f33c929db11c3d3724c0ba6f93926335662f9b";

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
  tile.drawableName = "qs_logo";
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
  VideoPlayerController? rootAudioController;
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('endfield_collab_enabled') ?? false;

    // Check if we are launching via Quick Settings or into the Menu directly
    final String defaultRouteName =
        PlatformDispatcher.instance.defaultRouteName;
    final bool isQsMenuLaunch =
        defaultRouteName.contains('qs_launch') ||
        defaultRouteName.contains('/menu');

    if (isEnabled && !isQsMenuLaunch) {
      rootAudioController = VideoPlayerController.asset('assets/Endfield.mp3');
      await rootAudioController.initialize();
      // Ensure looping is set to true immediately
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
  bool _endfieldCollabEnabled = false;
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

    final bool isAudioEnabled =
        prefs.getBool('endfield_collab_enabled') ?? false;

    // Handle audio controller logic
    final String defaultRouteName =
        PlatformDispatcher.instance.defaultRouteName;
    final bool isQsMenuLaunch =
        defaultRouteName.contains('qs_launch') ||
        defaultRouteName.contains('/menu');

    if (isAudioEnabled && !isQsMenuLaunch) {
      if (_audioController == null) {
        _audioController = VideoPlayerController.asset('assets/Endfield.mp3');
        try {
          await _audioController!.initialize();
          await _audioController!.setLooping(true);
          await _audioController!.play();
        } catch (e) {
          print("Error loading audio late: $e");
        }
      } else {
        if (!_audioController!.value.isPlaying) {
          await _audioController!.play();
        }
        if (!_audioController!.value.isLooping) {
          await _audioController!.setLooping(true);
        }
      }
    } else if ((!isAudioEnabled || isQsMenuLaunch) &&
        _audioController != null) {
      await _audioController!.pause();
      _audioController!.dispose();
      _audioController = null;
    }

    setState(() {
      _locale = Locale(prefs.getString('language_code') ?? 'en');
      _backgroundImagePath = prefs.getString('background_image_path');
      _backgroundOpacity = prefs.getDouble('background_opacity') ?? 0.2;
      _backgroundBlur = prefs.getDouble('background_blur') ?? 0.0;
      _endfieldCollabEnabled = isAudioEnabled;
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
              if (_endfieldCollabEnabled)
                Positioned.fill(
                  child: TopoBackground(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.15),
                    speed: 0.15,
                  ),
                )
              else if (_backgroundImagePath != null &&
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
                endfieldEnabled: _endfieldCollabEnabled,
                audioController: _audioController,
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
  final bool scrollToBottom;

  const TypewriterText({
    Key? key,
    required this.text,
    this.style,
    this.typeDuration = const Duration(milliseconds: 30),
    this.deleteDuration = const Duration(milliseconds: 20),
    this.scrollToBottom = false,
  }) : super(key: key);

  @override
  _TypewriterTextState createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startTyping(widget.text);
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
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

    if (_displayedText.isNotEmpty && _displayedText != textToType) {
      setState(() => _displayedText = "");
    }

    _timer = Timer.periodic(widget.typeDuration, (timer) {
      if (_currentIndex < textToType.length) {
        setState(() {
          _displayedText += textToType[_currentIndex];
          _currentIndex++;
        });

        if (widget.scrollToBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scrollToBottom) {
      return SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: Text(_displayedText, style: widget.style),
      );
    }
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
  final bool endfieldEnabled;
  final VideoPlayerController? audioController;

  const MainScreen({
    Key? key,
    required this.onLocaleChange,
    required this.onSettingsChanged,
    required this.bannerImagePath,
    required this.backgroundImagePath,
    required this.backgroundOpacity,
    required this.backgroundBlur,
    required this.endfieldEnabled,
    this.audioController,
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

  // Build Info
  String? _buildType;
  String? _buildBy;

  int _swipeRightCount = 0;
  Timer? _swipeResetTimer;

  late String _generatedTerminalId;

  // --- TIPS VARIABLES ---
  Timer? _tipTimer;
  int _currentTipIndex = 0;
  List<String> _tips = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Generate Random Terminal ID
    _generateTerminalId();
    _startTipRotation();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTips();
  }

  void _loadTips() {
    final loc = AppLocalizations.of(context);
    if (loc != null) {
      _tips = [
        loc.tip_1,
        loc.tip_2,
        loc.tip_3,
        loc.tip_4,
        loc.tip_5,
        loc.tip_6,
        loc.tip_7,
      ];
      // Ensure index is valid after language change
      if (_currentTipIndex >= _tips.length) {
        _currentTipIndex = 0;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swipeResetTimer?.cancel();
    _tipTimer?.cancel();
    super.dispose();
  }

  void _generateTerminalId() {
    final random = Random();
    final part1 = random.nextInt(9000) + 1000; // 4 digits
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final part2 =
        '${chars[random.nextInt(chars.length)]}${chars[random.nextInt(chars.length)]}'; // 2 letters
    final part3 = random.nextInt(900) + 100; // 3 digits
    _generatedTerminalId = 'ID: $part1-$part2-$part3';
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted && _tips.isNotEmpty) {
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
      // RESUME LOOPING IF APP COMES TO FOREGROUND
      final String defaultRouteName =
          PlatformDispatcher.instance.defaultRouteName;
      final bool isQsMenuLaunch =
          defaultRouteName.contains('qs_launch') ||
          defaultRouteName.contains('/menu');

      if (!isQsMenuLaunch &&
          widget.endfieldEnabled &&
          widget.audioController != null &&
          widget.audioController!.value.isInitialized) {
        if (!widget.audioController!.value.isPlaying) {
          widget.audioController!.play();
        }
      }
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

    // Check Build Status now that we have root
    await _checkBuildStatus();

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

  Future<void> _checkBuildStatus() async {
    const String basePath = '/data/adb/modules/ProjectRaco/';

    // Check OFFICIAL
    try {
      final officialResult = await Process.run('su', [
        '-c',
        'cat ${basePath}OFFICIAL',
      ]);

      if (officialResult.exitCode == 0) {
        final content = officialResult.stdout.toString().trim();
        final expectedString =
            'Dev:$_expectedOfficialDev-$_expectedOfficialHash-OFFICIAL';

        if (content == expectedString) {
          if (mounted) {
            setState(() {
              _buildType = 'OFFICIAL';
              _buildBy = _expectedOfficialDev;
            });
          }
          return; // Success
        } else {
          exit(0); // Tampered official file
        }
      }
    } catch (e) {
      // Ignore and try unofficial
    }

    // Check UNOFFICIAL
    try {
      final unofficialResult = await Process.run('su', [
        '-c',
        'cat ${basePath}UNOFFICIAL',
      ]);

      if (unofficialResult.exitCode == 0) {
        final content = unofficialResult.stdout.toString().trim();
        final RegExp regExp = RegExp(r'^Dev:(.+)-([a-fA-F0-9]+)-UNOFFICIAL$');
        final match = regExp.firstMatch(content);

        if (match != null) {
          final devName = match.group(1);
          if (mounted) {
            setState(() {
              _buildType = 'UNOFFICIAL';
              _buildBy = devName;
            });
          }
          return; // Success
        } else {
          exit(0); // Tampered unofficial file
        }
      }
    } catch (e) {
      // Ignore
    }

    // If neither official nor unofficial matched:
    exit(0);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error_launch_url(url)),
          ),
        );
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
          buildType: _buildType,
          buildBy: _buildBy,
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

  // ==========================================
  //      STANDARD MATERIAL LAYOUT
  // ==========================================

  Widget _buildStandardLayout(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
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
                        _buildTipsSection(colorScheme, localization),
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
    );
  }

  // ==========================================
  //    ENDFIELD (CROWDED INDUSTRIAL) LAYOUT
  // ==========================================

  Widget _buildEndfieldLayout(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    // Tech Colors
    final Color techYellow = const Color(0xFFFFD700); // Warning/Highlight
    final Color techBlue = const Color(0xFF00BFFF); // Data/Holo

    final monoStyle = const TextStyle(
      fontFamily: 'RobotoMono',
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    );

    // Randomize integrity between 80-100%
    final int integrity = 80 + Random().nextInt(21);

    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: SafeArea(
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: techYellow))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- HEADER BLOCK (CLICKABLE) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localization.endfield_talos_protocol,
                                style: monoStyle.copyWith(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                localization.endfield_raco_terminal,
                                style: monoStyle.copyWith(
                                  color: techYellow,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Container(
                                height: 2,
                                width: 100,
                                color: techYellow,
                              ),
                            ],
                          ),
                          IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.circleInfo,
                              color: techBlue,
                            ),
                            onPressed: _navigateToAboutPage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // --- BANNER BLOCK ---
                      GestureDetector(
                        onTap: _navigateToRacoPage,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: techBlue.withOpacity(0.5),
                              ),
                              color: Colors.black,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (widget.bannerImagePath != null &&
                                    widget.bannerImagePath!.isNotEmpty)
                                  Image.file(
                                    File(widget.bannerImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: Colors.black26),
                                  )
                                else
                                  Image.asset(
                                    'assets/Raco.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white12,
                                      ),
                                    ),
                                  ),

                                // Scanline overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.8),
                                      ],
                                      stops: const [0.6, 1.0],
                                    ),
                                  ),
                                ),

                                // Tech overlay info
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    color: techYellow,
                                    child: Text(
                                      "${localization.endfield_system_status}: ${_moduleInstalled ? localization.status_online : localization.status_offline} // V:$_moduleVersion",
                                      style: monoStyle.copyWith(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(
                                    Icons.nfc,
                                    color: Colors.white54,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- STATUS GRID ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildEndfieldStatBox(
                              "ROOT_ACCESS",
                              _hasRootAccess
                                  ? localization.yes.toUpperCase()
                                  : localization.no.toUpperCase(),
                              _hasRootAccess ? techBlue : Colors.red,
                              monoStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildEndfieldStatBox(
                              "ENGINE",
                              _isEndfieldEngineRunning
                                  ? localization.status_active
                                  : localization.status_standby,
                              _isEndfieldEngineRunning
                                  ? techYellow
                                  : Colors.white54,
                              monoStyle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // --- VERSION TICKER ---
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          color: Colors.black45,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.memory, size: 14, color: Colors.white54),
                            const SizedBox(width: 8),
                            Text(
                              "${localization.endfield_module}: $_moduleVersion",
                              style: monoStyle.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              localization.endfield_sys_rdy,
                              style: monoStyle.copyWith(
                                color: techBlue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- MODE SELECTOR (CROWDED GRID) ---
                      Text(
                        localization.endfield_performance_protocols,
                        style: monoStyle.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildEndfieldModeButton(
                            localization.power_save,
                            "3",
                            "POWER_SAVE",
                            Icons.battery_saver,
                            techBlue,
                            monoStyle,
                            localization,
                          ),
                          _buildEndfieldModeButton(
                            localization.balanced,
                            "2",
                            "BALANCED",
                            Icons.balance,
                            techBlue,
                            monoStyle,
                            localization,
                          ),
                          _buildEndfieldModeButton(
                            localization.performance,
                            "1",
                            "PERFORMANCE",
                            Icons.speed,
                            techYellow,
                            monoStyle,
                            localization,
                          ),
                          _buildEndfieldModeButton(
                            localization.gaming_pro,
                            "4",
                            "GAMING_PRO",
                            Icons.gamepad,
                            Colors.redAccent,
                            monoStyle,
                            localization,
                          ),
                          _buildEndfieldModeButton(
                            localization.cooldown,
                            "5",
                            "COOLDOWN",
                            Icons.ac_unit,
                            Colors.cyanAccent,
                            monoStyle,
                            localization,
                          ),
                          _buildEndfieldModeButton(
                            localization.clear,
                            "6",
                            "CLEAR",
                            Icons.delete_outline,
                            Colors.white,
                            monoStyle,
                            localization,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SYSTEM LOGS (VISUAL NOISE) ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border(
                            left: BorderSide(color: techYellow, width: 4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localization.endfield_system_log,
                              style: monoStyle.copyWith(
                                color: techYellow,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Fixed height container for stability, wrapped in ScrollView
                            SizedBox(
                              height: 50,
                              child: Opacity(
                                opacity: 0.7,
                                child: TypewriterText(
                                  text:
                                      "${_tips.isNotEmpty ? _tips[_currentTipIndex] : '...'}\n${localization.endfield_waiting_input}\n${localization.endfield_memory_integrity(integrity)}",
                                  style: monoStyle.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                  scrollToBottom: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- NAVIGATION MODULES ---
                      Text(
                        localization.endfield_external_modules,
                        style: monoStyle.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),

                      InkWell(
                        onTap: () {
                          if (_isEndfieldEngineRunning) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  localization
                                      .please_disable_endfield_engine_first,
                                ),
                              ),
                            );
                          } else {
                            _navigateToSlingshotPage();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: techBlue.withOpacity(0.5),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                techBlue.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.rocket_launch, color: techBlue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  localization.endfield_slingshot_preloader,
                                  style: monoStyle.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                localization.endfield_exec,
                                style: monoStyle.copyWith(
                                  color: techBlue,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _navigateToUtilitiesPage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            color: Colors.white10,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.build, color: Colors.white54),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  localization.endfield_utilities_tools,
                                  style: monoStyle.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                localization.endfield_open,
                                style: monoStyle.copyWith(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showLanguageSelectionDialog(localization),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            color: Colors.white10,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.language, color: Colors.white54),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  localization.endfield_language_select,
                                  style: monoStyle.copyWith(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                "[${_selectedLanguage}]",
                                style: monoStyle.copyWith(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      // Bottom Decoration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _generatedTerminalId,
                            style: monoStyle.copyWith(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                          Row(
                            children: [
                              FaIcon(
                                FontAwesomeIcons.telegram,
                                size: 16,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 16),
                              FaIcon(
                                FontAwesomeIcons.github,
                                size: 16,
                                color: Colors.white24,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEndfieldStatBox(
    String label,
    String value,
    Color color,
    TextStyle baseStyle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: baseStyle.copyWith(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(value, style: baseStyle.copyWith(fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildEndfieldModeButton(
    String label,
    String scriptArg,
    String modeKey,
    IconData icon,
    Color color,
    TextStyle baseStyle,
    AppLocalizations localization,
  ) {
    final bool isSelected = _currentMode == modeKey;
    final bool isExecuting = _executingScript == scriptArg;

    return InkWell(
      onTap: () {
        if (!_isEndfieldEngineRunning && _executingScript.isEmpty) {
          executeScript(scriptArg, modeKey);
        }
      },
      child: Container(
        width: (MediaQuery.of(context).size.width / 2) - 20, // 2 column grid
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.black.withOpacity(
                  0.3,
                ), // Added slight dark BG for readability
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.white54,
                  size: 20,
                ),
                if (isExecuting)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              style: baseStyle.copyWith(fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              isSelected
                  ? "${localization.mode_status_label} ${localization.status_active}"
                  : "${localization.mode_status_label} ${localization.status_ready}",
              style: baseStyle.copyWith(
                fontSize: 8,
                color: isSelected ? color : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  //      ORIGINAL BUILDER LOGIC
  // ==========================================

  // Standard helper widgets (kept for standard layout)
  Widget _buildTipsSection(
    ColorScheme colorScheme,
    AppLocalizations localization,
  ) {
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
                localization.tips_title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40.0,
            child: Align(
              alignment: Alignment.topLeft,
              child: TypewriterText(
                text: _tips.isNotEmpty ? _tips[_currentTipIndex] : '',
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

  @override
  Widget build(BuildContext context) {
    if (widget.endfieldEnabled) {
      return _buildEndfieldLayout(context);
    }
    return _buildStandardLayout(context);
  }
}
