#!/system/bin/sh
#
# All copy and move operations will now abort on failure.
#

check_for_config_changes() {
  local new_config="$1"
  local saved_config="$2"
  
  # This function extracts all configuration keys (e.g., "INCLUDE_ANYA", "SOC")
  # from both files, ignoring comments and section headers. It then compares the lists.
  # If the lists are different in any way (keys added or removed), it returns 0 (true).
  
  get_keys() {
    grep -vE '^#|^\[|^$' "$1" | cut -d'=' -f1
  }

  new_keys=$(get_keys "$new_config")
  saved_keys=$(get_keys "$saved_config")
  
  # diff will be silent and exit with 0 if files are identical.
  # If there is any difference, it will produce output and exit with 1.
  if ! diff <(echo "$new_keys" | sort) <(echo "$saved_keys" | sort) >/dev/null 2>&1; then
    ui_print "- Config file structure has changed."
    return 0 # 0 means true (changes detected)
  fi
  
  return 1 # 1 means false (no changes)
}

# FIX: New function to merge configs, preserving user values on upgrade.
merge_configs() {
  local new_config_default="$1" # The default raco.txt from the module zip
  local user_config_to_update="$2" # The user's saved raco.txt (/data/ProjectRaco/raco.txt)

  ui_print "- Merging new configuration options..."
  
  # Use a temporary file to avoid issues with reading and writing to the same file.
  local temp_file=$(mktemp)
  cp "$user_config_to_update" "$temp_file"

  # Read the default module config line by line
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments, section headers, and blank lines
    if [[ "$line" =~ ^# || "$line" =~ ^\[ || -z "$line" ]]; then
      continue
    fi
    
    # Extract the key (e.g., "INCLUDE_ANYA")
    key=$(echo "$line" | cut -d'=' -f1)
    
    # Check if the key already exists in the user's config
    # The grep uses `^${key}=` to ensure it matches the key at the start of the line precisely.
    if ! grep -q "^${key}=" "$temp_file"; then
      ui_print "  > Adding new option: $key"
      # If the key doesn't exist, append the entire line (key=value) to the user's config.
      echo "$line" >> "$temp_file"
    fi
  done < "$new_config_default"
  
  # Overwrite the original user config with the updated temporary file
  mv "$temp_file" "$user_config_to_update"
  ui_print "- Merge complete."
}


LATESTARTSERVICE=true
SOC=0
RACO_PERSIST_CONFIG="/data/ProjectRaco/raco.txt"

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
ui_print "Version : 7.0"
ui_print " "
sleep 1.5

ui_print "      INSTALLING Project Raco       "
ui_print " "
sleep 1.5

ui_print "- Setting up module files..."
mkdir -p /data/ProjectRaco
unzip -o "$ZIPFILE" 'Scripts/*' -d $MODPATH >&2

rm -f "/data/local/tmp/logo.png" >/dev/null 2>&1
ui_print "- Copying logo.png..."
cp "$MODPATH/logo.png" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy logo.png"

rm -f "/data/local/tmp/Anya.png" >/dev/null 2>&1
ui_print "- Copying Anya.png..."
cp "$MODPATH/Anya.png" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy Anya.png"

if [ -f "/data/ProjectRaco/game.txt" ]; then
    ui_print "- Existing game.txt found, preserving user settings."
else
    ui_print "- Performing first-time setup for game.txt."
    ui_print "- Copying game.txt..."
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

RACO_MODULE_CONFIG="$MODPATH/raco.txt"

ui_print "------------------------------------"
ui_print "      OPTIONAL ADDON SELECTION      "
ui_print "------------------------------------"
ui_print "- Extracting configuration file..."
unzip -o "$ZIPFILE" 'raco.txt' -d $MODPATH >&2

USE_SAVED_CONFIG=false
if [ -f "$RACO_PERSIST_CONFIG" ]; then
  ui_print " "
  ui_print "- Saved configuration found."
  
  if check_for_config_changes "$RACO_MODULE_CONFIG" "$RACO_PERSIST_CONFIG"; then
    ui_print " "
    ui_print "! New configuration options detected in module update."
    ui_print "! Your settings will be preserved and new options added."
    ui_print " "
    sleep 2
    
    merge_configs "$RACO_MODULE_CONFIG" "$RACO_PERSIST_CONFIG"
    
    ui_print "- Applying your updated configuration."
    cp "$RACO_PERSIST_CONFIG" "$RACO_MODULE_CONFIG" >/dev/null 2>&1 || abort "! Failed to apply updated configuration"
    USE_SAVED_CONFIG=true 

  else
    ui_print "  Do you want to use it?"
    ui_print " "
    ui_print "  Vol+ = Yes, use saved config"
    ui_print "  Vol- = No, choose again"
    ui_print " "
    if choose; then
      ui_print "- Using saved configuration."
      cp "$RACO_PERSIST_CONFIG" "$MODPATH" >/dev/null 2>&1 || abort "! Failed to copy saved configuration"
      USE_SAVED_CONFIG=true
    else
      ui_print "- Re-configuring addons."
    fi
  fi
fi

if [ "$USE_SAVED_CONFIG" = false ]; then
  ui_print " "
  ui_print "- Include Anya Thermal?"
  ui_print "Disable / Enable Thermal | Anya Flowstate"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_ANYA=1; ui_print "  > Yes"; else INCLUDE_ANYA=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Kobo Fast Charge?"
  ui_print "Fast Charging Add On"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_KOBO=1; ui_print "  > Yes"; else INCLUDE_KOBO=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Vestia Zeta Display?"
  ui_print "Maximize Screen Refresh Rate"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_ZETA=1; ui_print "  > Yes"; else INCLUDE_ZETA=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Sandevistan Boot?"
  ui_print "An Attempt to Make Boot Faster"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_SANDEV=1; ui_print "  > Yes"; else INCLUDE_SANDEV=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Updating module configuration..."
  sed -i "s/^INCLUDE_ANYA=.*/INCLUDE_ANYA=$INCLUDE_ANYA/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_KOBO=.*/INCLUDE_KOBO=$INCLUDE_KOBO/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_ZETA=.*/INCLUDE_ZETA=$INCLUDE_ZETA/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_SANDEV=.*/INCLUDE_SANDEV=$INCLUDE_SANDEV/" "$RACO_MODULE_CONFIG"
  ui_print "- Adding SOC Code ($SOC) to module config..."
  sed -i "s/^SOC=.*/SOC=$SOC/" "$RACO_MODULE_CONFIG"

  ui_print " "
  ui_print "- Save these choices for future installations?"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then
    ui_print "- Saving configuration for next time."
    cp "$RACO_MODULE_CONFIG" "/data/ProjectRaco" >/dev/null 2>&1 || abort "! Failed to save new configuration"
  else
    ui_print "- Choices will not be saved."
    [ -f "$RACO_PERSIST_CONFIG" ] && rm -f "$RACO_PERSIST_CONFIG"
  fi
fi

if [ -f "$RACO_MODULE_CONFIG" ]; then
    ui_print "- Finalizing SOC Code ($SOC) in raco.txt"
    sed -i "s/^SOC=.*/SOC=$SOC/" "$RACO_MODULE_CONFIG"
fi

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

if [ -f "$PLACEHOLDER_FILE" ]; then
  rm -f "$PLACEHOLDER_FILE"
fi

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
  ui_print "- Moving $(basename "$SOURCE_BIN")..."
  mv "$SOURCE_BIN" "$TARGET_BIN_PATH" >/dev/null 2>&1 || abort "! Failed to move HamadaAI binary"

  ui_print "- Setting permissions for $TARGET_BIN_NAME"
  set_perm $TARGET_BIN_PATH 0 0 0755
else
  ui_print "! ERROR: Source binary not found at $SOURCE_BIN"
  abort "! Aborting installation."
fi

set_perm_recursive $MODPATH/system/lib/libncurses.so 0 0 0644 0644
set_perm_recursive $MODPATH/system/etc/init/gpuservice.rc 0 0 0755 0755