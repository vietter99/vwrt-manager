#!/bin/sh
echo "Content-Type: application/json"
echo ""

# Lấy band từ query string (ví dụ: ?band=2.4G hoặc ?band=5G)
band=""
if echo "$QUERY_STRING" | grep -q 'band=5G'; then
  band="5G"
elif echo "$QUERY_STRING" | grep -q 'band=2.4G'; then
  band="2.4G"
fi

first=1
echo -n '{"channels":['

for phy in $(ls /sys/class/ieee80211/); do
  iwinfo $phy freqlist 2>/dev/null | grep -Eo '([0-9]+\.[0-9]+) GHz.*Channel [0-9]+' | awk '{print $1,$NF}'
done | while read freq ch; do
  if [ "$band" = "5G" ] && [ "$ch" -ge 36 ]; then
    [ $first -eq 1 ] && first=0 || echo -n ','
    echo -n "{\"ch\":$ch,\"freq\":\"$freq\"}"
  elif [ "$band" = "2.4G" ] && [ "$ch" -ge 1 ] && [ "$ch" -le 14 ]; then
    [ $first -eq 1 ] && first=0 || echo -n ','
    echo -n "{\"ch\":$ch,\"freq\":\"$freq\"}"
  fi
done

echo ']}'
