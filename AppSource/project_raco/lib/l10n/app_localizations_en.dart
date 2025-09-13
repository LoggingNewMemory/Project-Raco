// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Project Raco';

  @override
  String get by => 'By: Kanagawa Yamada';

  @override
  String get root_access => 'Root Access:';

  @override
  String get module_installed => 'Module Installed:';

  @override
  String get module_version => 'Module Version:';

  @override
  String get current_mode => 'Current Mode:';

  @override
  String get select_language => 'Select Language:';

  @override
  String get power_save_desc => 'Prioritizing Battery Over Performance';

  @override
  String get balanced_desc => 'Balance Battery and Performance';

  @override
  String get performance_desc => 'Prioritizing Performance Over Battery';

  @override
  String get clear_desc => 'Clear RAM By Killing All Apps';

  @override
  String get cooldown_desc =>
      'Cool Down Your Device\n(Let It Rest for 2 Minutes)';

  @override
  String get gaming_desc => 'Set to Performance and Kill All Apps';

  @override
  String get power_save => 'Power Save';

  @override
  String get balanced => 'Balanced';

  @override
  String get performance => 'Performance';

  @override
  String get clear => 'Clear';

  @override
  String get cooldown => 'Cool Down';

  @override
  String get gaming_pro => 'Gaming Pro';

  @override
  String get about_title =>
      'Thank you for the great people who helped improve EnCorinVest:';

  @override
  String get about_quote =>
      '\"Great Collaboration Lead to Great Innovation\"\n~ Kanagawa Yamada (Main Dev)';

  @override
  String get about_note =>
      'EnCorinVest Is Always Free, Open Source, and Open For Improvement';

  @override
  String get credits_1 => 'Rem01 Gaming';

  @override
  String get credits_2 => 'VelocityFox22';

  @override
  String get credits_3 => 'MiAzami';

  @override
  String get credits_4 => 'Kazuyoo';

  @override
  String get credits_5 => 'RiProG';

  @override
  String get credits_6 => 'Lieudahbelajar';

  @override
  String get credits_7 => 'KanaDev_IS';

  @override
  String get credits_8 => 'And All Testers That I Can\'t Mentioned One by One';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get device => 'Device:';

  @override
  String get cpu => 'CPU:';

  @override
  String get os => 'OS:';

  @override
  String get utilities => 'Utilities';

  @override
  String get utilities_title => 'Utilities';

  @override
  String get device_mitigation_title => 'Device Mitigation';

  @override
  String get device_mitigation_description =>
      'Turn on if you experience screen freeze';

  @override
  String get lite_mode_title => 'LITE Mode';

  @override
  String get lite_mode_description => 'Using Lite mode (Requested by Fans)';

  @override
  String get hamada_ai => 'HAMADA AI';

  @override
  String get hamada_ai_description =>
      'Automatically Switch to Performance When Entering Game';

  @override
  String get downscale_resolution => 'Downscale Resolution';

  @override
  String selected_resolution(String resolution) {
    return 'Selected: $resolution';
  }

  @override
  String get reset_resolution => 'Reset to Original';

  @override
  String get hamada_ai_toggle_title => 'Enable HAMADA AI';

  @override
  String get hamada_ai_start_on_boot => 'Start on Boot';

  @override
  String get edit_game_txt_title => 'Edit game.txt';

  @override
  String get save_button => 'Save';

  @override
  String get executing_command => 'Executing...';

  @override
  String get command_executed => 'Command executed.';

  @override
  String get command_failed => 'Command failed.';

  @override
  String get saving_file => 'Saving...';

  @override
  String get file_saved => 'File saved.';

  @override
  String get file_save_failed => 'Failed to save file.';

  @override
  String get reading_file => 'Reading file...';

  @override
  String get file_read_failed => 'Failed to read file.';

  @override
  String get writing_service_file => 'Updating boot script...';

  @override
  String get service_file_updated => 'Boot script updated.';

  @override
  String get service_file_update_failed => 'Failed to update boot script.';

  @override
  String get error_no_root => 'Root access required.';

  @override
  String get error_file_not_found => 'File not found.';

  @override
  String get game_txt_hint => 'Enter game package names, one per line...';

  @override
  String get resolution_unavailable_message =>
      'Resolution control is not available on this device.';

  @override
  String get applying_changes => 'Applying changes...';

  @override
  String get dnd_title => 'DND Switch';

  @override
  String get dnd_description => 'Automatically Turn DND on / off';

  @override
  String get dnd_toggle_title => 'Enable DND Auto Switch';

  @override
  String get bypass_charging_title => 'Bypass Charging';

  @override
  String get bypass_charging_description =>
      'Enable Bypass Charging While in Performance & Gaming Pro on Supported Device';

  @override
  String get bypass_charging_toggle => 'Enable Bypass Charging';

  @override
  String get bypass_charging_unsupported =>
      'Bypass charging is not supported on your device';

  @override
  String get bypass_charging_supported =>
      'Bypass charging is supported on your device';

  @override
  String get mode_status_label => 'Mode:';

  @override
  String get mode_manual => 'Manual';

  @override
  String get mode_hamada_ai => 'HamadaAI';

  @override
  String get please_disable_hamada_ai_first => 'Please Disable HamadaAI First';

  @override
  String get background_settings_title => 'Background Settings';

  @override
  String get background_settings_description =>
      'Customize the app\'s background image and opacity.';

  @override
  String get opacity_slider_label => 'Background Opacity';

  @override
  String get select_theme => 'Select Theme:';

  @override
  String get theme_classic => 'Classic';

  @override
  String get theme_modern => 'Modern';

  @override
  String get custom_governor_title => 'Custom Governor';

  @override
  String get custom_governor_description =>
      'Set custom CPU governor, This will set the governor in balanced mode';

  @override
  String get loading_governors => 'Loading governors...';

  @override
  String get no_governor_selected => 'None';
}
