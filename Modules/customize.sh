#!/system/bin/sh

check_for_config_changes() {
  local new_config_template="$1"
  local saved_config="$2"
  
  get_keys() {
    grep -vE '^#|^\[|^$' "$1" | cut -d'=' -f1 | sort
  }

  new_keys=$(get_keys "$new_config_template")
  saved_keys=$(get_keys "$saved_config")
  
  if ! diff <(echo "$new_keys") <(echo "$saved_keys") >/dev/null 2>&1; then
    return 0 # 0 means true (changes detected)
  fi
  
  return 1 # 1 means false (no changes)
}

# This function merges old user settings into a new config template.
# This is triggered when a module update adds/removes options.
merge_configs() {
  local new_template="$1"
  local persistent_config="$2"
  local temp_config="$MODPATH/raco.tmp"

  ui_print "- Merging your previous settings..."
  cp "$new_template" "$temp_config"

  while IFS='=' read -r key value || [ -n "$key" ]; do
    [[ "$key" =~ ^# ]] || [ -z "$key" ] && continue
    local escaped_key=$(echo "$key" | sed -e 's/[]\/$*.^[]/\\&/g')
    if grep -q "^${escaped_key}=" "$temp_config"; then
      sed -i "s/^${escaped_key}=.*/${key}=${value}/" "$temp_config"
    fi
  done < "$persistent_config"

  mv "$temp_config" "$persistent_config"
  ui_print "- Settings merged successfully."
  ui_print "- New options will use default values."
}

# This function handles the interactive addon selection using volume keys.
manual_addon_selection() {
  local config_file="$1"

  ui_print " "
  ui_print "- Include Anya Thermal?"
  ui_print "  Disable / Enable Thermal | Anya Flowstate"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_ANYA=1; ui_print "  > Yes"; else INCLUDE_ANYA=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Kobo Fast Charge?"
  ui_print "  Fast Charging Add On"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_KOBO=1; ui_print "  > Yes"; else INCLUDE_KOBO=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Vestia Zeta Display?"
  ui_print "  Maximize Screen Refresh Rate"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_ZETA=1; ui_print "  > Yes"; else INCLUDE_ZETA=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Sandevistan Boot?"
  ui_print "  An Attempt to Make Boot Faster"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_SANDEV=1; ui_print "  > Yes"; else INCLUDE_SANDEV=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Updating configuration..."
  sed -i "s/^INCLUDE_ANYA=.*/INCLUDE_ANYA=$INCLUDE_ANYA/" "$config_file"
  sed -i "s/^INCLUDE_KOBO=.*/INCLUDE_KOBO=$INCLUDE_KOBO/" "$config_file"
  sed -i "s/^INCLUDE_ZETA=.*/INCLUDE_ZETA=$INCLUDE_ZETA/" "$config_file"
  sed -i "s/^INCLUDE_SANDEV=.*/INCLUDE_SANDEV=$INCLUDE_SANDEV/" "$config_file"
  ui_print "- Your choices have been saved."
}

# --- Main Script Execution ---

LATESTARTSERVICE=true
SOC=0
RACO_PERSIST_CONFIG="/data/ProjectRaco/raco.txt"
RACO_MODULE_TEMPLATE="$MODPATH/raco.txt"

ui_print "------------------------------------"
ui_print "             Project Raco           "
ui_print "------------------------------------"
ui_print "         By: Kanagawa Yamada        "
ui_print "------------------------------------"
ui_print " "
sleep 1.5

ui_print "------------------------------------"
ui_print "DO NOT COMBINE WITH ANY PERF MODULE!"
ui_print "------------------------------------"
ui_print " "
sleep 1.5

# Ensure the persistent data directory exists
mkdir -p /data/ProjectRaco

if [ -f "$RACO_PERSIST_CONFIG" ]; then
  SAVED_SOC=$(grep '^SOC=' "$RACO_PERSIST_CONFIG" | cut -d'=' -f2)
  if [ -n "$SAVED_SOC" ] && [ "$SAVED_SOC" -gt 0 ]; then
    SOC=$SAVED_SOC
  fi
fi

if [ $SOC -eq 0 ]; then
  soc_recognition_extra() {
    [ -d /sys/class/kgsl/kgsl-3d0/devfreq ] && { SOC=2; return 0; }
    [ -d /sys/devices/platform/kgsl-2d0.0/kgsl ] && { SOC=2; return 0; }
    [ -d /sys/kernel/ged/hal ] && { SOC=1; return 0; }
    [ -d /sys/kernel/tegra_gpu ] && { SOC=6; return 0; }
    return 1
  }

  get_soc_getprop() {
    local SOC_PROP="
ro.board.platform
ro.soc.model
ro.hardware
ro.chipname
ro.hardware.chipname
ro.vendor.soc.model.external_name
ro.vendor.qti.soc_name
ro.vendor.soc.model.part_name
ro.vendor.soc.model
"
    for prop in $SOC_PROP; do
      getprop "$prop"
    done
  }

  recognize_soc() {
    case "$1" in
    *mt* | *MT*) SOC=1 ;;
    *sm* | *qcom* | *SM* | *QCOM* | *Qualcomm*) SOC=2 ;;
    *exynos* | *Exynos* | *EXYNOS* | *universal* | *samsung* | *erd* | *s5e*) SOC=3 ;;
    *Unisoc* | *unisoc* | *ums*) SOC=4 ;;
    *gs* | *Tensor* | *tensor*) SOC=5 ;;
    *kirin*) SOC=7 ;;
    esac
    [ $SOC -eq 0 ] && return 1
  }

  ui_print "------------------------------------"
  ui_print "        RECOGNIZING CHIPSET         "
  ui_print "------------------------------------"
  soc_recognition_extra
  [ $SOC -eq 0 ] && recognize_soc "$(get_soc_getprop)"
  [ $SOC -eq 0 ] && recognize_soc "$(grep -E "Hardware|Processor" /proc/cpuinfo | uniq | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
  [ $SOC -eq 0 ] && recognize_soc "$(grep "model\sname" /proc/cpuinfo | uniq | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
  [ $SOC -eq 0 ] && {
    ui_print "! Unable to detect your SoC (Chipset)."
    abort "! Installation cannot continue. Aborting."
  }
fi

ui_print "------------------------------------"
ui_print "            MODULE INFO             "
ui_print "------------------------------------"
ui_print "Name : Project Raco"
ui_print "Version : 2.1"
ui_print " "
sleep 1.5

ui_print "      INSTALLING Project Raco       "
ui_print " "
sleep 1.5

ui_print "- Setting up module files..."
unzip -o "$ZIPFILE" 'Scripts/*' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'raco.txt' -d $MODPATH >&2

# File copy operations
rm -f "/data/local/tmp/logo.png" >/dev/null 2>&1
cp "$MODPATH/logo.png" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy logo.png"
rm -f "/data/local/tmp/Anya.png" >/dev/null 2>&1
cp "$MODPATH/Anya.png" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy Anya.png"

if [ -f "/data/ProjectRaco/game.txt" ]; then
    ui_print "- Existing game.txt found, preserving user settings."
else
    ui_print "- Performing first-time setup for game.txt."
    cp "$MODPATH/game.txt" "/data/ProjectRaco" >/dev/null 2>&1 || abort "! Failed to copy game.txt"
fi
ui_print " "

set_perm_recursive $MODPATH 0 0 0755 0755
set_perm_recursive $MODPATH/Scripts 0 0 0777 0755

sleep 1.5

choose() {
  while true; do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > "$TMPDIR/events"
    if [ -s "$TMPDIR/events" ]; then
      if grep -q "KEY_VOLUMEUP" "$TMPDIR/events"; then
        return 0
      else
        return 1
      fi
    fi
  done
}

# --- REVISED CONFIGURATION LOGIC ---
ui_print "------------------------------------"
ui_print "      OPTIONAL ADDON SELECTION      "
ui_print "------------------------------------"

if [ ! -f "$RACO_PERSIST_CONFIG" ]; then
  # Case 1: First-time installation.
  ui_print "- No previous configuration found."
  ui_print "- Please choose your preferred addons."
  cp "$RACO_MODULE_TEMPLATE" "$RACO_PERSIST_CONFIG"
  manual_addon_selection "$RACO_PERSIST_CONFIG"
else
  # Case 2: Existing installation.
  ui_print "- Saved configuration found."

  # Automatically merge if the config template has changed.
  # This preserves user settings across module updates.
  if check_for_config_changes "$RACO_MODULE_TEMPLATE" "$RACO_PERSIST_CONFIG"; then
    merge_configs "$RACO_MODULE_TEMPLATE" "$RACO_PERSIST_CONFIG"
  fi

  # Always give the user the choice to keep their settings or reconfigure.
  ui_print " "
  ui_print "  Use your saved settings?"
  ui_print "  (New options from updates are already merged)."
  ui_print " "
  ui_print "  Vol+ = Yes, use saved settings"
  ui_print "  Vol- = No, re-configure addons"
  ui_print " "
  if choose; then
    ui_print "- Using your saved/merged configuration."
  else
    ui_print "- Re-configuring addons..."
    manual_addon_selection "$RACO_PERSIST_CONFIG"
  fi
fi

# Finalize by writing the detected SOC code to the persistent config.
ui_print "- Finalizing SOC Code ($SOC) in config"
sed -i "s/^SOC=.*/SOC=$SOC/" "$RACO_PERSIST_CONFIG"

# Clean up the template file from the module directory.
# The module's own scripts should now read from /data/ProjectRaco/raco.txt
rm -f "$RACO_MODULE_TEMPLATE"

ui_print " "
ui_print "   INSTALLING/UPDATING Project Raco App   "
ui_print " "

PACKAGE_NAME="com.kanagawa.yamada.project.raco"
ui_print "- Copying ProjectRaco.apk..."
cp "$MODPATH/ProjectRaco.apk" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy ProjectRaco.apk"
pm install -r -g /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1
if ! pm path "$PACKAGE_NAME" >/dev/null 2>&1; then
  ui_print "! Initial install failed. Retrying with root..."
  su -c pm install -r -g /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1
  if ! pm path "$PACKAGE_NAME" >/dev/null 2>&1; then
    ui_print "! Root install also failed. Attempting a clean install..."
    ui_print "- Uninstalling any existing version..."
    su -c pm uninstall "$PACKAGE_NAME" >/dev/null 2>&1
    sleep 1
    ui_print "- Attempting a fresh installation..."
    su -c pm install -g /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1
  fi
fi

if pm path "$PACKAGE_NAME" >/dev/null 2>&1; then
  ui_print "- Project Raco App installed/updated successfully."
else
  ui_print "! CRITICAL: Failed to install the Project Raco App after multiple attempts."
fi
rm /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1

ui_print " "
ui_print "         INSTALLING HAMADA AI         "
ui_print " "

BIN_PATH=$MODPATH/system/bin
TARGET_BIN_NAME=HamadaAI
TARGET_BIN_PATH=$BIN_PATH/$TARGET_BIN_NAME
PLACEHOLDER_FILE=$BIN_PATH/Kakangkuh
mkdir -p $BIN_PATH
[ -f "$PLACEHOLDER_FILE" ] && rm -f "$PLACEHOLDER_FILE"

ARCH=$(getprop ro.product.cpu.abi)
if [[ "$ARCH" == *"arm64"* ]]; then
  ui_print "- Detected 64-bit ARM architecture ($ARCH)"
  SOURCE_BIN=$MODPATH/HamadaAI/hamadaAI_arm64
else
  ui_print "- Detected 32-bit ARM architecture or other ($ARCH)"
  SOURCE_BIN=$MODPATH/HamadaAI/hamadaAI_arm32
fi

if [ -f "$SOURCE_BIN" ]; then
  ui_print "- Installing HamadaAI binary..."
  mv "$SOURCE_BIN" "$TARGET_BIN_PATH" >/dev/null 2>&1 || abort "! Failed to move HamadaAI binary"
  set_perm $TARGET_BIN_PATH 0 0 0755
else
  ui_print "! ERROR: Source binary not found at $SOURCE_BIN"
  abort "! Aborting installation."
fi

ui_print "- Cleaning up installation files..."
rm -rf "$MODPATH/HamadaAI"