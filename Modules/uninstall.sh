# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

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

rm -rf /data/local/tmp/logo.png
rm -rf /data/local/tmp/Anya.png
pm uninstall -k com.kanagawa.yamada.project.raco >/dev/null 2>&1
rm -rf /data/ProjectRaco

# Managed to read this? Thanks for using Project Raco
