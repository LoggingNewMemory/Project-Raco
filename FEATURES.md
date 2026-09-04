# Features Documentation

## Critical Compatibility Notice

**DO NOT combine this module with any other performance optimization modules.**

Some modules may be compatible, but proceed with caution. The low-level nature of Project Raco means it will likely conflict with other kernel tweakers or memory managers.

---

## Core Technologies (C-Based Daemon)

Project Raco utilizes a compiled C backend (`raco_service`) to apply system-level changes efficiently.

### RSwap (Advanced Swap Management)
- **Direct Block/Loop Swap:** Creates and manages a dedicated `/data/ProjectRaco/RSWAP` file.
- **Priority Paging:** Ensures swap is active and optimized at a kernel level.

### Zetamin (Display & Rendering Optimizations)
- **SurfaceFlinger Tweaks:** Injects props to disable hardware composition overhead, backpressure, and client composition caches.
- **Render Engine Overrides:** Mount-masks configuration files to enforce SkiaVK (Vulkan-based) or ANGLE (OpenGL ES translation) as the primary renderer.

### Kobo (Fast Charge Control)
- **Current & Voltage Unlocking:** Bypasses default charging limitations by directly modifying power supply values (e.g., setting max current and voltage constraints).
- **Thermal Limit Adjustments:** Recalibrates cooling, warm, and hot temperature thresholds to maintain charging speeds.

### Anya (Thermal Control Override)
- **Thermal Flowstate Disabler:** A Project Raco exclusive that halts standard thermal daemon services.
- **Service Termination:** Scans and forcibly stops kernel thermal drivers (`init.svc.*thermal`) via `resetprop` to prevent aggressive throttling during heavy loads.

### Ayunda Rusdi (Color & Screen Enhancements)
- **Advanced Display Calibration:** Directly modifies screen output parameters for richer, more accurate color representation.

---

## CPU, GPU & System Tweaks

- **App-Based Mode Control (Hamada AI):** Intelligently switches performance modes. Automatically detects game launches to enter performance mode, and scales back during screen-off (Doze/Deep Sleep).
- **GPU Max Lock Frequency:** Dynamically pulls maximum supported frequencies from GPU drivers (including MediaTek's `gpufreq_opp_dump`) and locks them to prevent frame drops.
- **I/O Tweaks:** Alters scheduler algorithms and random-add parameters across all block devices to reduce read/write latency.
- **LMK & Memory Tuning:** Optimizes Low Memory Killer limits and system memory caching behavior.
- **Deep Sleep Optimization:** Configures GMS (Google Mobile Services) to Doze efficiently, reducing background battery drain.

---

## Project Raco Companion App & Game Assistant

The module includes a fully native Kotlin/Jetpack Compose Android app (`ProjectRaco.apk`) that serves as a control center and game enhancement suite.

### In-Game Overlay
- **Floating System Monitor:** Real-time FPS, RAM usage, and system status overlaid directly onto your games.
- **Quick Controls:** Instantly toggle Refresh Rate, Rotation Lock, Screen Brightness, and trigger RAM cleanups without minimizing the game.
- **Game Tools:** 
  - **Custom Crosshair:** Configurable screen-center crosshairs for shooter games.
  - **Auxiliary Lines:** On-screen alignment lines for strategic placement.
  - **Auto DND (Do Not Disturb):** Blocks notifications while gaming.

### App Modules
- **Core Tweaks Screen:** Interface to manually trigger IO, CPU, and GPU scripts.
- **Automation Screen:** Configure Hamada AI, Auto DND, and app whitelists.
- **RSwap & Appearance Screens:** Manage the swapfile size and adjust Ayunda Rusdi color properties.

---

## Support & Troubleshooting

For issues or questions, please refer to the main documentation or contact support through the official Project Raco Telegram channel.
