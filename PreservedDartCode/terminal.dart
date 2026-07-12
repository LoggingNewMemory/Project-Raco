import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';

/// Cool hacker startup screen before terminal launches
class HackerStartupScreen extends StatefulWidget {
  const HackerStartupScreen({Key? key}) : super(key: key);

  @override
  State<HackerStartupScreen> createState() => _HackerStartupScreenState();
}

class _HackerStartupScreenState extends State<HackerStartupScreen>
    with SingleTickerProviderStateMixin {
  // Updated boot messages
  final List<String> _bootMessages = [
    'INITIALIZING PROJECT RACO TERM...',
    'MOUNTING USER AS SUPERUSER...',
    'DETECTING KERNEL IS...',
    'MENELPON ADMIN...',
    'LOGIN IN WITH USER CREDS.',
    'ACCESS GRANTED. WELCOME, USER.',
    'LOADING PROJECT RACO TERMINAL...',
  ];

  int _currentMessageIndex = 0;
  late AnimationController _glitchController;

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _startBootSequence();
  }

  @override
  void dispose() {
    _glitchController.dispose();
    super.dispose();
  }

  void _startBootSequence() {
    Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentMessageIndex < _bootMessages.length) {
          _currentMessageIndex++;
        } else {
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TerminalPage()),
              );
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, primaryColor.withOpacity(0.1), Colors.black],
          ),
        ),
        child: Stack(
          children: [
            // Scanline effect
            AnimatedBuilder(
              animation: _glitchController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.05,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          primaryColor.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: [
                          _glitchController.value - 0.1,
                          _glitchController.value,
                          _glitchController.value + 0.1,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.terminal, size: 80, color: primaryColor),
                    const SizedBox(height: 32),
                    Text(
                      '[ PROJECT RACO ]',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TERMINAL ACCESS',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryColor.withOpacity(0.7),
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _currentMessageIndex,
                        itemBuilder: (context, index) {
                          final isLast = index == _currentMessageIndex - 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  '> ',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _bootMessages[index],
                                    style: TextStyle(
                                      color: isLast
                                          ? primaryColor
                                          : primaryColor.withOpacity(0.5),
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isLast)
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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

// The main terminal interface page (Original Implementation).
class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Widget> _outputLines = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Add a welcome message when the terminal opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _outputLines.add(
          Text(
            'Project Raco Terminal [1.0]\n(c) 2025 Kanagawa Yamada. All rights reserved.\nType "help" for available commands.',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        );
      });
      // Ensure the input field is focused.
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Executes the entered command using root privileges.
  Future<void> _runCommand(String command) async {
    if (command.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      // Display the entered command in the output.
      _outputLines.add(_buildPrompt(command));
    });
    _inputController.clear();
    _scrollToBottom();

    final commandTrimmed = command.trim().toLowerCase();

    // Handle internal commands.
    if (commandTrimmed == 'clear') {
      setState(() {
        _outputLines.clear();
        _isProcessing = false;
      });
      return;
    }

    if (commandTrimmed == 'exit') {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (commandTrimmed == 'help') {
      setState(() {
        const helpText = '''
Project Raco Terminal Help:

Internal Commands:
  help      - Show this list of available commands.
  clear     - Clear all output from the terminal screen.
  exit      - Close the terminal session.

System Commands:
  Any other command will be executed as a system shell command
  with root privileges (e.g., 'ls -l', 'whoami', 'pwd').
''';
        _outputLines.add(_buildOutput(helpText.trim()));
        _isProcessing = false;
      });
      _scrollToBottom();
      FocusScope.of(context).requestFocus(_focusNode);
      return;
    }

    // Execute the command as a root shell process.
    try {
      final result = await Process.run('su', ['-c', command]);
      final output = (result.stdout as String).trim();
      final error = (result.stderr as String).trim();

      if (mounted) {
        setState(() {
          if (output.isNotEmpty) {
            _outputLines.add(_buildOutput(output));
          }
          if (error.isNotEmpty) {
            _outputLines.add(_buildError(error));
          }
          if (output.isEmpty && error.isEmpty) {
            // Add a blank line for commands with no output.
            _outputLines.add(const SizedBox(height: 12)); // Match font size
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _outputLines.add(_buildError('ERROR: Subroutine failed. $e'));
        });
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      _scrollToBottom();
      // Re-focus the input field after command execution.
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper methods to build styled text widgets.
  Widget _buildPrompt(String command) {
    final colorScheme = Theme.of(context).colorScheme;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: colorScheme.onSurface,
        ),
        children: [
          TextSpan(
            text: 'netrunner@localhost:~> ',
            style: TextStyle(
              color: colorScheme.primary,
              shadows: [Shadow(blurRadius: 3.0, color: colorScheme.primary)],
            ),
          ),
          TextSpan(
            text: command,
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput(String text) {
    return SelectableText(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
    );
  }

  Widget _buildError(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return SelectableText(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        color: colorScheme.error,
        fontSize: 12,
        shadows: [Shadow(blurRadius: 3.0, color: colorScheme.error)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputStyle = TextStyle(
      fontFamily: 'monospace',
      color: colorScheme.onSurface,
      fontSize: 12,
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PROJECT RACO SHELL',
          style: TextStyle(
            fontFamily: 'monospace',
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: colorScheme.primary.withOpacity(0.5),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(_focusNode),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Scrollable output area.
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _outputLines.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: _outputLines[index],
                      );
                    },
                  ),
                ),
                // Input field area.
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Text(
                        'netrunner@localhost:~>',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: inputStyle,
                          cursorColor: colorScheme.primary,
                          onSubmitted: _runCommand,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
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
