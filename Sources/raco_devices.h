/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
This program is free software: you can redistribute it and/or modify it under the terms of 
the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. 

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
See the GNU General Public License for more details. 
You should have received a copy of the GNU General Public License along with this program. 

If not, see https://www.gnu.org/licenses/.
 */
 
#ifndef RACO_DEVICES_H
#define RACO_DEVICES_H

// SoC Awaken Profiles
void mediatek_awaken();
void snapdragon_awaken();
void exynos_awaken();
void unisoc_awaken();
void tensor_awaken();
void tegra_awaken();

// SoC Balanced Profiles
void mediatek_balanced();
void snapdragon_balanced();
void exynos_balanced();
void unisoc_balanced();
void tensor_balanced();
void tegra_balanced();

// SoC Powersave Profiles
void mediatek_powersave();
void snapdragon_powersave();
void exynos_powersave();
void unisoc_powersave();
void tensor_powersave();
void tegra_powersave();

// SoC Normal Profiles (Neutral)
void mediatek_normal();
void snapdragon_normal();
void exynos_normal();
void unisoc_normal();
void tensor_normal();
void tegra_normal();

// Devfreq Helpers
void devfreq_max_perf(const char *path);
void devfreq_mid_perf(const char *path);
void devfreq_min_perf(const char *path);
void devfreq_unlock(const char *path);

#endif // RACO_DEVICES_H