#!/bin/sh
echo "Content-type: application/json"
echo ""
SSID=$(echo "$QUERY_STRING" | sed -n 's/^ssid=\(.*\)/\1/p')
if [ -n "$SSID" ]; then
  # Tìm section có SSID này
  SECTION=$(uci show wireless | grep "ssid='$SSID'" | cut -d. -f2 | cut -d= -f1)
  if [ -n "$SECTION" ]; then
    uci delete wireless."$SECTION"
    uci commit wireless
    /etc/init.d/network reload
    echo '{"status":"success","ssid":"'"$SSID"'"}'
    exit 0
  fi
fi
echo '{"status":"error","message":"SSID không tồn tại"}'
