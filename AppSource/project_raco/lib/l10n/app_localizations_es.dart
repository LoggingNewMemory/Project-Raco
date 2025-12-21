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
  String get lite_mode_description => 'Usar modo lite (Solicitado por fans)';

  @override
  String get hamada_ai => 'HAMADA AI';

  @override
  String get hamada_ai_description =>
      'Autmáticamente cambia a modo Rendimiento cuando se inicie un juego.';

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
  String get save_button => 'Guardar';

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
}
