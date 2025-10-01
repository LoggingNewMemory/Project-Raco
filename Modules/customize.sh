#!/system/bin/sh

copy_with_retry() {
  local SOURCE_FILE="$1"
  local DEST_PATH="$2"
  local FILE_NAME=$(basename "$SOURCE_FILE")
  local DEST_FILE="$DEST_PATH/$FILE_NAME"

  ui_print "- Copying $FILE_NAME..."
  for i in 1 2 3 4; do
    su -c cp -f "$SOURCE_FILE" "$DEST_PATH" >/dev/null 2>&1
    if [ -s "$DEST_FILE" ]; then
      ui_print "  ...Success."
      return 0
    fi
    if [ "$i" -lt 4 ]; then
      ui_print "  ...Failed. Retrying (Attempt $i/4)"
      sleep 1
    fi
  done

  ui_print "! CRITICAL: Failed to copy $FILE_NAME after 4 attempts."
  abort "! Aborting installation."
}

move_with_retry() {
  local SOURCE_FILE="$1"
  local DEST_FILE="$2"

  ui_print "- Moving $(basename "$SOURCE_FILE")..."
  for i in 1 2 3 4; do
    su -c mv -f "$SOURCE_FILE" "$DEST_FILE" >/dev/null 2>&1
    if [ -s "$DEST_FILE" ] && [ ! -f "$SOURCE_FILE" ]; then
      ui_print "  ...Success."
      return 0
    fi
    if [ "$i" -lt 4 ]; then
      ui_print "  ...Failed. Retrying (Attempt $i/4)"
      sleep 1
    fi
  done

  ui_print "! CRITICAL: Failed to move $(basename "$SOURCE_FILE") after 4 attempts."
  abort "! Aborting installation."
}

check_for_new_addons() {
  local new_config="$1"
  local saved_config="$2"
  
  # Get all INCLUDE keys from the new config
  new_keys=$(grep '^INCLUDE_' "$new_config" | cut -d'=' -f1)
  
  for key in $new_keys; do
    # Check if the key exists in the saved config
    if ! grep -q "^$key=" "$saved_config"; then
      ui_print "- New addon detected: $key"
      return 0 # 0 means true (new addons found)
    fi
  done
  
  return 1 # 1 means false (no new addons found)
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
ui_print "Version : CBT 6.3 REV"
ui_print " "
sleep 1.5

ui_print "      INSTALLING Project Raco       "
ui_print " "
sleep 1.5

ui_print "- Setting up module files..."
mkdir -p /data/ProjectRaco
unzip -o "$ZIPFILE" 'Scripts/*' -d $MODPATH >&2
copy_with_retry "$MODPATH/logo.png" "/data/local/tmp"
copy_with_retry "$MODPATH/Anya.png" "/data/local/tmp"

if [ -f "/data/ProjectRaco/game.txt" ]; then
    ui_print "- Existing game.txt found, preserving user settings."
else
    ui_print "- Performing first-time setup for game.txt."
    copy_with_retry "$MODPATH/game.txt" "/data/ProjectRaco"
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
  
  # NEW LOGIC: Check for new addons
  if check_for_new_addons "$RACO_MODULE_CONFIG" "$RACO_PERSIST_CONFIG"; then
    ui_print " "
    ui_print "! New Addon Available, Reconfigure?"
    ui_print " "
    ui_print "  Vol+ = Yes, Reconfigure"
    ui_print "  Vol- = No, use saved values"
    ui_print " "
    if choose; then
      ui_print "- User chose to reconfigure."
      # By doing nothing here, USE_SAVED_CONFIG remains false
      # and the script will proceed to the manual selection.
    else
      ui_print "- Using saved configuration and ignoring new addons."
      copy_with_retry "$RACO_PERSIST_CONFIG" "$MODPATH"
      USE_SAVED_CONFIG=true
    fi
  else
    # ORIGINAL LOGIC: No new addons found, ask to use saved config
    ui_print "  Do you want to use it?"
    ui_print " "
    ui_print "  Vol+ = Yes, use saved config"
    ui_print "  Vol- = No, choose again"
    ui_print " "
    if choose; then
      ui_print "- Using saved configuration."
      copy_with_retry "$RACO_PERSIST_CONFIG" "$MODPATH"
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
    copy_with_retry "$RACO_MODULE_CONFIG" "/data/ProjectRaco"
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

copy_with_retry "$MODPATH/ProjectRaco.apk" "/data/local/tmp"

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
  move_with_retry "$SOURCE_BIN" "$TARGET_BIN_PATH"

  ui_print "- Setting permissions for $TARGET_BIN_NAME"
  set_perm $TARGET_BIN_PATH 0 0 0755
else
  ui_print "! ERROR: Source binary not found at $SOURCE_BIN"
  abort "! Aborting installation."
fi

set_perm_recursive $MODPATH/system/lib/libncurses.so 0 0 0644 0644