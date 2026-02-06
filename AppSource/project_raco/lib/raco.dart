import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

// --- GLOBAL VIDEO CACHE ---
late VideoPlayerController _cachedController;
Future<void>? _initFuture;
bool _isCacheInitialized = false;

void initRacoVideoCache() {
  if (_isCacheInitialized) return;

  // FIX: Added VideoPlayerOptions(mixWithOthers: true)
  // This prevents the silent video from stealing audio focus and stopping the BGM.
  _cachedController = VideoPlayerController.asset(
    'assets/RacoL2D.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );

  _initFuture = _cachedController
      .initialize()
      .then((_) {
        _cachedController.setLooping(true);
        _cachedController.setVolume(0.0); // Ensure silence
        _isCacheInitialized = true;
      })
      .catchError((e) {
        debugPrint("Raco Video Cache Failed: $e");
      });
}
// --------------------------

class RacoPage extends StatefulWidget {
  const RacoPage({Key? key}) : super(key: key);

  @override
  State<RacoPage> createState() => _RacoPageState();
}

class _RacoPageState extends State<RacoPage> {
  bool _isReady = false;
  int _dialogueIndex = 0;

  final List<String> _dialogues = [
    "Welcome. Please scroll down to read more.",
    "I am Zefanya... though most call me Raco.",
    "Yamada-sama requested I greet you.",
    "Don't stare too much... it is embarrassing.",
    "I was just tidying up the pixels here.",
    "My ears? Yes, they are real. Please do not touch.",
    "I hope you are not carrying any red laser pointers.",
    "I cannot responsible for my actions if I see a red dot.",
    "Yamada-sama is likely coding right now.",
    "I have to ensure he remembers to eat and sleep.",
    "Being a childhood friend is... a lot of work.",
    "My tail moves on its own. Pay it no mind.",
    "Do you require refreshments? I can brew some tea.",
    "I prefer warm fish over expensive dinners.",
    "The data below is accurate. I verified it myself.",
    "I am not cold... I am just composed.",
    "...",
    "You are quite patient to stay here with me.",
    "I do not dislike your company, I suppose.",
    "Feel free to check the Telegram group later.",
    "I will remain here. Please, proceed.",
  ];

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  void _setupVideo() {
    if (!_isCacheInitialized && _initFuture == null) {
      initRacoVideoCache();
    }

    if (_cachedController.value.isInitialized) {
      _playVideo();
    } else {
      _initFuture?.then((_) {
        if (mounted) _playVideo();
      });
    }
  }

  void _playVideo() {
    // Ensure volume is 0 before playing to be double safe
    _cachedController.setVolume(0.0);
    _cachedController.play();
    setState(() {
      _isReady = true;
    });
  }

  void _nextDialogue() {
    setState(() {
      _dialogueIndex = (_dialogueIndex + 1) % _dialogues.length;
    });
  }

  @override
  void dispose() {
    _cachedController.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const BackButton(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- TOP SECTION: VIDEO WITH VN OVERLAY ---
            Container(
              width: double.infinity,
              color: Colors.black,
              child: _isReady
                  ? Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AspectRatio(
                          aspectRatio: _cachedController.value.aspectRatio,
                          child: VideoPlayer(_cachedController),
                        ),
                        // VN Overlay
                        GestureDetector(
                          onTap: _nextDialogue,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                            // Reduced vertical padding to reduce box height
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Raco",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                // Reduced spacing
                                const SizedBox(height: 4),
                                // --- TypewriterText ---
                                TypewriterText(
                                  text: _dialogues[_dialogueIndex],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                                // -------------------------------------
                                // Reduced spacing
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    "▼ Tap to read",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      height: 400,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
            ),

            // --- BOTTOM SECTION: INFO ---
            Transform.translate(
              offset: const Offset(0, -25),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Decoration
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name Header
                    Text(
                      "Zefanya Raco",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    Text(
                      "[ゼファニャ・ラチョ]",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.9),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Yamada's Neko Maid",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),

                    const Divider(height: 30),

                    // Info Data
                    const _InfoRow(label: "Name Call", value: "Raco / Zefa"),
                    const _InfoRow(
                      label: "Age",
                      value: "[Same as Kanagawa Yamada]",
                    ),
                    const _InfoRow(label: "Nationality", value: "Japanese"),
                    const _InfoRow(label: "Height", value: "180 cm"),
                    const _InfoRow(label: "Weight", value: "80 kg"),
                    const _InfoRow(label: "Gender", value: "Female [Straight]"),
                    const _InfoRow(label: "Race", value: "Cat girl"),
                    const _InfoRow(label: "Hobby", value: "Chasing Red Laser"),
                    const _InfoRow(
                      label: "Favorite Food",
                      value: "Warm Fish, Hot tea",
                    ),
                    const _InfoRow(label: "Hate", value: "Karbit, LGBTQ+"),
                    const _InfoRow(
                      label: "Origin",
                      value: "Yamada's childhood friend",
                    ),
                    const _InfoRow(
                      label: "Affiliation",
                      value: "KanaDev_IS Hidden Member",
                    ),
                    const _InfoRow(label: "Personality", value: "Kuudere"),
                    const _InfoRow(label: "Birthday", value: "4 September"),
                    const _InfoRow(label: "Religion", value: "Christian"),

                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final Uri url = Uri.parse('https://t.me/ProjectRaco');
                          if (!await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          )) {
                            debugPrint("Could not launch $url");
                          }
                        },
                        child: Text(
                          "Official Project Raco Telegram Group",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TypewriterText Widget ---
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

    if (_displayedText.isNotEmpty && _displayedText != textToType) {
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
