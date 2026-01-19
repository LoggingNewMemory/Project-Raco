# Features Documentation

## ⚠️ Critical Compatibility Notice

**DO NOT combine this module with any other performance optimization modules.**

Some modules may be compatible (e.g., SkiaVK/GL Module), but proceed with caution. Test thoroughly before deploying.

---

## Core Features

### Performance Controls
- **App-Based Mode Control** - Switch performance modes per application
- **CPU Max Lock Frequency** - Lock CPU to maximum frequency for sustained performance
- **GPU Tweaks** - Graphics processor optimizations
- **RAM Tweaks** - Memory management enhancements
- **Storage Tweaks** - I/O performance improvements

### System Optimizations
- **GED Tweaks** - Game Engine Daemon optimizations
- **Mali Scheduling** - Enhanced GPU scheduling for Mali chipsets
- **Minor Kernel Tweaks** - Low-level system optimizations
- **LMK Tweak** - Low Memory Killer adjustments
- **Disable Tracing** - Remove system tracing overhead

### Thermal Management
- **Anya Disable Thermal Flowstate** *(Addon - Project Raco Exclusive)*
  - Advanced thermal control system
  - **Note:** Standard thermal checking via `getprop | grep thermal` doesn't work
  - **Alternative command:** `ps -A | grep -i thermal`

---

## Addon Features

### Charging & Battery
- **Fast Charge** - Accelerated charging speeds
- **Kobo Fast Charge** - Enhanced fast charging implementation
- **Bypass Charging** *(on supported devices)* - Direct power mode
- **Disable Lock Frame Rate When Low Battery** - Maintain performance on low battery

### Display & Graphics
- **Vestia Zeta Display** - Display enhancement suite
- **Ayunda Rusdi Color Enhancer Pro** *(Project Raco Exclusive)* - Advanced color calibration
- **Downscale Resolution** - Reduce resolution for better performance
- **AmeRender Gen II** *(Render & SurfaceFlinger Tweaks)*
  - Compatible with SkiaVK/GL render modules
  - Advanced rendering pipeline optimizations
- **Disable Frame Rate Limit** - Remove FPS caps

### Rendering Backend
- **System Graphics Driver Switcher** - Switch between graphics drivers
- **Set SkiaVK as Backend Render** - Vulkan-based Skia rendering
- **Set ANGLE as Renderer** - OpenGL ES translation layer

### Intelligence & Automation
- **Hamada AI** - Intelligent performance switching
  - Auto-switch to performance mode during gaming
  - Auto-switch to power-save when screen is off
- **Sandevistan Boot** *(Project Raco Exclusive Settings)* - Optimized boot sequence
- **Auto DND When Playing Games** - Automatic Do Not Disturb mode

### System Maintenance
- **FStrim & Clear Cache** - Storage optimization and cleanup
- **Kasane Preload** - Intelligent app preloading
- **Raco Plugin** - Extended functionality support

### Input & Network
- **Touch Improve Tweak** - Enhanced touchscreen responsiveness
- **Set CloudFlare DNS as Default** - Improved DNS resolution (1.1.1.1)

---

## Compatibility Notes

- Test each feature individually before enabling multiple features
- Some features are device-specific and may not work on all hardware
- Project Raco Exclusive features require the full Project Raco package
- Always create a backup before applying system-level tweaks

---

## Support & Troubleshooting

For issues or questions, please refer to the main documentation or contact support through (official channels)[https://t.me/KLCGen2].