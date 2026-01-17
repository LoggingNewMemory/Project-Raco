// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get app_title => 'Project Raco';

  @override
  String get by => 'Por: Kanagawa Yamada';

  @override
  String get root_access => 'Acceso Root:';

  @override
  String get module_installed => 'Módulo Instalado:';

  @override
  String get module_version => 'Versión de Módulo:';

  @override
  String get module_not_installed => 'No Instalado';

  @override
  String get current_mode => 'Perfil Actual:';

  @override
  String get select_language => 'Selecciona tu lenguaje:';

  @override
  String get power_save_desc => 'Priorizar eficiencia sobre rendimiento';

  @override
  String get balanced_desc => 'Equilibrar eficiencia y rendimiento';

  @override
  String get performance_desc => 'Priorizar rendimiento sobre eficiencia';

  @override
  String get clear_desc => 'Limpiar la ram a través de cerrar procesos';

  @override
  String get cooldown_desc =>
      'Enfriar tu dispositivo\n(Dejalo descansar por 2 minutos)';

  @override
  String get gaming_desc =>
      'Cambie a rendimiento y termine procesos para liberar más RAM';

  @override
  String get power_save => 'Ahorro de batería';

  @override
  String get balanced => 'Equilibrio';

  @override
  String get performance => 'Rendimiento';

  @override
  String get clear => 'Limpiar';

  @override
  String get cooldown => 'Enfriar';

  @override
  String get gaming_pro => 'Gaming Pro';

  @override
  String get about_title =>
      'Gracias a toda la maravillosa gente que ayuda a mejorar Project Raco:';

  @override
  String get about_quote =>
      '\"Grande colaboración lleva a grande innovación!\"\n~ Kanagawa Yamada (Principal desarrollador)';

  @override
  String get about_note =>
      'Project Raco es grátis, código abierto y libre para modificar y mejorar!';

  @override
  String get credits_11 => 'Y a todos los testers que aportaron su feedback!';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get utilities => 'Utilidades';

  @override
  String get utilities_title => 'Utilidades';

  @override
  String get search_utilities => 'Buscar utilidades';

  @override
  String get core_tweaks_title => 'Tweaks principales';

  @override
  String get automation_title => 'Automatización';

  @override
  String get system_title => 'Sistema';

  @override
  String get appearance_title => 'Apariencia';

  @override
  String get fix_and_tweak_title => 'Arreglo y tweaks';

  @override
  String get device_mitigation_title => 'Mitigación del dispositivo';

  @override
  String get device_mitigation_description =>
      'Enciendelo si experimentas congelado de pantalla';

  @override
  String get lite_mode_title => 'Modo lite';

  @override
  String get lite_mode_description =>
      'Versión ligera de rendimiento, usa menos batería pero con menor aumento de rendimiento';

  @override
  String get life_mode_title => 'Modo LIFE';

  @override
  String get life_mode_description => 'Mitad de potencia de CPU en Equilibrado';

  @override
  String get hamada_ai => 'HAMADA AI';

  @override
  String get hamada_ai_description =>
      'Cambiar a Rendimiento al entrar al juego, cambiar a Ahorro de batería al apagar pantalla';

  @override
  String get downscale_resolution => 'Disminuir la resolución';

  @override
  String selected_resolution(String resolution) {
    return 'Seleccionado: $resolution';
  }

  @override
  String get reset_resolution => 'Restablecer valores originales';

  @override
  String get hamada_ai_toggle_title => 'Activar HAMADA AI';

  @override
  String get hamada_ai_start_on_boot => 'Iniciar al arrancar';

  @override
  String get edit_game_txt_title => 'Editar game.txt';

  @override
  String get sync_changes => 'Sincronizar cambios';

  @override
  String get executing_command => 'Ejecutando...';

  @override
  String get command_executed => 'Comando ejecutado.';

  @override
  String get command_failed => 'Comando fallido.';

  @override
  String get saving_file => 'Guardando...';

  @override
  String get file_saved => 'Archivo guardado.';

  @override
  String get file_save_failed => 'Fallo al guardar archivo.';

  @override
  String get reading_file => 'Leyendo archivo...';

  @override
  String get file_read_failed => 'Fallo al leer el archivo.';

  @override
  String get writing_service_file => 'Actualizando script de arranque...';

  @override
  String get service_file_updated => 'Script de arranque actualizado.';

  @override
  String get service_file_update_failed =>
      'Fallo al actualizar el script de arranque.';

  @override
  String get error_no_root => 'Acceso root requerido.';

  @override
  String get error_file_not_found => 'Archivo no encontrado.';

  @override
  String get game_txt_hint =>
      'Escriba el nombre del paquete del juego, uno por linea...';

  @override
  String get resolution_unavailable_message =>
      'Control de resolución no está disponible para este dispositivo.';

  @override
  String get applying_changes => 'Aplicando cambios...';

  @override
  String get applying_new_color => 'Aplicando nuevo color, por favor espere...';

  @override
  String get dnd_title => 'Modo no molestar';

  @override
  String get dnd_description =>
      'Automaticamente activa/desactiva modo No Molestar';

  @override
  String get dnd_toggle_title =>
      'Activar cambio automático de modo No Molestar';

  @override
  String get bypass_charging_title => 'Bypass de carga';

  @override
  String get bypass_charging_description =>
      'Activar Bypass de carga estando en modo Rendimiento & Gaming Pro en dispositivos soportados';

  @override
  String get bypass_charging_toggle => 'Activar Bypass de carga';

  @override
  String get bypass_charging_unsupported =>
      'Bypass de carga no está soportado para tu dispositivo';

  @override
  String get bypass_charging_supported =>
      'Bypass de carga está soportado para tu dispositivo';

  @override
  String get mode_status_label => 'Modo:';

  @override
  String get mode_manual => 'Manual';

  @override
  String get mode_hamada_ai => 'HamadaAI';

  @override
  String get please_disable_hamada_ai_first =>
      'Por favor desactive HamadaAI primero';

  @override
  String get background_settings_title => 'Configuración de fondo';

  @override
  String get background_settings_description =>
      'Configure la apariencia del fondo, color, opacidad y otros valores más.';

  @override
  String get opacity_slider_label => 'Opacidad de fondo';

  @override
  String get blur_slider_label => 'Desenfoque de fondo';

  @override
  String get banner_settings_title => 'Configuración de banner';

  @override
  String get banner_settings_description =>
      'Personalizar el aspecto del banner de la pantalla principal (Imágenes con aspecto 16:9 soportados).';

  @override
  String get device_name => 'Nombre de dispositivo';

  @override
  String get processor => 'Procesador';

  @override
  String get ram => 'Memoria RAM';

  @override
  String get phone_storage => 'Almacenamiento';

  @override
  String get battery_capacity => 'Capacidad de bateria';

  @override
  String get custom_governor_title => 'Governor personalizado';

  @override
  String get custom_governor_description =>
      'Ajuste su Governor personalizado para su CPU, Esto se pondrá en modo balance';

  @override
  String get loading_governors => 'Cargando governors...';

  @override
  String get no_governor_selected => 'Ninguno';

  @override
  String get anya_thermal_title => 'Anya Melfissa Disable Thermal';

  @override
  String get anya_thermal_description =>
      'Deshabilita Thermal en Rendimiento y Gaming, Y habilita Thermal en Eficiencia, Equilibrado y Enfriamiento.';

  @override
  String get anya_thermal_toggle_title => 'Activa Anya Thermal Flowstate';

  @override
  String get system_actions_title => 'Acciones de sistema';

  @override
  String get fstrim_title => 'Fstrim';

  @override
  String get fstrim_description => 'Recortar particiones de Android.';

  @override
  String get clear_cache_title => 'Limpiar caché';

  @override
  String get better_powersave_title => 'Mejor eficiencia';

  @override
  String get better_powersave_description =>
      'Limita el CPU a la mitad en vez de frecuencia minima (Solo para Modo Eficiencia)';

  @override
  String get carlotta_cpu_title => 'Carlotta CPU';

  @override
  String get carlotta_cpu_description =>
      'Modificar CPU Objetivo (ADVERTENCIA: Puede Bloquear su Dispositivo)';

  @override
  String build_version_title(String buildName) {
    return 'Project Raco: $buildName Compilacion';
  }

  @override
  String build_by_title(String builderName) {
    return 'Compilacion por: $builderName';
  }

  @override
  String get screen_modifier_title => 'Modificador de Pantalla';

  @override
  String get screen_modifier_description =>
      'Ajuste la matriz de color y la saturación de la pantalla para una experiencia de visualización personalizada.';

  @override
  String get screen_modifier_red => 'Rojo';

  @override
  String get screen_modifier_green => 'Verde';

  @override
  String get screen_modifier_blue => 'Azul';

  @override
  String get screen_modifier_saturation => 'Saturación';

  @override
  String get screen_modifier_reset => 'Restablecer a Valores Predeterminados';

  @override
  String get screen_modifier_apply_on_boot => 'Aplicar al Arrancar';

  @override
  String get graphics_driver_title => 'Controlador Gráfico del Sistema';

  @override
  String get graphics_driver_description =>
      'Modifica el controlador gráfico de tu dispositivo';

  @override
  String get graphics_driver_default => 'Predeterminado';

  @override
  String get graphics_driver_game => 'Juegos';

  @override
  String get graphics_driver_developer => 'Desarrollador';

  @override
  String get current_driver => 'Actual:';

  @override
  String get legacy_notif_title => 'Notificación heredada';

  @override
  String get legacy_notif_description =>
      'Use la notificación heredada si la notificación no aparece en algunas ROMs';

  @override
  String get slingshot_title => 'Raco Slingshot';

  @override
  String get slingshot_description =>
      'Precarga los archivos de tu aplicación antes de iniciarla, esto puede acelerar el tiempo de carga y mejorar el rendimiento';

  @override
  String get angle_title => 'Iniciar usando gráficos ANGLE';

  @override
  String get angle_not_supported =>
      'Los gráficos ANGLE no son compatibles con este dispositivo';

  @override
  String get skia_title => 'Usar SkiaVK como motor Skia predeterminado';

  @override
  String get preload_mode => 'Modo de Preload';

  @override
  String get start_preload => 'Iniciar Slingshot';

  @override
  String get swipe_again_to_cancel =>
      'Desliza a la derecha de nuevo para cancelar';

  @override
  String get execution_cancelled => 'Ejecución cancelada';

  @override
  String get toast_title => 'Notificación Toast';

  @override
  String get toast_description =>
      'Usar toast en lugar de notificación (Recomendado si usa HamadaAI)';

  @override
  String get sandevistan_duration_title => 'Duración Sandevistan';

  @override
  String get sandevistan_duration_description =>
      'Modificar la Duración Sandevistan (Segundos)';

  @override
  String get sandevistan_duration_hint => 'Ingrese la duración en segundos';

  @override
  String get sandev_egg_useless => '¡NAH TÍO! ¡ES INÚTIL! ¡MEJOR DESACTÍVALO!';

  @override
  String get sandev_egg_original =>
      'Puro original, o no tienes idea o te da miedo modificarlo';

  @override
  String get sandev_egg_better => 'Así me gusta Choom, súbele más si quieres';

  @override
  String get sandev_egg_david =>
      '¿Qué pasa? ¿Intentas ser David Martinez? No va a funcionar';

  @override
  String get sandev_egg_smasher =>
      '¡NAH BRO, A ESTE PUNTO TE SOLEAS A ADAM SMASHER!';

  @override
  String get hamada_powersave_screen_off_title =>
      'Ahorro de batería al apagar pantalla';

  @override
  String get hamada_normal_interval_title => 'Intervalo Normal';

  @override
  String get hamada_screen_off_interval_title => 'Intervalo Pantalla Apagada';

  @override
  String get hamada_interval_hint => 'Introduce segundos (min 2)';

  @override
  String get plugins_title => 'Plugins';

  @override
  String get plugins_description =>
      'Administrar e instalar módulos externos para Project Raco';

  @override
  String get install_plugin => 'Instalar Plugin';

  @override
  String get no_plugins_installed => 'No hay plugins instalados';

  @override
  String get plugin_installer => 'Instalador de Plugins';

  @override
  String get install_question => '¿Quieres instalar este plugin?';

  @override
  String get delete_plugin_title => 'Eliminar Plugin';

  @override
  String delete_plugin_confirm(String pluginName) {
    return '¿Estás seguro de que deseas eliminar $pluginName?';
  }

  @override
  String get plugin_verification_failed =>
      'Verificación fallida: RacoPlugin=1 no encontrado en prop.';

  @override
  String get plugin_script_error => 'Error en el script de instalación.';

  @override
  String get logs_saved => 'Registros guardados en Descargas.';

  @override
  String get plugin_installed_success => 'Plugin instalado con éxito.';

  @override
  String get plugin_uninstall_success => 'Plugin desinstalado.';
}
