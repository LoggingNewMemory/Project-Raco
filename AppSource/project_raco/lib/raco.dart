import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// --- GLOBAL VIDEO CACHE ---
// Defined globally so it persists across the app lifecycle
late VideoPlayerController _cachedController;
Future<void>? _initFuture;
bool _isCacheInitialized = false;

// Call this from main.dart
void initRacoVideoCache() {
  if (_isCacheInitialized) return; // Prevent double init

  _cachedController = VideoPlayerController.asset('assets/RacoL2D.mp4');
  _initFuture = _cachedController
      .initialize()
      .then((_) {
        _cachedController.setLooping(true);
        _cachedController.setVolume(0.0);
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

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  void _setupVideo() {
    // Ensure cache is started if main.dart missed it (fallback)
    if (!_isCacheInitialized && _initFuture == null) {
      initRacoVideoCache();
    }

    // If already initialized, play immediately
    if (_cachedController.value.isInitialized) {
      _playVideo();
    } else {
      // Otherwise wait for the existing future
      _initFuture?.then((_) {
        if (mounted) _playVideo();
      });
    }
  }

  void _playVideo() {
    _cachedController.play();
    setState(() {
      _isReady = true;
    });
  }

  @override
  void dispose() {
    // CRITICAL: Do NOT dispose the controller.
    // Just pause it so it's ready for next time instantly.
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
            // --- TOP SECTION: VIDEO ---
            Container(
              width: double.infinity,
              color: Colors.black,
              child: _isReady
                  ? AspectRatio(
                      aspectRatio: _cachedController.value.aspectRatio,
                      child: VideoPlayer(_cachedController),
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
                    const _InfoRow(label: "Height", value: "178 cm"),
                    const _InfoRow(label: "Weight", value: "79 kg"),
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
