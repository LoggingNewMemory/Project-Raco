import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('id'),
    Locale('ja'),
    Locale('ru'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Project Raco'**
  String get app_title;

  /// No description provided for @by.
  ///
  /// In en, this message translates to:
  /// **'By: Kanagawa Yamada'**
  String get by;

  /// No description provided for @root_access.
  ///
  /// In en, this message translates to:
  /// **'Root Access:'**
  String get root_access;

  /// No description provided for @module_installed.
  ///
  /// In en, this message translates to:
  /// **'Module Installed:'**
  String get module_installed;

  /// No description provided for @module_version.
  ///
  /// In en, this message translates to:
  /// **'Module Version:'**
  String get module_version;

  /// No description provided for @module_not_installed.
  ///
  /// In en, this message translates to:
  /// **'Not Installed'**
  String get module_not_installed;

  /// No description provided for @current_mode.
  ///
  /// In en, this message translates to:
  /// **'Current Mode:'**
  String get current_mode;

  /// No description provided for @select_language.
  ///
  /// In en, this message translates to:
  /// **'Select Language:'**
  String get select_language;

  /// No description provided for @power_save_desc.
  ///
  /// In en, this message translates to:
  /// **'Prioritizing Battery Over Performance'**
  String get power_save_desc;

  /// No description provided for @balanced_desc.
  ///
  /// In en, this message translates to:
  /// **'Balance Battery and Performance'**
  String get balanced_desc;

  /// No description provided for @performance_desc.
  ///
  /// In en, this message translates to:
  /// **'Prioritizing Performance Over Battery'**
  String get performance_desc;

  /// No description provided for @clear_desc.
  ///
  /// In en, this message translates to:
  /// **'Clear RAM By Killing All Apps'**
  String get clear_desc;

  /// No description provided for @cooldown_desc.
  ///
  /// In en, this message translates to:
  /// **'Cool Down Your Device\n(Let It Rest for 2 Minutes)'**
  String get cooldown_desc;

  /// No description provided for @gaming_desc.
  ///
  /// In en, this message translates to:
  /// **'Set to Performance and Kill All Apps'**
  String get gaming_desc;

  /// No description provided for @power_save.
  ///
  /// In en, this message translates to:
  /// **'Power Save'**
  String get power_save;

  /// No description provided for @balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balanced;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @cooldown.
  ///
  /// In en, this message translates to:
  /// **'Cool Down'**
  String get cooldown;

  /// No description provided for @gaming_pro.
  ///
  /// In en, this message translates to:
  /// **'Gaming Pro'**
  String get gaming_pro;

  /// No description provided for @about_title.
  ///
  /// In en, this message translates to:
  /// **'Thank you for the great people who helped improve Project Raco:'**
  String get about_title;

  /// No description provided for @about_quote.
  ///
  /// In en, this message translates to:
  /// **'\"Great Collaboration Lead to Great Innovation\"\n~ Kanagawa Yamada (Main Dev)'**
  String get about_quote;

  /// No description provided for @about_note.
  ///
  /// In en, this message translates to:
  /// **'Project Raco Is Always Free, Open Source, and Open For Improvement'**
  String get about_note;

  /// No description provided for @credits_11.
  ///
  /// In en, this message translates to:
  /// **'And All Testers That I Can\'t Mentioned One by One'**
  String get credits_11;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @utilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilities;

  /// No description provided for @utilities_title.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilities_title;

  /// No description provided for @search_utilities.
  ///
  /// In en, this message translates to:
  /// **'Search Utilities'**
  String get search_utilities;

  /// No description provided for @core_tweaks_title.
  ///
  /// In en, this message translates to:
  /// **'Core Tweaks'**
  String get core_tweaks_title;

  /// No description provided for @automation_title.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get automation_title;

  /// No description provided for @system_title.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system_title;

  /// No description provided for @appearance_title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance_title;

  /// No description provided for @fix_and_tweak_title.
  ///
  /// In en, this message translates to:
  /// **'Fix and Tweak'**
  String get fix_and_tweak_title;

  /// No description provided for @device_mitigation_title.
  ///
  /// In en, this message translates to:
  /// **'Device Mitigation'**
  String get device_mitigation_title;

  /// No description provided for @device_mitigation_description.
  ///
  /// In en, this message translates to:
  /// **'Turn on if you experience screen freeze'**
  String get device_mitigation_description;

  /// No description provided for @lite_mode_title.
  ///
  /// In en, this message translates to:
  /// **'LITE Mode'**
  String get lite_mode_title;

  /// No description provided for @lite_mode_description.
  ///
  /// In en, this message translates to:
  /// **'Light Version of Performance, uses Less Battery but Less Performance Boost'**
  String get lite_mode_description;

  /// No description provided for @life_mode_title.
  ///
  /// In en, this message translates to:
  /// **'LIFE Mode'**
  String get life_mode_title;

  /// No description provided for @life_mode_description.
  ///
  /// In en, this message translates to:
  /// **'Half CPU Power on Balance'**
  String get life_mode_description;

  /// No description provided for @endfield_engine.
  ///
  /// In en, this message translates to:
  /// **'Endfield Engine'**
  String get endfield_engine;

  /// No description provided for @endfield_engine_description.
  ///
  /// In en, this message translates to:
  /// **'Switch to Performance When Entering Game, Switch to Power Save When Screen Off'**
  String get endfield_engine_description;

  /// No description provided for @downscale_resolution.
  ///
  /// In en, this message translates to:
  /// **'Downscale Resolution'**
  String get downscale_resolution;

  /// No description provided for @selected_resolution.
  ///
  /// In en, this message translates to:
  /// **'Selected: {resolution}'**
  String selected_resolution(String resolution);

  /// No description provided for @reset_resolution.
  ///
  /// In en, this message translates to:
  /// **'Reset to Original'**
  String get reset_resolution;

  /// No description provided for @endfield_engine_toggle_title.
  ///
  /// In en, this message translates to:
  /// **'Enable Endfield Engine'**
  String get endfield_engine_toggle_title;

  /// No description provided for @endfield_engine_start_on_boot.
  ///
  /// In en, this message translates to:
  /// **'Start on Boot'**
  String get endfield_engine_start_on_boot;

  /// No description provided for @edit_game_txt_title.
  ///
  /// In en, this message translates to:
  /// **'Edit game.txt'**
  String get edit_game_txt_title;

  /// No description provided for @sync_changes.
  ///
  /// In en, this message translates to:
  /// **'Sync Changes'**
  String get sync_changes;

  /// No description provided for @executing_command.
  ///
  /// In en, this message translates to:
  /// **'Executing...'**
  String get executing_command;

  /// No description provided for @command_executed.
  ///
  /// In en, this message translates to:
  /// **'Command executed.'**
  String get command_executed;

  /// No description provided for @command_failed.
  ///
  /// In en, this message translates to:
  /// **'Command failed.'**
  String get command_failed;

  /// No description provided for @saving_file.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving_file;

  /// No description provided for @file_saved.
  ///
  /// In en, this message translates to:
  /// **'File saved.'**
  String get file_saved;

  /// No description provided for @file_save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save file.'**
  String get file_save_failed;

  /// No description provided for @reading_file.
  ///
  /// In en, this message translates to:
  /// **'Reading file...'**
  String get reading_file;

  /// No description provided for @file_read_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file.'**
  String get file_read_failed;

  /// No description provided for @writing_service_file.
  ///
  /// In en, this message translates to:
  /// **'Updating boot script...'**
  String get writing_service_file;

  /// No description provided for @service_file_updated.
  ///
  /// In en, this message translates to:
  /// **'Boot script updated.'**
  String get service_file_updated;

  /// No description provided for @service_file_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update boot script.'**
  String get service_file_update_failed;

  /// No description provided for @error_no_root.
  ///
  /// In en, this message translates to:
  /// **'Root access required.'**
  String get error_no_root;

  /// No description provided for @error_file_not_found.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get error_file_not_found;

  /// No description provided for @game_txt_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter game package names, one per line...'**
  String get game_txt_hint;

  /// No description provided for @resolution_unavailable_message.
  ///
  /// In en, this message translates to:
  /// **'Resolution control is not available on this device.'**
  String get resolution_unavailable_message;

  /// No description provided for @applying_changes.
  ///
  /// In en, this message translates to:
  /// **'Applying changes...'**
  String get applying_changes;

  /// No description provided for @applying_new_color.
  ///
  /// In en, this message translates to:
  /// **'Applying New Color, Please Wait...'**
  String get applying_new_color;

  /// No description provided for @dnd_title.
  ///
  /// In en, this message translates to:
  /// **'DND Switch'**
  String get dnd_title;

  /// No description provided for @dnd_description.
  ///
  /// In en, this message translates to:
  /// **'Automatically Turn DND on / off'**
  String get dnd_description;

  /// No description provided for @dnd_toggle_title.
  ///
  /// In en, this message translates to:
  /// **'Enable DND Auto Switch'**
  String get dnd_toggle_title;

  /// No description provided for @bypass_charging_title.
  ///
  /// In en, this message translates to:
  /// **'Bypass Charging'**
  String get bypass_charging_title;

  /// No description provided for @bypass_charging_description.
  ///
  /// In en, this message translates to:
  /// **'Enable Bypass Charging While in Performance & Gaming Pro on Supported Device'**
  String get bypass_charging_description;

  /// No description provided for @bypass_charging_toggle.
  ///
  /// In en, this message translates to:
  /// **'Enable Bypass Charging'**
  String get bypass_charging_toggle;

  /// No description provided for @bypass_charging_unsupported.
  ///
  /// In en, this message translates to:
  /// **'Bypass charging is not supported on your device'**
  String get bypass_charging_unsupported;

  /// No description provided for @bypass_charging_supported.
  ///
  /// In en, this message translates to:
  /// **'Bypass charging is supported on your device'**
  String get bypass_charging_supported;

  /// No description provided for @mode_status_label.
  ///
  /// In en, this message translates to:
  /// **'Mode:'**
  String get mode_status_label;

  /// No description provided for @mode_manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get mode_manual;

  /// No description provided for @mode_endfield_engine.
  ///
  /// In en, this message translates to:
  /// **'Endfield'**
  String get mode_endfield_engine;

  /// No description provided for @please_disable_endfield_engine_first.
  ///
  /// In en, this message translates to:
  /// **'Please Disable Endfield Engine First'**
  String get please_disable_endfield_engine_first;

  /// No description provided for @background_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Background Settings'**
  String get background_settings_title;

  /// No description provided for @background_settings_description.
  ///
  /// In en, this message translates to:
  /// **'Customize the app\'s background image, opacity, and blur effect.'**
  String get background_settings_description;

  /// No description provided for @opacity_slider_label.
  ///
  /// In en, this message translates to:
  /// **'Background Opacity'**
  String get opacity_slider_label;

  /// No description provided for @blur_slider_label.
  ///
  /// In en, this message translates to:
  /// **'Background Blur'**
  String get blur_slider_label;

  /// No description provided for @banner_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Banner Settings'**
  String get banner_settings_title;

  /// No description provided for @banner_settings_description.
  ///
  /// In en, this message translates to:
  /// **'Customize the main screen\'s banner image (16:9 aspect ratio).'**
  String get banner_settings_description;

  /// No description provided for @device_name.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get device_name;

  /// No description provided for @processor.
  ///
  /// In en, this message translates to:
  /// **'Processor'**
  String get processor;

  /// No description provided for @ram.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get ram;

  /// No description provided for @phone_storage.
  ///
  /// In en, this message translates to:
  /// **'Phone storage'**
  String get phone_storage;

  /// No description provided for @battery_capacity.
  ///
  /// In en, this message translates to:
  /// **'Battery capacity'**
  String get battery_capacity;

  /// No description provided for @custom_governor_title.
  ///
  /// In en, this message translates to:
  /// **'Custom Governor'**
  String get custom_governor_title;

  /// No description provided for @custom_governor_description.
  ///
  /// In en, this message translates to:
  /// **'Set custom CPU governor, This will set the governor in balanced mode'**
  String get custom_governor_description;

  /// No description provided for @loading_governors.
  ///
  /// In en, this message translates to:
  /// **'Loading governors...'**
  String get loading_governors;

  /// No description provided for @no_governor_selected.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get no_governor_selected;

  /// No description provided for @anya_thermal_title.
  ///
  /// In en, this message translates to:
  /// **'Anya Melfissa Disable Thermal'**
  String get anya_thermal_title;

  /// No description provided for @anya_thermal_description.
  ///
  /// In en, this message translates to:
  /// **'Disable Thermal on Performance and Gaming, Enable Thermal on Powersave, Balanced, Cool Down.'**
  String get anya_thermal_description;

  /// No description provided for @anya_thermal_toggle_title.
  ///
  /// In en, this message translates to:
  /// **'Enable Anya Thermal Flowstate'**
  String get anya_thermal_toggle_title;

  /// No description provided for @system_actions_title.
  ///
  /// In en, this message translates to:
  /// **'System Actions'**
  String get system_actions_title;

  /// No description provided for @fstrim_title.
  ///
  /// In en, this message translates to:
  /// **'Fstrim'**
  String get fstrim_title;

  /// No description provided for @fstrim_description.
  ///
  /// In en, this message translates to:
  /// **'Trim Android partitions.'**
  String get fstrim_description;

  /// No description provided for @clear_cache_title.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clear_cache_title;

  /// No description provided for @better_powersave_title.
  ///
  /// In en, this message translates to:
  /// **'Better Powersave'**
  String get better_powersave_title;

  /// No description provided for @better_powersave_description.
  ///
  /// In en, this message translates to:
  /// **'Cap the CPU Freq to Half instead of Minimum Freq (Powersave Mode Only)'**
  String get better_powersave_description;

  /// No description provided for @carlotta_cpu_title.
  ///
  /// In en, this message translates to:
  /// **'Carlotta CPU'**
  String get carlotta_cpu_title;

  /// No description provided for @carlotta_cpu_description.
  ///
  /// In en, this message translates to:
  /// **'Modify Target CPU (WARN: May Crash Your Device)'**
  String get carlotta_cpu_description;

  /// No description provided for @build_version_title.
  ///
  /// In en, this message translates to:
  /// **'Project Raco: {buildName} Build'**
  String build_version_title(String buildName);

  /// No description provided for @build_by_title.
  ///
  /// In en, this message translates to:
  /// **'Build By: {builderName}'**
  String build_by_title(String builderName);

  /// No description provided for @screen_modifier_title.
  ///
  /// In en, this message translates to:
  /// **'Screen Modifier'**
  String get screen_modifier_title;

  /// No description provided for @screen_modifier_description.
  ///
  /// In en, this message translates to:
  /// **'Adjust the screen color matrix and saturation for a custom display experience.'**
  String get screen_modifier_description;

  /// No description provided for @screen_modifier_red.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get screen_modifier_red;

  /// No description provided for @screen_modifier_green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get screen_modifier_green;

  /// No description provided for @screen_modifier_blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get screen_modifier_blue;

  /// No description provided for @screen_modifier_saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get screen_modifier_saturation;

  /// No description provided for @screen_modifier_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get screen_modifier_reset;

  /// No description provided for @screen_modifier_apply_on_boot.
  ///
  /// In en, this message translates to:
  /// **'Apply on Boot'**
  String get screen_modifier_apply_on_boot;

  /// No description provided for @graphics_driver_title.
  ///
  /// In en, this message translates to:
  /// **'System Graphics Driver'**
  String get graphics_driver_title;

  /// No description provided for @graphics_driver_description.
  ///
  /// In en, this message translates to:
  /// **'Modify the Graphics Driver of Your Devices'**
  String get graphics_driver_description;

  /// No description provided for @graphics_driver_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get graphics_driver_default;

  /// No description provided for @graphics_driver_game.
  ///
  /// In en, this message translates to:
  /// **'Game Driver'**
  String get graphics_driver_game;

  /// No description provided for @graphics_driver_developer.
  ///
  /// In en, this message translates to:
  /// **'Developer Driver'**
  String get graphics_driver_developer;

  /// No description provided for @current_driver.
  ///
  /// In en, this message translates to:
  /// **'Current:'**
  String get current_driver;

  /// No description provided for @legacy_notif_title.
  ///
  /// In en, this message translates to:
  /// **'Legacy Notification'**
  String get legacy_notif_title;

  /// No description provided for @legacy_notif_description.
  ///
  /// In en, this message translates to:
  /// **'Use Legacy Notification In Case Notification Doesn\'t Show In Some ROMs'**
  String get legacy_notif_description;

  /// No description provided for @slingshot_title.
  ///
  /// In en, this message translates to:
  /// **'Raco Slingshot'**
  String get slingshot_title;

  /// No description provided for @slingshot_description.
  ///
  /// In en, this message translates to:
  /// **'Preload your app files before launching the app, this may speed up the loading time and improve performance'**
  String get slingshot_description;

  /// No description provided for @angle_title.
  ///
  /// In en, this message translates to:
  /// **'Launch using ANGLE Graphics'**
  String get angle_title;

  /// No description provided for @angle_not_supported.
  ///
  /// In en, this message translates to:
  /// **'ANGLE Graphics is not supported on this device'**
  String get angle_not_supported;

  /// No description provided for @skia_title.
  ///
  /// In en, this message translates to:
  /// **'Use SkiaVK as default Skia backend'**
  String get skia_title;

  /// No description provided for @preload_mode.
  ///
  /// In en, this message translates to:
  /// **'Preload Mode'**
  String get preload_mode;

  /// No description provided for @start_preload.
  ///
  /// In en, this message translates to:
  /// **'Start Slingshot'**
  String get start_preload;

  /// No description provided for @swipe_again_to_cancel.
  ///
  /// In en, this message translates to:
  /// **'Swipe Right Again To Cancel'**
  String get swipe_again_to_cancel;

  /// No description provided for @execution_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Execution Cancelled'**
  String get execution_cancelled;

  /// No description provided for @sandevistan_duration_title.
  ///
  /// In en, this message translates to:
  /// **'Sandevistan Duration'**
  String get sandevistan_duration_title;

  /// No description provided for @sandevistan_duration_description.
  ///
  /// In en, this message translates to:
  /// **'Modify the Sandevistan Duration (Seconds)'**
  String get sandevistan_duration_description;

  /// No description provided for @sandevistan_duration_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter duration in seconds'**
  String get sandevistan_duration_hint;

  /// No description provided for @sandev_egg_useless.
  ///
  /// In en, this message translates to:
  /// **'NAH MAN! IT\'S USELESS! JUST DISABLE IT DAWG'**
  String get sandev_egg_useless;

  /// No description provided for @sandev_egg_original.
  ///
  /// In en, this message translates to:
  /// **'Bro is original, either have no idea or too scared to modify'**
  String get sandev_egg_original;

  /// No description provided for @sandev_egg_better.
  ///
  /// In en, this message translates to:
  /// **'Alright Choom that\'s better, go more higher if you want'**
  String get sandev_egg_better;

  /// No description provided for @sandev_egg_david.
  ///
  /// In en, this message translates to:
  /// **'What dawg? Try to be David Martinez? Ain\'t gonna work'**
  String get sandev_egg_david;

  /// No description provided for @sandev_egg_smasher.
  ///
  /// In en, this message translates to:
  /// **'NAH BRO GONNA SOLO ADAM SMASHER AT THIS POINT!'**
  String get sandev_egg_smasher;

  /// No description provided for @endfield_powersave_screen_off_title.
  ///
  /// In en, this message translates to:
  /// **'Powersave When Screen Off'**
  String get endfield_powersave_screen_off_title;

  /// No description provided for @endfield_normal_interval_title.
  ///
  /// In en, this message translates to:
  /// **'Normal Interval'**
  String get endfield_normal_interval_title;

  /// No description provided for @endfield_screen_off_interval_title.
  ///
  /// In en, this message translates to:
  /// **'Screen Off Interval'**
  String get endfield_screen_off_interval_title;

  /// No description provided for @endfield_interval_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter seconds (min 2)'**
  String get endfield_interval_hint;

  /// No description provided for @plugins_title.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get plugins_title;

  /// No description provided for @plugins_description.
  ///
  /// In en, this message translates to:
  /// **'Manage and install external modules for Project Raco'**
  String get plugins_description;

  /// No description provided for @install_plugin.
  ///
  /// In en, this message translates to:
  /// **'Install Plugin'**
  String get install_plugin;

  /// No description provided for @no_plugins_installed.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed'**
  String get no_plugins_installed;

  /// No description provided for @plugin_installer.
  ///
  /// In en, this message translates to:
  /// **'Plugin Installer'**
  String get plugin_installer;

  /// No description provided for @installing_module.
  ///
  /// In en, this message translates to:
  /// **'Installing Raco Plugin'**
  String get installing_module;

  /// No description provided for @install_question.
  ///
  /// In en, this message translates to:
  /// **'Do you want to install this plugin?'**
  String get install_question;

  /// No description provided for @delete_plugin_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Plugin'**
  String get delete_plugin_title;

  /// No description provided for @delete_plugin_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {pluginName}?'**
  String delete_plugin_confirm(String pluginName);

  /// No description provided for @plugin_verification_failed.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed: RacoPlugin=1 not found in prop.'**
  String get plugin_verification_failed;

  /// No description provided for @plugin_script_error.
  ///
  /// In en, this message translates to:
  /// **'Install Script Error.'**
  String get plugin_script_error;

  /// No description provided for @logs_saved.
  ///
  /// In en, this message translates to:
  /// **'Logs saved to Downloads.'**
  String get logs_saved;

  /// No description provided for @plugin_installed_success.
  ///
  /// In en, this message translates to:
  /// **'Plugin installed successfully.'**
  String get plugin_installed_success;

  /// No description provided for @plugin_uninstall_success.
  ///
  /// In en, this message translates to:
  /// **'Plugin uninstalled.'**
  String get plugin_uninstall_success;

  /// No description provided for @plugin_manually_executed.
  ///
  /// In en, this message translates to:
  /// **'Plugin Manually Executed.'**
  String get plugin_manually_executed;

  /// No description provided for @plugin_run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get plugin_run;

  /// No description provided for @plugin_boot.
  ///
  /// In en, this message translates to:
  /// **'Boot'**
  String get plugin_boot;

  /// No description provided for @slingshot_no_app_selected.
  ///
  /// In en, this message translates to:
  /// **'No app selected'**
  String get slingshot_no_app_selected;

  /// No description provided for @slingshot_executing.
  ///
  /// In en, this message translates to:
  /// **'Slingshoting {package}...'**
  String slingshot_executing(String package);

  /// No description provided for @slingshot_complete.
  ///
  /// In en, this message translates to:
  /// **'Slingshot Complete'**
  String get slingshot_complete;

  /// No description provided for @slingshot_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search apps...'**
  String get slingshot_search_hint;

  /// No description provided for @slingshot_reload_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Reload App List'**
  String get slingshot_reload_tooltip;

  /// No description provided for @slingshot_no_apps_found.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get slingshot_no_apps_found;

  /// No description provided for @slingshot_mode_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal (fadvise hint)'**
  String get slingshot_mode_normal;

  /// No description provided for @slingshot_mode_deep.
  ///
  /// In en, this message translates to:
  /// **'Deep (fadvise + dlopen)'**
  String get slingshot_mode_deep;

  /// No description provided for @slingshot_mode_extreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme (mmap + MAP_POPULATE)'**
  String get slingshot_mode_extreme;

  /// No description provided for @slingshot_mode_recursive.
  ///
  /// In en, this message translates to:
  /// **'Recursive (looped deep check)'**
  String get slingshot_mode_recursive;

  /// No description provided for @silent_mode_title.
  ///
  /// In en, this message translates to:
  /// **'Silent Mode'**
  String get silent_mode_title;

  /// No description provided for @silent_mode_description.
  ///
  /// In en, this message translates to:
  /// **'Disables Notification, Raco Will Apply Tweaks Without Notifying'**
  String get silent_mode_description;

  /// No description provided for @slingshot_graphics_warning.
  ///
  /// In en, this message translates to:
  /// **'Some games might broken, Some might improve performance, Some might don\'t even Launch. But don\'t be afraid to try it first!'**
  String get slingshot_graphics_warning;

  /// No description provided for @playboost_title.
  ///
  /// In en, this message translates to:
  /// **'RiProG Playboost'**
  String get playboost_title;

  /// No description provided for @added_to_gamelist.
  ///
  /// In en, this message translates to:
  /// **'Added {package} to game list'**
  String added_to_gamelist(String package);

  /// No description provided for @removed_from_gamelist.
  ///
  /// In en, this message translates to:
  /// **'Removed {package} from game list'**
  String removed_from_gamelist(String package);

  /// No description provided for @extra_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Extra Settings'**
  String get extra_settings_title;

  /// No description provided for @extra_settings_description.
  ///
  /// In en, this message translates to:
  /// **'Anya, Kobo, Zetamin, Sandevistan'**
  String get extra_settings_description;

  /// No description provided for @anya_installer_title.
  ///
  /// In en, this message translates to:
  /// **'Anya Thermal'**
  String get anya_installer_title;

  /// No description provided for @anya_installer_desc.
  ///
  /// In en, this message translates to:
  /// **'Disable / Enable Thermal | Anya Flowstate'**
  String get anya_installer_desc;

  /// No description provided for @kobo_title.
  ///
  /// In en, this message translates to:
  /// **'Kobo Fast Charge'**
  String get kobo_title;

  /// No description provided for @kobo_desc.
  ///
  /// In en, this message translates to:
  /// **'Fast Charging Add On'**
  String get kobo_desc;

  /// No description provided for @zetamin_title.
  ///
  /// In en, this message translates to:
  /// **'Zetamin'**
  String get zetamin_title;

  /// No description provided for @zetamin_desc.
  ///
  /// In en, this message translates to:
  /// **'All in One Display Tweaks'**
  String get zetamin_desc;

  /// No description provided for @sandev_boot_title.
  ///
  /// In en, this message translates to:
  /// **'Sandevistan Boot'**
  String get sandev_boot_title;

  /// No description provided for @sandev_boot_desc.
  ///
  /// In en, this message translates to:
  /// **'An Attempt to Make Boot Faster'**
  String get sandev_boot_desc;

  /// No description provided for @reboot_to_take_effect.
  ///
  /// In en, this message translates to:
  /// **'Please Reboot to take effects'**
  String get reboot_to_take_effect;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'id', 'ja', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'id':
      return AppLocalizationsId();
    case 'ja':
      return AppLocalizationsJa();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
