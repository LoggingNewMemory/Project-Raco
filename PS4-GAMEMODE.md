# PS4 Game Mode (Project Raco)

Entry: ikon gamepad di pojok kanan atas layar utama. Mode ini landscape + fullscreen,
bertahan sampai kamu keluar (ikon power / Back -> konfirmasi).

## Suara & musik
Semua suara bawaan DISINTESIS di perangkat (orisinal, tanpa file audio, di-cache di cacheDir).
Musik/SFX PS4 asli berhak cipta dan tidak disertakan.

Untuk memakai audio milikmu sendiri, taruh file di `app/src/main/res/raw/` dengan nama:

| Nama file (tanpa ekstensi) | Dipakai untuk |
|---|---|
| ps4_bgm | musik latar (loop) |
| ps4_nav | geser daftar game |
| ps4_confirm | tekan START |
| ps4_startup | masuk Mode Game |
| ps4_launch | animasi masuk game |
| ps4_mode_eco / ps4_mode_balanced / ps4_mode_awaken | ganti mode |

`res/raw/keep.xml` mencegah R8 membuang file-file itu di build release.
Musik juga bisa dipilih dari penyimpanan lewat ikon gerigi di Mode Game.

## Overlay ganti mode
- Dalam game: jendela overlay layar penuh (tidak menghalangi sentuhan) muncul saat memilih
  Powersave/Balanced/Awaken di Game Assistant -> `gamemode/AssistantModeAnimator.kt`.
- Di Mode Game: bar ECO/BALANCED/AWAKEN memakai id yang sama dengan Game Assistant (2/3/4).

## Tampilan PS4 v2 (mengikuti referensi PS4 home)
- Bar status atas: logo + nama hari, mode aktif (ECO/BALANCED/AWAKEN), baterai %, suhu, ikon fungsi, jam.
- Baris tile persegi: tile fokus membesar (1.35x) dengan bingkai putih dan tetap di dekat tepi kiri
  saat daftar bergeser. Ketuk tile fokus (atau tombol START) untuk membuka game.
- Latar: pita sutra mengalir + simbol segitiga/lingkaran/silang/kotak yang melayang (ikut warna tema).
- Ikon di bar atas membuka panel di dalam Mode Game: PixelSleep, Bypass Charging, Tema & Suara,
  Pengaturan (membuka SEMUA halaman setelan app: Utilities, Raco Launchpad, Kill All Whitelist,
  Raco, About). Back menutup panel dulu, baru menawarkan keluar dari Mode Game.
