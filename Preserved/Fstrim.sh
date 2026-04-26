#!/bin/sh

for partition in data cache; do
    busybox fstrim -v "/$partition"
    sleep 0.1
done