import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class RacoPage extends StatefulWidget {
  const RacoPage({Key? key}) : super(key: key);

  @override
  State<RacoPage> createState() => _RacoPageState();
}

class _RacoPageState extends State<RacoPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize the video controller
    _controller = VideoPlayerController.asset('assets/RacoL2D.mp4')
      ..initialize()
          .then((_) {
            // Ensure the video loops and plays automatically
            _controller.setLooping(true);
            _controller.setVolume(
              0.0,
            ); // Mute by default for L2D background feel
            _controller.play();
            setState(() {
              _isInitialized = true;
            });
          })
          .catchError((error) {
            print("Video Error: $error");
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen orientation to adjust layout if needed
    // For this design, we strictly follow the Row layout (Left Video, Right Text)

    return Scaffold(
      appBar: AppBar(
        title: const Text("Raco L2D Page"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- LEFT SIDE: VIDEO ---
                Expanded(
                  flex: 5, // Takes up 5/12 of the space
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          Colors.blue[100], // Light blue background like mock
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller.value.size.width,
                              height: _controller.value.size.height,
                              child: VideoPlayer(_controller),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),

                const SizedBox(width: 16),

                // --- RIGHT SIDE: TEXT ---
                Expanded(
                  flex: 7, // Takes up 7/12 of the space
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[300]?.withOpacity(
                        0.3,
                      ), // Darker blue like mock
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _InfoRow(label: "Full Name", value: "Zefanya Raco"),
                          _InfoRow(label: "Name Call", value: "Raco / Zefa"),
                          _InfoRow(
                            label: "Age",
                            value: "[Same as Kanagawa Yamada]",
                          ),
                          _InfoRow(label: "Nationality", value: "Japanese"),
                          _InfoRow(label: "Height", value: "178 cm"),
                          _InfoRow(label: "Weight", value: "79 kg"),
                          _InfoRow(label: "Gender", value: "Female [Straight]"),
                          _InfoRow(label: "Race", value: "Cat girl"),
                          _InfoRow(
                            label: "Work as",
                            value: "Yamada's Neko Maid",
                          ),
                          _InfoRow(label: "Hobby", value: "Chasing Red Laser"),
                          _InfoRow(
                            label: "Favorite Food",
                            value: "Warm Fish, Hot tea",
                          ),
                          _InfoRow(label: "Hate", value: "Karbit, LGBTQ+"),
                          _InfoRow(
                            label: "Origin",
                            value: "Yamada's childhood friend",
                          ),
                          _InfoRow(
                            label: "Affiliation",
                            value: "KanaDev_IS Hidden Member",
                          ),
                          _InfoRow(label: "Personality", value: "Kuudere"),
                          _InfoRow(label: "Birthday", value: "4 September"),
                          _InfoRow(label: "Religion", value: "Christian"),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge,
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
