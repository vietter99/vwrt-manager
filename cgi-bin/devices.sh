#!/bin/sh
echo "Content-Type: application/json"
echo ""

echo "["

first=1
while read -r lease_time mac ip hostname id; do
  # Xác định trạng thái kết nối
  status=$(ip neigh show "$ip" 2>/dev/null | awk '{ print $NF }')
  case "$status" in
    REACHABLE|STALE|DELAY) status="online" ;;
    *) status="offline" ;;
  esac
  [ -z "$status" ] && status="UNKNOWN"

  # Dò xem thiết bị có kết nối WiFi nào (gán luôn ssid)
  wifi_ssid=""
  for iface in $(iw dev | awk '/Interface/ {print $2}'); do
    if iw dev "$iface" station dump | grep -iq "$mac"; then
      wifi_ssid=$(iw dev "$iface" info | awk -F'ssid ' '/ssid / {print $2}')
      break
    fi
  done

  # Nếu không có wifi thì lấy interface đang giao tiếp (LAN)
  device_iface=""
  if [ -z "$wifi_ssid" ]; then
    device_iface=$(ip neigh show "$ip" 2>/dev/null | awk '{print $3}' | head -n1)
  fi

  [ "$first" -eq 0 ] && echo ","
  first=0
  echo "  {"
  echo "    \"ip\": \"$ip\","
  echo "    \"mac\": \"$mac\","
  echo "    \"hostname\": \"${hostname:-unknown}\","
  echo "    \"status\": \"$status\","
  echo "    \"wifi\": \"$wifi_ssid\","
  echo "    \"iface\": \"${device_iface:-}\""
  echo "  }"
done < /tmp/dhcp.leases

echo "]"
