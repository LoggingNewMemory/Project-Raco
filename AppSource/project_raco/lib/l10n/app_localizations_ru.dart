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
  String get by => 'Автор: Kanagawa Yamada';

  @override
  String get root_access => 'Root-права:';

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
  String get performance_desc => 'Приоритет производительности над батареей';

  @override
  String get clear_desc =>
      'Отчистка оперативной памяти путём убийства фоновых приложений';

  @override
  String get cooldown_desc =>
      'Охладить устройство\n(Дайте ему отдохнуть 2 минуты)';

  @override
  String get gaming_desc =>
      'Установка режима Производительность и убийство ВСЕХ запущенных приложений';

  @override
  String get power_save => 'Энергосбережение';

  @override
  String get balanced => 'Баланс';

  @override
  String get performance => 'Производительность';

  @override
  String get clear => 'Отчистка';

  @override
  String get cooldown => 'Охлаждение';

  @override
  String get gaming_pro => 'Игровой режим';

  @override
  String get about_title =>
      'Спасибо всем, кто помог сделать Project Raco таким, каким вы его сейчас видите:';

  @override
  String get about_quote =>
      '\"Отличное сотрудничество приводит к отличным инновациям\"\n~ Kanagawa Yamada (главный разработчик)';

  @override
  String get about_note =>
      'Project Raco всегда будет бесплатным, с открытым исходным кодом, и открытым для улучшений';

  @override
  String get credits_11 => 'И все тестеры, которых я не могу упомянуть';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get utilities => 'Утилиты';

  @override
  String get utilities_title => 'Утилиты';

  @override
  String get search_utilities => 'Поиск утилит';

  @override
  String get core_tweaks_title => 'Основные твики';

  @override
  String get automation_title => 'Автоматизация';

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
      'Включите, если ваш экран подтормаживает';

  @override
  String get lite_mode_title => 'Легкий режим';

  @override
  String get lite_mode_description =>
      'LITE версия производительности: меньше расходует батарею, но дает меньший прирост производительности';

  @override
  String get life_mode_title => 'Режим LIFE';

  @override
  String get life_mode_description => 'Половина мощности ЦП в режиме Баланс';

  @override
  String get endfield_engine => 'Endfield Engine';

  @override
  String get endfield_engine_description =>
      'Включает Производительность в играх, Энергосбережение при выключенном экране';

  @override
  String get downscale_resolution => 'Понизить разрешение';

  @override
  String selected_resolution(String resolution) {
    return 'Выбранное разрешение: $resolution';
  }

  @override
  String get reset_resolution => 'Вернуться к родному разрешению';

  @override
  String get endfield_engine_toggle_title => 'Включить Endfield Engine';

  @override
  String get endfield_engine_start_on_boot => 'Запускать при загрузке';

  @override
  String get edit_game_txt_title => 'Изменить game.txt';

  @override
  String get sync_changes => 'Синхронизовать изменения';

  @override
  String get executing_command => 'Выполнение...';

  @override
  String get command_executed => 'Команда выполнена успешно.';

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
  String get error_no_root => 'Нужны ROOT права.';

  @override
  String get error_file_not_found => 'Файл не найден.';

  @override
  String get game_txt_hint =>
      'Введите имена игровых пакетов по одному в каждую строку...';

  @override
  String get resolution_unavailable_message =>
      'Управление разрешением не доступно на этом устройстве.';

  @override
  String get applying_changes => 'Применение настроек...';

  @override
  String get applying_new_color =>
      'Применение нового цвета, Пожалуйста подождите...';

  @override
  String get dnd_title => 'Не беспокоить';

  @override
  String get dnd_description => 'Автоматический переключатель Не беспокоить';

  @override
  String get dnd_toggle_title => 'Автоматический Не беспокоить';

  @override
  String get bypass_charging_title => 'Обходная зарядка';

  @override
  String get bypass_charging_description =>
      'Включать обходную зарядку в режиме Производительности и Игровом режиме на поддерживаемых устройствах';

  @override
  String get bypass_charging_toggle => 'Обходная зарядка';

  @override
  String get bypass_charging_unsupported =>
      'Обходная зарядка не поддерживается на вашем устройстве';

  @override
  String get bypass_charging_supported =>
      'Обходная зарядка поддерживается на вашем устройстве';

  @override
  String get mode_status_label => 'Режим:';

  @override
  String get mode_manual => 'Ручной';

  @override
  String get mode_endfield_engine => 'Endfield';

  @override
  String get please_disable_endfield_engine_first =>
      'Пожалуйста, сначала отключите Endfield Engine';

  @override
  String get background_settings_title => 'Настройки фона';

  @override
  String get background_settings_description =>
      'Изменяйте фоновое изображение приложения, непрозрачность, и размытие.';

  @override
  String get opacity_slider_label => 'Непрозрачность фона';

  @override
  String get blur_slider_label => 'Размытие фона';

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
  String get ram => 'Оперативная память';

  @override
  String get phone_storage => 'Хранилище';

  @override
  String get battery_capacity => 'Ёмкость батареи';

  @override
  String get custom_governor_title => 'Кастомный governor';

  @override
  String get custom_governor_description =>
      'Выбор кастомного governer-а ЦП, Это изменит governor в режиме Баланс';

  @override
  String get loading_governors => 'Загрузка governor-ов...';

  @override
  String get no_governor_selected => 'Ничего';

  @override
  String get anya_thermal_title => 'Отключение тротлинга Anya Melfissa';

  @override
  String get anya_thermal_description =>
      'Отключать тротлинг в Игровом режиме и режиме Производительность, включать в режимах Энергосбережение, Баланс, Охлаждение.';

  @override
  String get anya_thermal_toggle_title => 'Включить Anya Thermal Flowstate';

  @override
  String get system_actions_title => 'Системные действия';

  @override
  String get fstrim_title => 'fstrim';

  @override
  String get fstrim_description => 'Оптимизация разделов.';

  @override
  String get clear_cache_title => 'Отчистка кэша';

  @override
  String get better_powersave_title => 'Улучшенное энергосбережение';

  @override
  String get better_powersave_description =>
      'Уменьшать частоту процессора до середины вместо минимума (только в режиме Энергосбережение).';

  @override
  String get carlotta_cpu_title => 'Carlotta ЦП';

  @override
  String get carlotta_cpu_description =>
      'Изменить целевой ЦП (ВНИМАНИЕ: Возможен сбой устройства)';

  @override
  String build_version_title(String buildName) {
    return 'Project Raco: Сборка $buildName ';
  }

  @override
  String build_by_title(String builderName) {
    return 'Собрано $builderName';
  }

  @override
  String get screen_modifier_title => 'Модификация экрана';

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
  String get graphics_driver_title => 'Графический драйвер';

  @override
  String get graphics_driver_description => 'Изменить графический драйвер';

  @override
  String get graphics_driver_default => 'По умолчанию';

  @override
  String get graphics_driver_game => 'Игровой драйвер';

  @override
  String get graphics_driver_developer => 'Драйвер разработчика';

  @override
  String get current_driver => 'Текущий:';

  @override
  String get legacy_notif_title => 'Старые уведомления';

  @override
  String get legacy_notif_description =>
      'Включите, если уведомления не отображаются';

  @override
  String get slingshot_title => 'Raco Slingshot';

  @override
  String get slingshot_description =>
      'Предварительно загрузите файлы вашего приложения перед запуском, это может ускорить время запуска и повысить производительность';

  @override
  String get angle_title => 'Запуск с графикой ANGLE';

  @override
  String get angle_not_supported =>
      'Графика ANGLE не поддерживается на этом устройстве';

  @override
  String get skia_title => 'Использовать SkiaVK как Skia бэкенд по умолчанию';

  @override
  String get preload_mode => 'Режим предзагрузки';

  @override
  String get start_preload => 'Начать Slingshot';

  @override
  String get swipe_again_to_cancel => 'Свайпните вправо еще раз для отмены';

  @override
  String get execution_cancelled => 'Выполнение отменено';

  @override
  String get sandevistan_duration_title => 'Длительность Sandevistan';

  @override
  String get sandevistan_duration_description =>
      'Изменить длительность Sandevistan (Секунды)';

  @override
  String get sandevistan_duration_hint => 'Введите длительность в секундах';

  @override
  String get sandev_egg_useless => 'НЕ, БРО! ЭТО БЕСПОЛЕЗНО! ПРОСТО ВЫРУБИ ЭТО';

  @override
  String get sandev_egg_original =>
      'Бро оригинален, либо понятия не имеет что это, либо боится менять';

  @override
  String get sandev_egg_better => 'Во, так-то лучше, давай выше, если хочешь';

  @override
  String get sandev_egg_david =>
      'Чего? Пытаешься быть Дэвидом Мартинесом? Не прокатит';

  @override
  String get sandev_egg_smasher =>
      'НЕ, НУ ТЫ РЕШИЛ АДАМА СМЭШЕРА В СОЛО ВЫНЕСТИ!';

  @override
  String get endfield_powersave_screen_off_title =>
      'Энергосбережение при выключенном экране';

  @override
  String get endfield_normal_interval_title => 'Обычный интервал';

  @override
  String get endfield_screen_off_interval_title =>
      'Интервал при выключенном экране';

  @override
  String get endfield_interval_hint => 'Введите в секундах (минимум 2)';

  @override
  String get plugins_title => 'Плагины';

  @override
  String get plugins_description =>
      'Управление и установка внешних модулей для Project Raco';

  @override
  String get install_plugin => 'Установить плагин';

  @override
  String get no_plugins_installed => 'Плагины не установлены';

  @override
  String get plugin_installer => 'Установщик плагинов';

  @override
  String get installing_module => 'Установка плагина Raco';

  @override
  String get install_question => 'Вы хотите установить этот плагин?';

  @override
  String get delete_plugin_title => 'Удалить плагин';

  @override
  String delete_plugin_confirm(String pluginName) {
    return 'Вы уверены, что хотите удалить $pluginName?';
  }

  @override
  String get plugin_verification_failed =>
      'Ошибка проверки: RacoPlugin=1 не найден в свойствах.';

  @override
  String get plugin_script_error => 'Ошибка скрипта установки.';

  @override
  String get logs_saved => 'Логи сохранены в Загрузки.';

  @override
  String get plugin_installed_success => 'Плагин успешно установлен.';

  @override
  String get plugin_uninstall_success => 'Плагин удален.';

  @override
  String get plugin_manually_executed => 'Плагин запущен вручную.';

  @override
  String get plugin_run => 'Запустить';

  @override
  String get plugin_boot => 'Загрузить';

  @override
  String get slingshot_no_app_selected => 'Приложение не выбрано';

  @override
  String slingshot_executing(String package) {
    return 'Slingshot для $package...';
  }

  @override
  String get slingshot_complete => 'Slingshot завершен';

  @override
  String get slingshot_search_hint => 'Поиск приложений...';

  @override
  String get slingshot_reload_tooltip => 'Обновить список приложений';

  @override
  String get slingshot_no_apps_found => 'Приложения не найдены';

  @override
  String get slingshot_mode_normal => 'Обычный (fadvise hint)';

  @override
  String get slingshot_mode_deep => 'Глубокий (fadvise + dlopen)';

  @override
  String get slingshot_mode_extreme => 'Экстремальный (mmap + MAP_POPULATE)';

  @override
  String get slingshot_mode_recursive => 'Рекурсивный (looped deep check)';

  @override
  String get silent_mode_title => 'Тихий режим';

  @override
  String get silent_mode_description =>
      'Отключает уведомления, Raco будет применять твики без уведомления';

  @override
  String get slingshot_graphics_warning =>
      'Некоторые игры могут сломаться, некоторые могут улучшить производительность, а некоторые могут даже не запуститься. Но не бойтесь попробовать!';

  @override
  String get playboost_title => 'RiProG Playboost';

  @override
  String added_to_gamelist(String package) {
    return 'Добавлено $package в список игр';
  }

  @override
  String removed_from_gamelist(String package) {
    return 'Удалено $package из списка игр';
  }

  @override
  String get extra_settings_title => 'Дополнительные настройки';

  @override
  String get extra_settings_description => 'Anya, Kobo, Zetamin, Sandevistan';

  @override
  String get anya_installer_title => 'Anya Thermal';

  @override
  String get anya_installer_desc =>
      'Отключить / Включить тротлинг | Anya Flowstate';

  @override
  String get kobo_title => 'Быстрая зарядка Kobo';

  @override
  String get kobo_desc => 'Дополнение для быстрой зарядки';

  @override
  String get zetamin_title => 'Zetamin';

  @override
  String get zetamin_desc => 'Все настройки дисплея в одном';

  @override
  String get sandev_boot_title => 'Загрузка Sandevistan';

  @override
  String get sandev_boot_desc => 'Попытка ускорить загрузку';

  @override
  String get reboot_to_take_effect =>
      'Пожалуйста, перезагрузите устройство для применения изменений';

  @override
  String get please_restart_app => 'Пожалуйста, перезапустите приложение';
}
