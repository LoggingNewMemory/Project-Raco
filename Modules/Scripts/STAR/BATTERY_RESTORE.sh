###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
###################################

cmd power set-mode 0 > /dev/null 2>&1
cmd power set-adaptive-power-saver-enabled false > /dev/null 2>&1
cmd power thermalservice override-status 0 > /dev/null 2>&1
settings delete global battery_saver_constants > /dev/null 2>&1