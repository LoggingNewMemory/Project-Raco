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
  String get module_not_installed => 'Not Installed';

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
      'Thank you for the great people who helped improve Project Raco:';

  @override
  String get about_quote =>
      '\"Great Collaboration Lead to Great Innovation\"\n~ Kanagawa Yamada (Main Dev)';

  @override
  String get about_note =>
      'Project Raco Is Always Free, Open Source, and Open For Improvement';

  @override
  String get credits_11 => 'And All Testers That I Can\'t Mentioned One by One';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get utilities => 'Utilities';

  @override
  String get utilities_title => 'Utilities';

  @override
  String get search_utilities => 'Search Utilities';

  @override
  String get core_tweaks_title => 'Core Tweaks';

  @override
  String get automation_title => 'Automation';

  @override
  String get system_title => 'System';

  @override
  String get appearance_title => 'Appearance';

  @override
  String get fix_and_tweak_title => 'Fix and Tweak';

  @override
  String get device_mitigation_title => 'Device Mitigation';

  @override
  String get device_mitigation_description =>
      'Turn on if you experience screen freeze';

  @override
  String get lite_mode_title => 'LITE Mode';

  @override
  String get lite_mode_description =>
      'Light Version of Performance, uses Less Battery but Less Performance Boost';

  @override
  String get life_mode_title => 'LIFE Mode';

  @override
  String get life_mode_description => 'Half CPU Power on Balance';

  @override
  String get endfield_engine => 'Endfield Engine';

  @override
  String get endfield_engine_description =>
      'Switch to Performance When Entering Game, Switch to Power Save When Screen Off';

  @override
  String get downscale_resolution => 'Downscale Resolution';

  @override
  String selected_resolution(String resolution) {
    return 'Selected: $resolution';
  }

  @override
  String get reset_resolution => 'Reset to Original';

  @override
  String get endfield_engine_toggle_title => 'Enable Endfield Engine';

  @override
  String get endfield_engine_start_on_boot => 'Start on Boot';

  @override
  String get edit_game_txt_title => 'Edit game.txt';

  @override
  String get sync_changes => 'Sync Changes';

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
  String get applying_new_color => 'Applying New Color, Please Wait...';

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
  String get mode_endfield_engine => 'Endfield';

  @override
  String get please_disable_endfield_engine_first =>
      'Please Disable Endfield Engine First';

  @override
  String get background_settings_title => 'Background Settings';

  @override
  String get background_settings_description =>
      'Customize the app\'s background image, opacity, and blur effect.';

  @override
  String get opacity_slider_label => 'Background Opacity';

  @override
  String get blur_slider_label => 'Background Blur';

  @override
  String get banner_settings_title => 'Banner Settings';

  @override
  String get banner_settings_description =>
      'Customize the main screen\'s banner image (16:9 aspect ratio).';

  @override
  String get device_name => 'Device name';

  @override
  String get processor => 'Processor';

  @override
  String get ram => 'RAM';

  @override
  String get phone_storage => 'Phone storage';

  @override
  String get battery_capacity => 'Battery capacity';

  @override
  String get custom_governor_title => 'Custom Governor';

  @override
  String get custom_governor_description =>
      'Set custom CPU governor, This will set the governor in balanced mode';

  @override
  String get loading_governors => 'Loading governors...';

  @override
  String get no_governor_selected => 'None';

  @override
  String get anya_thermal_title => 'Anya Melfissa Disable Thermal';

  @override
  String get anya_thermal_description =>
      'Disable Thermal on Performance and Gaming, Enable Thermal on Powersave, Balanced, Cool Down.';

  @override
  String get anya_thermal_toggle_title => 'Enable Anya Thermal Flowstate';

  @override
  String get system_actions_title => 'System Actions';

  @override
  String get fstrim_title => 'Fstrim';

  @override
  String get fstrim_description => 'Trim Android partitions.';

  @override
  String get clear_cache_title => 'Clear Cache';

  @override
  String get better_powersave_title => 'Better Powersave';

  @override
  String get better_powersave_description =>
      'Cap the CPU Freq to Half instead of Minimum Freq (Powersave Mode Only)';

  @override
  String get carlotta_cpu_title => 'Carlotta CPU';

  @override
  String get carlotta_cpu_description =>
      'Modify Target CPU (WARN: May Crash Your Device)';

  @override
  String build_version_title(String buildName) {
    return 'Project Raco: $buildName Build';
  }

  @override
  String build_by_title(String builderName) {
    return 'Build By: $builderName';
  }

  @override
  String get screen_modifier_title => 'Screen Modifier';

  @override
  String get screen_modifier_description =>
      'Adjust the screen color matrix and saturation for a custom display experience.';

  @override
  String get screen_modifier_red => 'Red';

  @override
  String get screen_modifier_green => 'Green';

  @override
  String get screen_modifier_blue => 'Blue';

  @override
  String get screen_modifier_saturation => 'Saturation';

  @override
  String get screen_modifier_reset => 'Reset to Defaults';

  @override
  String get screen_modifier_apply_on_boot => 'Apply on Boot';

  @override
  String get graphics_driver_title => 'System Graphics Driver';

  @override
  String get graphics_driver_description =>
      'Modify the Graphics Driver of Your Devices';

  @override
  String get graphics_driver_default => 'Default';

  @override
  String get graphics_driver_game => 'Game Driver';

  @override
  String get graphics_driver_developer => 'Developer Driver';

  @override
  String get current_driver => 'Current:';

  @override
  String get legacy_notif_title => 'Legacy Notification';

  @override
  String get legacy_notif_description =>
      'Use Legacy Notification In Case Notification Doesn\'t Show In Some ROMs';

  @override
  String get slingshot_title => 'Raco Slingshot';

  @override
  String get slingshot_description =>
      'Preload your app files before launching the app, this may speed up the loading time and improve performance';

  @override
  String get angle_title => 'Launch using ANGLE Graphics';

  @override
  String get angle_not_supported =>
      'ANGLE Graphics is not supported on this device';

  @override
  String get skia_title => 'Use SkiaVK as default Skia backend';

  @override
  String get preload_mode => 'Preload Mode';

  @override
  String get start_preload => 'Start Slingshot';

  @override
  String get swipe_again_to_cancel => 'Swipe Right Again To Cancel';

  @override
  String get execution_cancelled => 'Execution Cancelled';

  @override
  String get sandevistan_duration_title => 'Sandevistan Duration';

  @override
  String get sandevistan_duration_description =>
      'Modify the Sandevistan Duration (Seconds)';

  @override
  String get sandevistan_duration_hint => 'Enter duration in seconds';

  @override
  String get sandev_egg_useless =>
      'NAH MAN! IT\'S USELESS! JUST DISABLE IT DAWG';

  @override
  String get sandev_egg_original =>
      'Bro is original, either have no idea or too scared to modify';

  @override
  String get sandev_egg_better =>
      'Alright Choom that\'s better, go more higher if you want';

  @override
  String get sandev_egg_david =>
      'What dawg? Try to be David Martinez? Ain\'t gonna work';

  @override
  String get sandev_egg_smasher =>
      'NAH BRO GONNA SOLO ADAM SMASHER AT THIS POINT!';

  @override
  String get endfield_powersave_screen_off_title => 'Powersave When Screen Off';

  @override
  String get endfield_normal_interval_title => 'Normal Interval';

  @override
  String get endfield_screen_off_interval_title => 'Screen Off Interval';

  @override
  String get endfield_interval_hint => 'Enter seconds (min 2)';

  @override
  String get plugins_title => 'Plugins';

  @override
  String get plugins_description =>
      'Manage and install external modules for Project Raco';

  @override
  String get install_plugin => 'Install Plugin';

  @override
  String get no_plugins_installed => 'No plugins installed';

  @override
  String get plugin_installer => 'Plugin Installer';

  @override
  String get installing_module => 'Installing Raco Plugin';

  @override
  String get install_question => 'Do you want to install this plugin?';

  @override
  String get delete_plugin_title => 'Delete Plugin';

  @override
  String delete_plugin_confirm(String pluginName) {
    return 'Are you sure you want to delete $pluginName?';
  }

  @override
  String get plugin_verification_failed =>
      'Verification Failed: RacoPlugin=1 not found in prop.';

  @override
  String get plugin_script_error => 'Install Script Error.';

  @override
  String get logs_saved => 'Logs saved to Downloads.';

  @override
  String get plugin_installed_success => 'Plugin installed successfully.';

  @override
  String get plugin_uninstall_success => 'Plugin uninstalled.';

  @override
  String get plugin_manually_executed => 'Plugin Manually Executed.';

  @override
  String get plugin_run => 'Run';

  @override
  String get plugin_boot => 'Boot';

  @override
  String get slingshot_no_app_selected => 'No app selected';

  @override
  String slingshot_executing(String package) {
    return 'Slingshoting $package...';
  }

  @override
  String get slingshot_complete => 'Slingshot Complete';

  @override
  String get slingshot_search_hint => 'Search apps...';

  @override
  String get slingshot_reload_tooltip => 'Reload App List';

  @override
  String get slingshot_no_apps_found => 'No apps found';

  @override
  String get slingshot_mode_normal => 'Normal (fadvise hint)';

  @override
  String get slingshot_mode_deep => 'Deep (fadvise + dlopen)';

  @override
  String get slingshot_mode_extreme => 'Extreme (mmap + MAP_POPULATE)';

  @override
  String get slingshot_mode_recursive => 'Recursive (looped deep check)';

  @override
  String get silent_mode_title => 'Silent Mode';

  @override
  String get silent_mode_description =>
      'Disables Notification, Raco Will Apply Tweaks Without Notifying';

  @override
  String get slingshot_graphics_warning =>
      'Some games might broken, Some might improve performance, Some might don\'t even Launch. But don\'t be afraid to try it first!';

  @override
  String get playboost_title => 'RiProG Playboost';

  @override
  String added_to_gamelist(String package) {
    return 'Added $package to game list';
  }

  @override
  String removed_from_gamelist(String package) {
    return 'Removed $package from game list';
  }

  @override
  String get extra_settings_title => 'Extra Settings';

  @override
  String get extra_settings_description => 'Anya, Kobo, Zetamin, Sandevistan';

  @override
  String get anya_installer_title => 'Anya Thermal';

  @override
  String get anya_installer_desc => 'Disable / Enable Thermal | Anya Flowstate';

  @override
  String get kobo_title => 'Kobo Fast Charge';

  @override
  String get kobo_desc => 'Fast Charging Add On';

  @override
  String get zetamin_title => 'Zetamin';

  @override
  String get zetamin_desc => 'All in One Display Tweaks';

  @override
  String get sandev_boot_title => 'Sandevistan Boot';

  @override
  String get sandev_boot_desc => 'An Attempt to Make Boot Faster';
}
