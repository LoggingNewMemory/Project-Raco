import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '/l10n/app_localizations.dart';
import '../topo_background.dart';

class AppearancePage extends StatefulWidget {
  final String? initialBackgroundImagePath;
  final double initialBackgroundOpacity;
  final double initialBackgroundBlur;

  const AppearancePage({
    Key? key,
    required this.initialBackgroundImagePath,
    required this.initialBackgroundOpacity,
    required this.initialBackgroundBlur,
  }) : super(key: key);
  @override
  _AppearancePageState createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _isLoading = true;
  String? backgroundImagePath;
  double backgroundOpacity = 0.2;
  double backgroundBlur = 0.0;
  String? bannerImagePath;
  bool endfieldCollabEnabled = false;

  @override
  void initState() {
    super.initState();
    backgroundImagePath = widget.initialBackgroundImagePath;
    backgroundOpacity = widget.initialBackgroundOpacity;
    backgroundBlur = widget.initialBackgroundBlur;
    _loadAppearanceSettings();
  }

  Future<void> _loadAppearanceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      bannerImagePath = prefs.getString('banner_image_path');
      endfieldCollabEnabled = prefs.getBool('endfield_collab_enabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleEndfieldCollab(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('endfield_collab_enabled', value);
    if (mounted) {
      setState(() {
        endfieldCollabEnabled = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.please_restart_app),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final pageContent = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(localization.appearance_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          BackgroundSettingsCard(
            initialPath: backgroundImagePath,
            initialOpacity: backgroundOpacity,
            initialBlur: backgroundBlur,
            onSettingsChanged: (path, opacity, blur) {
              setState(() {
                backgroundImagePath = path;
                backgroundOpacity = opacity;
                backgroundBlur = blur;
              });
            },
          ),
          BannerSettingsCard(
            initialPath: bannerImagePath,
            onSettingsChanged: (path) {
              setState(() => bannerImagePath = path);
            },
          ),
          EndfieldSettingsCard(
            value: endfieldCollabEnabled,
            onChanged: _toggleEndfieldCollab,
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: colorScheme.surface),

        if (endfieldCollabEnabled)
          Positioned.fill(
            child: TopoBackground(
              color: colorScheme.primary.withOpacity(0.15),
              speed: 0.15,
            ),
          )
        else if (backgroundImagePath != null && backgroundImagePath!.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: backgroundBlur,
              sigmaY: backgroundBlur,
            ),
            child: Opacity(
              opacity: backgroundOpacity,
              child: Image.file(
                File(backgroundImagePath!),
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

class BackgroundSettingsCard extends StatefulWidget {
  final String? initialPath;
  final double initialOpacity;
  final double initialBlur;
  final Function(String?, double, double) onSettingsChanged;

  const BackgroundSettingsCard({
    Key? key,
    required this.initialPath,
    required this.initialOpacity,
    required this.initialBlur,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _BackgroundSettingsCardState createState() => _BackgroundSettingsCardState();
}

class _BackgroundSettingsCardState extends State<BackgroundSettingsCard>
    with AutomaticKeepAliveClientMixin {
  late String? _path;
  late double _opacity;
  late double _blurPercentage;
  final double _maxSigma = 15.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _opacity = widget.initialOpacity;
    _blurPercentage = (widget.initialBlur / _maxSigma * 100.0).clamp(
      0.0,
      100.0,
    );
  }

  @override
  void didUpdateWidget(BackgroundSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath ||
        widget.initialOpacity != oldWidget.initialOpacity ||
        widget.initialBlur != oldWidget.initialBlur) {
      if (mounted) {
        setState(() {
          _path = widget.initialPath;
          _opacity = widget.initialOpacity;
          _blurPercentage = (widget.initialBlur / _maxSigma * 100.0).clamp(
            0.0,
            100.0,
          );
        });
      }
    }
  }

  double get _currentSigmaValue => (_blurPercentage / 100.0 * _maxSigma);

  Future<void> _pickAndSetImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('background_image_path', pickedFile.path);
        if (mounted) {
          setState(() => _path = pickedFile.path);
        }
        widget.onSettingsChanged(_path, _opacity, _currentSigmaValue);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _updateOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_opacity', opacity);
    widget.onSettingsChanged(_path, opacity, _currentSigmaValue);
  }

  Future<void> _updateBlur(double percentage) async {
    final sigmaValue = (percentage / 100.0 * _maxSigma);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('background_blur', sigmaValue);
    widget.onSettingsChanged(_path, _opacity, sigmaValue);
  }

  Future<void> _resetBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_image_path');
    await prefs.setDouble('background_opacity', 0.2);
    await prefs.remove('background_blur');
    if (mounted) {
      setState(() {
        _path = null;
        _opacity = 0.2;
        _blurPercentage = 0.0;
      });
    }
    widget.onSettingsChanged(null, 0.2, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              localization.background_settings_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.background_settings_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Text(
              localization.opacity_slider_label,
              style: textTheme.bodyMedium,
            ),
            Slider(
              value: _opacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(_opacity * 100).toStringAsFixed(0)}%',
              onChanged: (value) {
                if (mounted) {
                  setState(() => _opacity = value);
                }
                widget.onSettingsChanged(_path, value, _currentSigmaValue);
              },
              onChangeEnd: _updateOpacity,
            ),
            Text(localization.blur_slider_label, style: textTheme.bodyMedium),
            Slider(
              value: _blurPercentage,
              min: 0.0,
              max: 100.0,
              divisions: 100,
              label: '${_blurPercentage.round()}%',
              onChanged: (value) {
                if (mounted) {
                  setState(() => _blurPercentage = value);
                }
                final currentSigma = (value / 100.0 * _maxSigma);
                widget.onSettingsChanged(_path, _opacity, currentSigma);
              },
              onChangeEnd: _updateBlur,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickAndSetImage,
                    child: const Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resetBackground,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                    ),
                    child: const Icon(Icons.delete_outline),
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

class BannerSettingsCard extends StatefulWidget {
  final String? initialPath;
  final Function(String?) onSettingsChanged;

  const BannerSettingsCard({
    Key? key,
    required this.initialPath,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _BannerSettingsCardState createState() => _BannerSettingsCardState();
}

class _BannerSettingsCardState extends State<BannerSettingsCard>
    with AutomaticKeepAliveClientMixin {
  late String? _path;
  bool _isProcessing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  @override
  void didUpdateWidget(BannerSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != oldWidget.initialPath) {
      if (mounted) {
        setState(() {
          _path = widget.initialPath;
        });
      }
    }
  }

  Future<void> _generateAndSaveSeedColor(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'banner_seed_color';
    Color? newColor;

    if (imagePath == null || imagePath.isEmpty) {
      await prefs.remove(key);
      newColor = null;
    } else {
      try {
        final int? seedColorValue = await compute(
          _calculateSeedColor,
          imagePath,
        );
        if (seedColorValue != null) {
          await prefs.setInt(key, seedColorValue);
          newColor = Color(seedColorValue);
        } else {
          await prefs.remove(key);
          newColor = null;
        }
      } catch (e) {
        await prefs.remove(key);
        newColor = null;
      }
    }
    themeNotifier.value = newColor;
  }

  Future<void> _pickAndCropImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null || !mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Banner',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        setState(() => _isProcessing = true);
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(
          croppedFile.path,
        ).copy(p.join(appDir.path, fileName));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('banner_image_path', savedImage.path);

        await _generateAndSaveSeedColor(savedImage.path);

        if (mounted) {
          setState(() {
            _path = savedImage.path;
            _isProcessing = false;
          });
        }
        widget.onSettingsChanged(_path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick or crop image: $e')),
        );
      }
    }
  }

  Future<void> _resetBanner() async {
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('banner_image_path');

    await _generateAndSaveSeedColor(null);

    if (mounted) {
      setState(() {
        _path = null;
        _isProcessing = false;
      });
    }
    widget.onSettingsChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              localization.banner_settings_title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localization.banner_settings_description,
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            if (_isProcessing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        localization.applying_new_color,
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pickAndCropImage,
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resetBanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                      child: const Icon(Icons.delete_outline),
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

class EndfieldSettingsCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const EndfieldSettingsCard({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHighest,
      child: SwitchListTile(
        title: Text(
          "Endfield Collab",
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "Switch to Endfield Theme",
          style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        value: value,
        onChanged: onChanged,
        secondary: Icon(Icons.music_note_outlined, color: colorScheme.primary),
        activeColor: colorScheme.primary,
      ),
    );
  }
}

@visibleForTesting
Future<int?> _calculateSeedColor(String imagePath) async {
  try {
    final file = File(imagePath);
    final imageBytes = await file.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image in isolate');
    }

    final rgbaBytes = image.getBytes(order: img.ChannelOrder.rgba);
    final pixels = <int>[];
    for (var i = 0; i < rgbaBytes.length; i += 4) {
      final r = rgbaBytes[i];
      final g = rgbaBytes[i + 1];
      final b = rgbaBytes[i + 2];
      final a = rgbaBytes[i + 3];
      pixels.add((a << 24) | (r << 16) | (g << 8) | b);
    }

    final quantizer = QuantizerCelebi();
    final quantizedColors = await quantizer.quantize(pixels, 128);
    final rankedColors = Score.score(quantizedColors.colorToCount);
    return rankedColors.first;
  } catch (e) {
    return null;
  }
}
