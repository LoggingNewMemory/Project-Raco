# PixelSleep & Bypass Charging

Keduanya ada di APK: **Utilities -> PixelSleep** dan **Utilities -> Bypass Charging**.
Di Game Asisten (tab Tools) hanya ada saklar: tile **PixelSleep** dan **Bypass Charge**.

## PixelSleep
- Overlay layar penuh yang tidak menerima sentuhan, berisi pola titik hitam (ordered dither 8x8)
  yang tersebar merata. Jumlah pixel (2-50 %) dan ukuran titik (1-3 px) diatur di APK.
- Hemat baterai HANYA di layar OLED/AMOLED (pixel hitam tidak memancarkan cahaya). LCD tidak berubah.
- Berjalan sebagai foreground service (notifikasi kecil) dan dipulihkan setelah reboot.
- Android 12+: sistem memblokir sentuhan yang menembus overlay pihak ketiga yang opasitasnya > 0.8.
  Aplikasi memulai dari 0.8 (selalu aman), lalu (root) mengatur `block_untrusted_touches` = 0,
  memverifikasinya, baru menaikkan ke hitam penuh. Nilai asli dipulihkan saat PixelSleep dimatikan.

## Bypass Charging
- Menulis nilai ke node sysfs pengendali charger (butuh root). Node yang dikenal dideteksi otomatis
  (batt_slate_mode, input_suspend, charging_enabled, dll.), bisa dipilih manual atau isi node sendiri
  (path harus di /sys/, nilai dibatasi huruf/angka).
- Pengaman (BypassService): charging otomatis normal lagi saat charger dicabut atau baterai di bawah
  batas "Lanjut mengisi di bawah" (default 20 %). Setelah reboot flag bypass direset.
- Dukungan tergantung kernel: sebagian node hanya MENGHENTIKAN pengisian (baterai tetap terpakai),
  bukan pass-through sejati. Coba satu node per satu dan lihat arus/kondisi di halaman status.

### Bypass "asli" di MediaTek (Infinix/Tecno)
Setelah XOS 16, bypass bawaan Infinix (`/sys/devices/platform/charger/bypass_charger`) hanya menurunkan arus,
sebagian masih masuk baterai. Modul open source (AZenith, ACC) memakai interface gauge MediaTek:
`echo "0 1" > /proc/mtk_battery_cmd/current_cmd` (bypass) dan `echo "0 0" > ...` (normal);
arus baterai turun sampai <= 10 mA. Node ini ada di daftar bawaan dan diprioritaskan.
Halaman status menampilkan verifikasi: "Baterai diam (~0 mA)" bila bypass benar-benar asli.

## File baru
`tools/` (PixelSleepController, PixelSleepService, BypassCharging, BypassService, BootReceiver,
ToolNotifications), `UtilitiesPages/PixelSleepScreen.kt`, `UtilitiesPages/BypassChargingScreen.kt`,
`res/values*/strings_tools.xml`. Diubah: `UtilitiesScreen.kt`, `RacoGameAssistant.kt`, `AndroidManifest.xml`.
