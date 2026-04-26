#!/system/bin/sh

# ------------------------------------
# Configuration Functions
# ------------------------------------

merge_configs() {
  local new_template="$1"
  local persistent_config="$2"
  local temp_config="$MODPATH/raco.tmp"

  ui_print "- Merging your previous settings..."
  
  # 1. Start with the clean/tidy template
  cp "$new_template" "$temp_config"

  # 2. Read values from the old (potentially untidy) file. 
  # Now uses space as delimiter instead of '='
  while read -r key value || [ -n "$key" ]; do
    [[ "$key" =~ ^# ]] || [ -z "$key" ] && continue    
    
    # Escape special characters for sed
    local escaped_key=$(echo "$key" | sed -e 's/[]\/$*.^[]/\\&/g')
    
    # 3. Inject old values into the clean template
    if grep -q "^${escaped_key} " "$temp_config"; then
      sed -i "s/^${escaped_key} .*/${key} ${value}/" "$temp_config"
    fi
  done < "$persistent_config"

  # 4. Overwrite persistent file with the clean, updated version
  mv "$temp_config" "$persistent_config"
  ui_print "- Settings merged successfully."
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
  # Updated to check for space delimiter
  SAVED_SOC=$(grep '^SOC ' "$RACO_PERSIST_CONFIG" | awk '{print $2}')
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
    *Unisoc* | *unisoc* | *ums* | *UNISOC* | *sp* | *SC*) SOC=4 ;;
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
  [ $SOC -eq 0 ] && recognize_soc "$(grep "model|sname" /proc/cpuinfo | uniq | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
  [ $SOC -eq 0 ] && {
    ui_print "! Unable to detect your SoC (Chipset)."
    abort "! Installation cannot continue. Aborting."
  }
fi

ui_print "------------------------------------"
ui_print "            MODULE INFO             "
ui_print "------------------------------------"
ui_print "Name : Project Raco"
ui_print "Version : 6.0"
ui_print " "
sleep 1.5

ui_print "      INSTALLING Project Raco       "
ui_print " "
sleep 1.5

ui_print "- Setting up module files..."
unzip -o "$ZIPFILE" 'Compiled/*' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'CoreSys/*' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'Binaries/*' -d $MODPATH >&2
unzip -o "$ZIPFILE" 'raco.txt' -d $MODPATH >&2

# File copy operations
rm -f "/data/local/tmp/logo.png" >/dev/null 2>&1
cp "$MODPATH/logo.png" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy logo.png"
rm -f "/data/local/tmp/Anya.png" >/dev/null 2>&1
cp "$MODPATH/Anya.png" "/data/local/tmp" >/dev/null 2>&1 || abort "! Failed to copy Anya.png"

ui_print " "

# Set standard directory permissions
set_perm_recursive $MODPATH 0 0 0755 0755

# Apply 0755 execution permissions to the C binaries per diagram architecture
ui_print "- Setting executable permissions for binaries..."
set_perm_recursive "$MODPATH/Compiled" 0 0 0755 0755
set_perm_recursive "$MODPATH/CoreSys" 0 0 0755 0755
set_perm_recursive "$MODPATH/Binaries" 0 0 0755 0755

sleep 1.5

# --- Main Configuration Logic ---

if [ ! -f "$RACO_PERSIST_CONFIG" ]; then
  # Case 1: First-time installation.
  ui_print "- No previous configuration found."
  ui_print "- Creating default configuration..."
  cp "$RACO_MODULE_TEMPLATE" "$RACO_PERSIST_CONFIG"
else
  # Case 2: Existing installation.
  ui_print "- Saved configuration found."

  # FORCE MERGE: Always merge to ensure the latest file structure is applied
  merge_configs "$RACO_MODULE_TEMPLATE" "$RACO_PERSIST_CONFIG"
  
  ui_print "- Configuration updated with new structure."
fi

# Finalize by writing the detected SOC code to the persistent config (using space delimiter)
ui_print "- Finalizing SOC Code ($SOC) in config"
sed -i "s/^SOC .*/SOC $SOC/" "$RACO_PERSIST_CONFIG"

# Clean up the template file from the module directory.
rm -f "$RACO_MODULE_TEMPLATE"

ui_print " "
ui_print "   INSTALLING/UPDATING Project Raco App   "
ui_print " "

PACKAGE_NAME="com.kanagawa.yamada.project.raco"
ui_print "- Copying ProjectRaco.apk..."

# Soft check for APK copy to prevent installation failure
if cp "$MODPATH/ProjectRaco.apk" "/data/local/tmp" >/dev/null 2>&1; then
  ui_print "- Installing APK..."
  pm install --user 0 /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1

  if pm path "$PACKAGE_NAME" >/dev/null 2>&1; then
    ui_print "- Project Raco App installed/updated successfully."
  else
    ui_print "! WARNING: Installation of Project Raco App failed."
    ui_print "! Please unzip the module and install the APK manually."
  fi

  # Clean up APK file
  rm -f /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1
else
  ui_print "! WARNING: Failed to copy ProjectRaco.apk to temp directory."
  ui_print "! Please unzip the module and install the APK manually."
fi