import 'package:process_run/process_run.dart';
import 'dart:io';

//region Helper Functions
Future<ProcessResult> runRootCommandAndWait(String command) async {
  try {
    return await run('su', ['-c', command]);
  } catch (e) {
    return ProcessResult(0, -1, '', 'Execution failed: $e');
  }
}

Future<void> runRootCommandFireAndForget(String command) async {
  try {
    await Process.start(
      'su',
      ['-c', '$command &'],
      runInShell: true,
      mode: ProcessStartMode.detached,
    );
  } catch (e) {
    // Error starting root command
  }
}

Future<bool> checkRootAccess() async {
  try {
    final result = await runRootCommandAndWait('id');
    return result.exitCode == 0 && result.stdout.toString().contains('uid=0');
  } catch (e) {
    return false;
  }
}
