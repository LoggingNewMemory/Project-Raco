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

  /// No description provided for @credits_1.
  ///
  /// In en, this message translates to:
  /// **'Rem01 Gaming'**
  String get credits_1;

  /// No description provided for @credits_2.
  ///
  /// In en, this message translates to:
  /// **'MiAzami'**
  String get credits_2;

  /// No description provided for @credits_3.
  ///
  /// In en, this message translates to:
  /// **'Kazuyoo'**
  String get credits_3;

  /// No description provided for @credits_4.
  ///
  /// In en, this message translates to:
  /// **'RiProG'**
  String get credits_4;

  /// No description provided for @credits_5.
  ///
  /// In en, this message translates to:
  /// **'HoyoSlave'**
  String get credits_5;

  /// No description provided for @credits_6.
  ///
  /// In en, this message translates to:
  /// **'Koneko_dev'**
  String get credits_6;

  /// No description provided for @credits_7.
  ///
  /// In en, this message translates to:
  /// **'Not_ValentineSTCV'**
  String get credits_7;

  /// No description provided for @credits_8.
  ///
  /// In en, this message translates to:
  /// **'Andreyka4_45'**
  String get credits_8;

  /// No description provided for @credits_9.
  ///
  /// In en, this message translates to:
  /// **'Zexshia'**
  String get credits_9;

  /// No description provided for @credits_10.
  ///
  /// In en, this message translates to:
  /// **'KanaDev_IS'**
  String get credits_10;

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
  /// **'Using Lite mode (Requested by Fans)'**
  String get lite_mode_description;

  /// No description provided for @hamada_ai.
  ///
  /// In en, this message translates to:
  /// **'HAMADA AI'**
  String get hamada_ai;

  /// No description provided for @hamada_ai_description.
  ///
  /// In en, this message translates to:
  /// **'Automatically Switch to Performance When Entering Game'**
  String get hamada_ai_description;

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

  /// No description provided for @hamada_ai_toggle_title.
  ///
  /// In en, this message translates to:
  /// **'Enable HAMADA AI'**
  String get hamada_ai_toggle_title;

  /// No description provided for @hamada_ai_start_on_boot.
  ///
  /// In en, this message translates to:
  /// **'Start on Boot'**
  String get hamada_ai_start_on_boot;

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

  /// No description provided for @save_button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_button;

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

  /// No description provided for @mode_hamada_ai.
  ///
  /// In en, this message translates to:
  /// **'HamadaAI'**
  String get mode_hamada_ai;

  /// No description provided for @please_disable_hamada_ai_first.
  ///
  /// In en, this message translates to:
  /// **'Please Disable HamadaAI First'**
  String get please_disable_hamada_ai_first;

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
  /// **'Carlotta CPU Mitigation'**
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
