#!/bin/sh
if pm list packages | grep -q "webui"; then
	am start -n io.github.a13e300.ksuwebui/.WebUIActivity --es id "PingPimp"
else
	echo "KSU WebUI Standalone is not installed"
fi
