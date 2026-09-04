<img width="1280" height="720" alt="Banner" src="https://github.com/user-attachments/assets/78637f78-1a79-41cc-9dba-ab1dfd2bdf0a" />

# Project Raco

**Universal Android Performance & Optimization Module**

Project Raco is an advanced, root-level performance enhancement framework for Android devices. Written in C and Shell, and paired with a modern Kotlin-based companion app, it aims to unlock the maximum hardware potential of your device for gaming and daily use.

## Compatibility
Project Raco is designed to support a wide range of chipsets. Its dynamic SoC recognition engine detects and applies optimizations specific to:
* **Snapdragon** (Qualcomm)
* **MediaTek**
* **Exynos** (Samsung)
* **Kirin** (Huawei)
* **UniSoc**

> **Note:** This module likely supports almost all mobile architectures (excluding PC/x86 CPUs). The installer will automatically verify support and apply the correct patches.

---

## Core Components
Project Raco is split into two main architectures:
1. **CoreSys (C-based Daemon):** Low-level tweaks including I/O scheduling, GPU frequency locking, kernel optimizations, and custom modules (Kobo, Anya, Zetamin, RSwap).
2. **Companion App (Kotlin/Jetpack Compose):** A fully featured control center with a floating In-Game Overlay for real-time adjustments and monitoring.

## Features Overview
**NEW:** Project Raco now includes a robust **Companion App** featuring:
* **Auto Game Detection & Monitoring**
* **Real-time Floating FPS & System Info**
* **Quick Controls Overlay** (Refresh Rate, Rotation Lock, Brightness, Volume, RAM Clean)
* **Gaming Tools** (Custom Crosshair, Auxiliary Lines)

**MUST READ:** Before installing, please review the full feature list and compatibility warnings.
**[View Full Features List](https://github.com/LoggingNewMemory/Project-Raco/blob/main/FEATURES.md)**

---

## For Developers
If you want your tweaks merged into Project Raco, please adhere to the following guidelines:
1. **Universal Stability:** Your tweaks must run on multiple devices without causing bootloops or conflicts.
2. **Adaptability:** Code must adapt to the main core structures and follow the C-based daemon logic.
3. **No Conflicts:** Ensure your code does not collide with existing tweaks (e.g., Zetamin or Anya).
4. **Single PR:** All tweaks must be sent through a single Pull Request.
5. **Functionality:** Tweaks must offer measurable performance benefits. Placebo tweaks will be rejected.

---
**Project Raco Official Telegram is [HERE](https://t.me/ProjectRacoOfficial)**
---

## Support The Project
If you enjoy this project, consider supporting the development:

* **Global:** [SociaBuzz](https://sociabuzz.com/kanagawa_yamada/tribe)
* **QRIS:** [Telegram](https://t.me/KLAGen2/86)

---

### Looking for the PC Version?
Check out Project Raco for PC here: **[Project-Raco-PC](https://github.com/LoggingNewMemory/Project-Raco-PC)**
