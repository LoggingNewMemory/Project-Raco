// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get app_title => 'Project Raco';

  @override
  String get by => 'Oleh: Kanagawa Yamada';

  @override
  String get root_access => 'Akses Root:';

  @override
  String get module_installed => 'Modul Terpasang:';

  @override
  String get module_version => 'Versi Modul:';

  @override
  String get module_not_installed => 'Tidak Terpasang';

  @override
  String get current_mode => 'Mode Saat Ini:';

  @override
  String get select_language => 'Pilih Bahasa:';

  @override
  String get power_save_desc => 'Memprioritaskan Baterai Di Atas Performa';

  @override
  String get balanced_desc => 'Seimbangkan Baterai dan Performa';

  @override
  String get performance_desc => 'Memprioritaskan Performa Di Atas Baterai';

  @override
  String get clear_desc => 'Bersihkan RAM Dengan Membunuh Semua Aplikasi';

  @override
  String get cooldown_desc =>
      'Dinginkan Perangkat Anda\n(Biarkan Beristirahat Selama 2 Menit)';

  @override
  String get gaming_desc => 'Atur ke Performa dan Bunuh Semua Aplikasi';

  @override
  String get power_save => 'Hemat Daya';

  @override
  String get balanced => 'Seimbang';

  @override
  String get performance => 'Performa';

  @override
  String get clear => 'Bersihkan';

  @override
  String get cooldown => 'Dinginkan';

  @override
  String get gaming_pro => 'Pro Gaming';

  @override
  String get about_title =>
      'Terima kasih kepada orang-orang hebat yang membantu memperbaiki Project Raco:';

  @override
  String get about_quote =>
      '\"Kolaborasi Hebat Mengarah pada Inovasi Hebat\"\n~ Kanagawa Yamada (Pengembang Utama)';

  @override
  String get about_note =>
      'Project Raco Selalu Gratis, Sumber Terbuka, dan Terbuka untuk Peningkatan';

  @override
  String get credits_11 =>
      'Dan Semua Penguji yang Tidak Bisa Disebutkan Satu per Satu';

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get utilities => 'Utilitas';

  @override
  String get utilities_title => 'Utilitas';

  @override
  String get search_utilities => 'Cari Utilitas';

  @override
  String get core_tweaks_title => 'Tweak Inti';

  @override
  String get automation_title => 'Otomatisasi';

  @override
  String get system_title => 'Sistem';

  @override
  String get appearance_title => 'Tampilan';

  @override
  String get fix_and_tweak_title => 'Perbaikan & Tweak';

  @override
  String get device_mitigation_title => 'Mitigasi Perangkat';

  @override
  String get device_mitigation_description =>
      'Nyalakan jika Anda mengalami layar beku';

  @override
  String get lite_mode_title => 'Mode LITE';

  @override
  String get lite_mode_description =>
      'Versi Ringan dari Performa, menggunakan Lebih Sedikit Baterai tetapi Peningkatan Performa Lebih Sedikit';

  @override
  String get life_mode_title => 'Mode LIFE';

  @override
  String get life_mode_description => 'Setengah Daya CPU di Seimbang';

  @override
  String get hamada_ai => 'HAMADA AI';

  @override
  String get hamada_ai_description =>
      'Beralih ke Performa Saat Masuk Game, Beralih ke Hemat Daya Saat Layar Mati';

  @override
  String get downscale_resolution => 'Turunkan Resolusi';

  @override
  String selected_resolution(String resolution) {
    return 'Terpilih: $resolution';
  }

  @override
  String get reset_resolution => 'Kembali ke Asli';

  @override
  String get hamada_ai_toggle_title => 'Aktifkan HAMADA AI';

  @override
  String get hamada_ai_start_on_boot => 'Mulai saat Boot';

  @override
  String get edit_game_txt_title => 'Edit game.txt';

  @override
  String get sync_changes => 'Sinkronkan Perubahan';

  @override
  String get executing_command => 'Menjalankan...';

  @override
  String get command_executed => 'Perintah dijalankan.';

  @override
  String get command_failed => 'Perintah gagal.';

  @override
  String get saving_file => 'Menyimpan...';

  @override
  String get file_saved => 'File disimpan.';

  @override
  String get file_save_failed => 'Gagal menyimpan file.';

  @override
  String get reading_file => 'Membaca file...';

  @override
  String get file_read_failed => 'Gagal membaca file.';

  @override
  String get writing_service_file => 'Memperbarui skrip boot...';

  @override
  String get service_file_updated => 'Skrip boot diperbarui.';

  @override
  String get service_file_update_failed => 'Gagal memperbarui skrip boot.';

  @override
  String get error_no_root => 'Membutuhkan akses root.';

  @override
  String get error_file_not_found => 'File tidak ditemukan.';

  @override
  String get game_txt_hint => 'Masukkan nama paket game, satu per baris...';

  @override
  String get resolution_unavailable_message =>
      'Kontrol resolusi tidak tersedia di perangkat ini.';

  @override
  String get applying_changes => 'Menerapkan perubahan...';

  @override
  String get applying_new_color => 'Menerapkan Warna Baru, Harap Tunggu...';

  @override
  String get dnd_title => 'Saklar DND';

  @override
  String get dnd_description => 'Otomatis Nyalakan / Matikan DND';

  @override
  String get dnd_toggle_title => 'Aktifkan Saklar Otomatis DND';

  @override
  String get bypass_charging_title => 'Bypass Charging';

  @override
  String get bypass_charging_description =>
      'Aktifkan Bypass Charging Saat Mode Performa & Gaming Pro di Perangkat yang Didukung';

  @override
  String get bypass_charging_toggle => 'Aktifkan Bypass Charging';

  @override
  String get bypass_charging_unsupported =>
      'Bypass charging tidak didukung di perangkat Anda';

  @override
  String get bypass_charging_supported =>
      'Bypass charging didukung di perangkat Anda';

  @override
  String get mode_status_label => 'Mode:';

  @override
  String get mode_manual => 'Manual';

  @override
  String get mode_hamada_ai => 'HamadaAI';

  @override
  String get please_disable_hamada_ai_first =>
      'Harap Nonaktifkan HamadaAI Terlebih Dahulu';

  @override
  String get background_settings_title => 'Pengaturan Latar Belakang';

  @override
  String get background_settings_description =>
      'Sesuaikan gambar latar belakang, opasitas, dan efek blur aplikasi.';

  @override
  String get opacity_slider_label => 'Opasitas Latar Belakang';

  @override
  String get blur_slider_label => 'Tingkat Blur Latar';

  @override
  String get banner_settings_title => 'Pengaturan Banner';

  @override
  String get banner_settings_description =>
      'Sesuaikan gambar banner layar utama (rasio aspek 16:9).';

  @override
  String get device_name => 'Nama perangkat';

  @override
  String get processor => 'Prosesor';

  @override
  String get ram => 'RAM';

  @override
  String get phone_storage => 'Penyimpanan telepon';

  @override
  String get battery_capacity => 'Kapasitas baterai';

  @override
  String get custom_governor_title => 'Gubernur Kustom';

  @override
  String get custom_governor_description =>
      'Atur gubernur CPU kustom, Ini akan mengatur gubernur dalam mode seimbang';

  @override
  String get loading_governors => 'Memuat gubernur...';

  @override
  String get no_governor_selected => 'Tidak Ada';

  @override
  String get anya_thermal_title => 'Anya Melfissa Nonaktifkan Thermal';

  @override
  String get anya_thermal_description =>
      'Nonaktifkan Thermal pada mode Performa dan Gaming, Aktifkan Thermal pada mode Hemat Daya, Seimbang, dan Dinginkan.';

  @override
  String get anya_thermal_toggle_title => 'Aktifkan Anya Thermal Flowstate';

  @override
  String get system_actions_title => 'Tindakan Sistem';

  @override
  String get fstrim_title => 'Fstrim';

  @override
  String get fstrim_description => 'Pangkas partisi Android.';

  @override
  String get clear_cache_title => 'Bersihkan Cache';

  @override
  String get better_powersave_title => 'Powersave Lebih Baik';

  @override
  String get better_powersave_description =>
      'Batasi Freq CPU ke Setengah, bukan Freq Minimum (Hanya Mode Powersave)';

  @override
  String get carlotta_cpu_title => 'Carlotta CPU';

  @override
  String get carlotta_cpu_description =>
      'Modifikasi Target CPU (PERINGATAN: Dapat Membuat Perangkat Crash)';

  @override
  String build_version_title(String buildName) {
    return 'Project Raco: Build $buildName';
  }

  @override
  String build_by_title(String builderName) {
    return 'Dibuat Oleh: $builderName';
  }

  @override
  String get screen_modifier_title => 'Pengubah Layar';

  @override
  String get screen_modifier_description =>
      'Sesuaikan matriks warna layar dan saturasi untuk pengalaman tampilan kustom.';

  @override
  String get screen_modifier_red => 'Merah';

  @override
  String get screen_modifier_green => 'Hijau';

  @override
  String get screen_modifier_blue => 'Biru';

  @override
  String get screen_modifier_saturation => 'Saturasi';

  @override
  String get screen_modifier_reset => 'Kembali ke Default';

  @override
  String get screen_modifier_apply_on_boot => 'Terapkan saat Boot';

  @override
  String get graphics_driver_title => 'Driver Grafis Sistem';

  @override
  String get graphics_driver_description => 'Ubah Driver Grafis Perangkat Anda';

  @override
  String get graphics_driver_default => 'Default';

  @override
  String get graphics_driver_game => 'Driver Game';

  @override
  String get graphics_driver_developer => 'Driver Pengembang';

  @override
  String get current_driver => 'Saat Ini:';

  @override
  String get legacy_notif_title => 'Notifikasi Legacy';

  @override
  String get legacy_notif_description =>
      'Gunakan Notifikasi Legacy Jika Notifikasi Tidak Muncul Di Beberapa ROM';

  @override
  String get slingshot_title => 'Raco Slingshot';

  @override
  String get slingshot_description =>
      'Preload file aplikasi Anda sebelum meluncurkan aplikasi, ini dapat mempercepat waktu memuat dan meningkatkan performa';

  @override
  String get angle_title => 'Jalankan dengan Grafis ANGLE';

  @override
  String get angle_description =>
      'Jalankan aplikasi menggunakan driver Grafis ANGLE';

  @override
  String get angle_not_supported =>
      'Grafis ANGLE tidak didukung di perangkat ini';

  @override
  String get preload_mode => 'Mode Preload';

  @override
  String get start_preload => 'Mulai Slingshot';

  @override
  String get swipe_again_to_cancel => 'Geser Kanan Lagi Untuk Membatalkan';

  @override
  String get execution_cancelled => 'Eksekusi Dibatalkan';

  @override
  String get toast_title => 'Notifikasi Toast';

  @override
  String get toast_description =>
      'Gunakan toast daripada notifikasi (Disarankan jika menggunakan HamadaAI)';

  @override
  String get sandevistan_duration_title => 'Durasi Sandevistan';

  @override
  String get sandevistan_duration_description =>
      'Ubah Durasi Sandevistan (Detik)';

  @override
  String get sandevistan_duration_hint => 'Masukkan durasi dalam detik';
}
