# Module Porting Guide for Project Raco

## Prerequisites

Before you begin porting modules to Project Raco, please read the [Plugin Development Guide](https://github.com/LoggingNewMemory/Project-Raco/blob/main/PLUGIN.md) thoroughly.

## Important Notes

- Project Raco 4.0 currently **does not support WebUI**. WebUI support may be added in future releases.
- Unlike traditional Magisk modules, Project Raco does not use `post-fs-data.sh`. Instead, all initialization should be handled in `service.sh`.

## Porting Checklist

### 1. Module Properties File
**Action:** Rename `module.prop` to `raco.prop`

Add the following line to identify it as a Raco plugin:
```
RacoPlugin=1
```

### 2. Plugin Logo
**Action:** Replace `banner.png` with `logo.png`

**Requirements:**
- Must have a 1:1 aspect ratio (square)
- Recommended maximum resolution: 512×512 pixels
- Higher resolutions (e.g., 4K) will unnecessarily increase file size and load times

### 3. Installation Script
**File:** `install.sh`

**Critical:** This script must be written in pure shell script language, similar to how you would write `service.sh`. Do not use Magisk module-specific syntax or functions.

### 4. Uninstallation Script
**File:** `uninstall.sh`

This script is executed when the plugin is uninstalled. If your plugin modifies system files, creates directories, or changes configurations, you must properly clean up these changes in this script. Do not leave it empty.

## Plugin Submission

Ready to share your plugin with the community?

1. Join the [Yamada Dormitory](https://t.me/ProjectRaco)
2. Tag @KanagawaYamadaVTeacher with your plugin submission
3. Your plugin will be reviewed and forwarded to the official Project Raco channel

## Guidelines and Warnings

⚠️ **Plugin Development Standards:**
- **No gimmick or fake plugins** – Your plugin must provide genuine functionality
- **Open source required** – Closed-source plugins will not be accepted
- **Quality matters** – Ensure your code is well-tested and properly documented

---

Good luck with your development! If you have questions, don't hesitate to reach out to the dormitory.