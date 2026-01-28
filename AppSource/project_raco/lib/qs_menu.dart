import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:process_run/process_run.dart';

class QSMenuPage extends StatefulWidget {
  const QSMenuPage({Key? key}) : super(key: key);

  @override
  State<QSMenuPage> createState() => _QSMenuPageState();
}

class _QSMenuPageState extends State<QSMenuPage> {
  // Track which button is processing
  String? _loadingArg;
  // Track which button finished successfully
  String? _successArg;

  Future<void> _activateMode(String scriptArg) async {
    // 1. Start Loading
    setState(() {
      _loadingArg = scriptArg;
      // We don't clear _successArg here immediately so the UI doesn't jump,
      // or we can clear it if we want only one active at a time.
      // Let's clear it to indicate a new operation started.
      _successArg = null;
    });

    try {
      // 2. Execute Script
      // We add "> /dev/null 2>&1" to ensure Dart doesn't hang waiting for
      // background processes (like the notification daemon) to close their pipes.
      await Process.run('su', [
        '-c',
        'sh /data/adb/modules/ProjectRaco/Scripts/Raco.sh $scriptArg > /dev/null 2>&1',
      ]);

      // 3. Set Success State (Trigger Animation)
      if (mounted) {
        setState(() {
          _loadingArg = null;
          _successArg = scriptArg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingArg = null;
        });
      }
      print("Error executing mode: $e");
    }

    // 4. Menu stays open (No navigator pop)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Tap -> Close Menu
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              SystemNavigator.pop(); // Ensure transparent activity closes
            },
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          // Menu Card
          Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Raco Modes",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildBtn(
                        "Power Save",
                        Icons.battery_saver,
                        "3",
                        Colors.green,
                      ),
                      _buildBtn("Balanced", Icons.balance, "2", Colors.blue),
                      _buildBtn("Performance", Icons.speed, "1", Colors.orange),
                      _buildBtn(
                        "Gaming",
                        Icons.sports_esports,
                        "4",
                        Colors.red,
                      ),
                      _buildBtn("Cooldown", Icons.ac_unit, "5", Colors.cyan),
                      _buildBtn("Clear", Icons.clear_all, "6", Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, IconData icon, String scriptArg, Color color) {
    final bool isLoading = _loadingArg == scriptArg;
    final bool isSuccess = _successArg == scriptArg;
    // Disable clicks on ALL buttons while ONE is loading
    final bool isBusy = _loadingArg != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : () => _activateMode(scriptArg),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: (isSuccess || isLoading)
                ? color.withOpacity(0.2)
                : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isSuccess || isLoading) ? color : color.withOpacity(0.3),
              width: (isSuccess || isLoading) ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 32,
                width: 32,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: isLoading
                      ? CircularProgressIndicator(
                          key: const ValueKey("spinner"),
                          color: color,
                          strokeWidth: 3,
                        )
                      : isSuccess
                      ? Icon(
                          Icons.check_circle_rounded, // The thick check icon
                          key: const ValueKey("check"),
                          color: color,
                          size: 32,
                        )
                      : Icon(
                          icon,
                          key: const ValueKey("icon"),
                          color: color,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: (isSuccess || isLoading)
                      ? FontWeight.w900
                      : FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
