import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:process_run/process_run.dart';

class QSMenuPage extends StatelessWidget {
  const QSMenuPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Raco Modes",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
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
                        context,
                        "Power Save",
                        Icons.battery_saver,
                        "3",
                        Colors.green,
                      ),
                      _buildBtn(
                        context,
                        "Balanced",
                        Icons.balance,
                        "2",
                        Colors.blue,
                      ),
                      _buildBtn(
                        context,
                        "Performance",
                        Icons.speed,
                        "1",
                        Colors.orange,
                      ),
                      _buildBtn(
                        context,
                        "Gaming",
                        Icons.sports_esports,
                        "4",
                        Colors.red,
                      ),
                      _buildBtn(
                        context,
                        "Cooldown",
                        Icons.ac_unit,
                        "5",
                        Colors.cyan,
                      ),
                      _buildBtn(
                        context,
                        "Clear",
                        Icons.clear_all,
                        "6",
                        Colors.grey,
                      ),
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

  Widget _buildBtn(
    BuildContext context,
    String label,
    IconData icon,
    String scriptArg,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Process.run('su', [
          '-c',
          'sh /data/adb/modules/ProjectRaco/Scripts/Raco.sh $scriptArg',
        ]);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
