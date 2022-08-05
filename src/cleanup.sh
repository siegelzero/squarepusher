#!/bin/bash
for f in "$@"
do
   cp "$f" /tmp/tmp.dat
   cat /tmp/tmp.dat | sort -u | sort -R | head -n 1000 > "$f"
done
