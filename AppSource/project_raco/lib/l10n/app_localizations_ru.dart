// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get app_title => 'Project Raco';

  @override
  String get by => 'By: Kanagawa Yamada';

  @override
  String get root_access => 'Root-доступ:';

  @override
  String get module_installed => 'Модуль установлен:';

  @override
  String get module_version => 'Версия модуля:';

  @override
  String get module_not_installed => 'Модуль не установлен';

  @override
  String get current_mode => 'Текущий режим:';

  @override
  String get select_language => 'Выбрать язык:';

  @override
  String get power_save_desc => 'Приоритет батареи над производительностью';

  @override
  String get balanced_desc => 'Баланс батареи и производительности';

  @override
  String get performance_desc => 'Приоритет производительности над батарей';

  @override
  String get clear_desc => 'Отчистка RAM путём убийства фоновых приложений';

  @override
  String get cooldown_desc =>
      'Охлаждаю устройство\n(Дайте отдохнуть ему 2 минты)';

  @override
  String get gaming_desc =>
      'Установка режима производительности и убийство ВСЕХ запущенных приложений';

  @override
  String get power_save => 'Энергосбережение';

  @override
  String get balanced => 'Баланс';

  @override
  String get performance => 'Производительность';

  @override
  String get clear => 'Отчистить';

  @override
  String get cooldown => 'Охлаждение';

  @override
  String get gaming_pro => 'Игровой режим';

  @override
  String get about_title =>
      'Спасибо всем, кто помог сделать Project Raco таким , каким вы его сейчас видите:';

  @override
  String get about_quote =>
      '\"Отличное сотрудничество приводит к отличным инновациям\"\n~ Kanagawa Yamada (главный разработчик)';

  @override
  String get about_note =>
      'Project Raco всегда будет бесплатен, с открытым исходным кодом, и открытым для улучшений';

  @override
  String get credits_1 => 'Rem01 Gaming';

  @override
  String get credits_2 => 'MiAzami';

  @override
  String get credits_3 => 'Kazuyoo';

  @override
  String get credits_4 => 'RiProG';

  @override
  String get credits_5 => 'HoyoSlave';

  @override
  String get credits_6 => 'Koneko_dev';

  @override
  String get credits_7 => 'Not_ValentineSTCV';

  @override
  String get credits_8 => 'Andreyka4_45';

  @override
  String get credits_9 => 'Zexshia';

  @override
  String get credits_10 => 'KanaDev_IS';

  @override
  String get credits_11 => 'И всем тестерам, которых я не могу упомянуть';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get utilities => 'Утилиты';

  @override
  String get utilities_title => 'Утилиты';

  @override
  String get search_utilities => 'Найти утилиты';

  @override
  String get core_tweaks_title => 'Основные твики';

  @override
  String get automation_title => 'Автоматически';

  @override
  String get system_title => 'Система';

  @override
  String get appearance_title => 'Внешний вид';

  @override
  String get fix_and_tweak_title => 'Фиксы и твики';

  @override
  String get device_mitigation_title => 'Смягчение фризов';

  @override
  String get device_mitigation_description =>
      'Включите это, если ваш экран имеет подтормаживания';

  @override
  String get lite_mode_title => 'Легкий режим';

  @override
  String get lite_mode_description =>
      'Облегченная версия производительности, меньше расходует батарею, но дает меньший прирост производительности';

  @override
  String get hamada_ai => 'HAMADA AI';

  @override
  String get hamada_ai_description =>
      'Автоматически меняет режим на Производительность, когда открывается игра';

  @override
  String get downscale_resolution => 'Понизить резрешение';

  @override
  String selected_resolution(String resolution) {
    return 'Выбранное разрешение: $resolution';
  }

  @override
  String get reset_resolution => 'Вернуться к родному разрешению';

  @override
  String get hamada_ai_toggle_title => 'Включить HAMADA AI';

  @override
  String get hamada_ai_start_on_boot => 'Запускать при загрузке устройтсва';

  @override
  String get edit_game_txt_title => 'Изменить game.txt';

  @override
  String get sync_changes => 'Синхронизовать изменения';

  @override
  String get save_button => 'Сохранить';

  @override
  String get executing_command => 'Выполнение...';

  @override
  String get command_executed => 'Команда выполнена Успешно.';

  @override
  String get command_failed => 'Ошибка.';

  @override
  String get saving_file => 'Сохранение...';

  @override
  String get file_saved => 'Файл сохранён.';

  @override
  String get file_save_failed => 'Ошибка сохранения файла.';

  @override
  String get reading_file => 'Чтение файла...';

  @override
  String get file_read_failed => 'Ошибка чтения файла.';

  @override
  String get writing_service_file => 'Обновление скрипта запуска...';

  @override
  String get service_file_updated => 'Скрипт запуска обновлён.';

  @override
  String get service_file_update_failed => 'Ошибка обновления скрипта запуска.';

  @override
  String get error_no_root => 'Нужен ROOT доступ.';

  @override
  String get error_file_not_found => 'Файл не найден.';

  @override
  String get game_txt_hint =>
      'Введите имена игровых пакетов по одному в каждую строку...';

  @override
  String get resolution_unavailable_message =>
      'Управление разрешением не досутпно на этом устройстве.';

  @override
  String get applying_changes => 'Применение настроек...';

  @override
  String get applying_new_color =>
      'Применение нового цвета, Пожалуйста подождите...';

  @override
  String get dnd_title => 'Изменить DND';

  @override
  String get dnd_description =>
      'Автоматический переключатель DND Включен / Выключен';

  @override
  String get dnd_toggle_title => 'Включить автопереключатель DND';

  @override
  String get bypass_charging_title => 'Обходная зарядка';

  @override
  String get bypass_charging_description =>
      'Включите обходную зарядку в режиме Производительности & Игровом на поддерживаемом устройстве';

  @override
  String get bypass_charging_toggle => 'Включить обходную зарядку';

  @override
  String get bypass_charging_unsupported =>
      'Обходная зарядка не поддреживается на вашем устройстве';

  @override
  String get bypass_charging_supported =>
      'Обходная зарядка поддерживается на вашем устройстве';

  @override
  String get mode_status_label => 'Mode:';

  @override
  String get mode_manual => 'Ручной';

  @override
  String get mode_hamada_ai => 'HamadaAI';

  @override
  String get please_disable_hamada_ai_first =>
      'Пожалуйста сначала отключите HamadaAI';

  @override
  String get background_settings_title => 'Фоновые настройки';

  @override
  String get background_settings_description =>
      'Измените фоновое изображение приложения, непрозрачность, и блюр эффект.';

  @override
  String get opacity_slider_label => 'Непрозрачность фона';

  @override
  String get blur_slider_label => 'Блюр заднего фона';

  @override
  String get banner_settings_title => 'Параметры баннера';

  @override
  String get banner_settings_description =>
      'Измените главное изображение (16:9).';

  @override
  String get device_name => 'Имя устройства';

  @override
  String get processor => 'Процессор';

  @override
  String get ram => 'RAM';

  @override
  String get phone_storage => 'хранилище';

  @override
  String get battery_capacity => 'Ёмкость батареи';

  @override
  String get custom_governor_title => 'Кастомный Governor';

  @override
  String get custom_governor_description =>
      'Выбор кастомного ЦПУ governor, Это изменит governor в Баланс режиме';

  @override
  String get loading_governors => 'Загрузка governors...';

  @override
  String get no_governor_selected => 'Ничего';

  @override
  String get anya_thermal_title => 'Anya Melfissa Disable Thermal';

  @override
  String get anya_thermal_description =>
      'Отключение Thermal в играх, Включите Thermal в Баланс, Энергосберегающем, Охлаждающем режимах.';

  @override
  String get anya_thermal_toggle_title => 'Включить Anya Thermal Flowstate';

  @override
  String get system_actions_title => 'Системные действия';

  @override
  String get fstrim_title => 'Fstrim';

  @override
  String get fstrim_description => 'Обрезка Android разделов.';

  @override
  String get clear_cache_title => 'Отчистка caсhe';

  @override
  String get better_powersave_title => 'Batter Powersave';

  @override
  String get better_powersave_description =>
      'Уменьшите частоту процессора наполовину вместо минимальной (только в режиме энергосбережения).';

  @override
  String get carlotta_cpu_title => 'Carlotta CPU';

  @override
  String get carlotta_cpu_description =>
      'Изменить целевой ЦП (ВНИМАНИЕ: Возможен сбой устройства)';

  @override
  String build_version_title(String buildName) {
    return 'Project Raco: $buildName Build';
  }

  @override
  String build_by_title(String builderName) {
    return 'Build By: $builderName';
  }

  @override
  String get screen_modifier_title => 'Модификатор экрана';

  @override
  String get screen_modifier_description =>
      'Настройте цветовую матрицу и насыщенность экрана для индивидуального отображения.';

  @override
  String get screen_modifier_red => 'Красный';

  @override
  String get screen_modifier_green => 'Зеленый';

  @override
  String get screen_modifier_blue => 'Синий';

  @override
  String get screen_modifier_saturation => 'Насыщенность';

  @override
  String get screen_modifier_reset => 'Сбросить по умолчанию';

  @override
  String get screen_modifier_apply_on_boot => 'Применять при загрузке';

  @override
  String get graphics_driver_title => 'Системный графический драйвер';

  @override
  String get graphics_driver_description =>
      'Изменить графический драйвер устройства';

  @override
  String get graphics_driver_default => 'По умолчанию';

  @override
  String get graphics_driver_game => 'Игровой драйвер';

  @override
  String get graphics_driver_developer => 'Драйвер разработчика';

  @override
  String get current_driver => 'Текущий:';

  @override
  String get legacy_notif_title => 'Устаревшее уведомление';

  @override
  String get legacy_notif_description =>
      'Используйте это, если уведомления не отображаются на некоторых прошивках';

  @override
  String get kasane_title => 'Kasane Предзагрузка';

  @override
  String get kasane_by => 'Автор: Koneko_Dev';

  @override
  String get free_ram => 'Свободная RAM:';

  @override
  String get preload_mode => 'Режим предзагрузки';

  @override
  String get start_preload => 'Начать';
}
