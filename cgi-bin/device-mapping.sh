#!/bin/sh

echo "Content-Type: application/json"
echo ""

echo "{"
echo "\"interfaces\": ["

# 🔍 Lấy danh sách interface thuộc firewall zone 'lan'
lan_interfaces=$(uci show firewall | grep "=zone" | cut -d'[' -f2 | cut -d']' -f1 | while read -r idx; do
  name=$(uci get firewall.@zone[$idx].name 2>/dev/null)
  [ "$name" = "lan" ] && uci get firewall.@zone[$idx].network
done)

first_entry=1

for section in $(uci show network | grep '=interface' | cut -d. -f2 | cut -d= -f1); do
  # ❌ Bỏ qua interface không thuộc zone LAN
  if ! echo "$lan_interfaces" | grep -qw "$section"; then
    continue
  fi

  human_readable() {
    size=$1
    if [ "$size" -ge 1073741824 ]; then
      echo "$(awk "BEGIN {printf \"%.1f GB\", $size/1073741824}")"
    elif [ "$size" -ge 1048576 ]; then
      echo "$(awk "BEGIN {printf \"%.1f MB\", $size/1048576}")"
    elif [ "$size" -ge 1024 ]; then
      echo "$(awk "BEGIN {printf \"%.1f KB\", $size/1024}")"
    else
      echo "${size} B"
    fi
  }

  device=$(uci get network.$section.device 2>/dev/null)
  ipaddr=$(uci get network.$section.ipaddr 2>/dev/null)
  [ -z "$device" ] && continue

  mac=$(cat /sys/class/net/$device/address 2>/dev/null)
  rx_bytes=$(cat /sys/class/net/$device/statistics/rx_bytes 2>/dev/null)
  tx_bytes=$(cat /sys/class/net/$device/statistics/tx_bytes 2>/dev/null)

  rx=$(human_readable $rx_bytes)
  tx=$(human_readable $tx_bytes)

  # ✅ Tính subnet dạng /24 để khớp với ACL
  subnet=$(echo "$ipaddr" | awk -F. '{printf "%s.%s.%s.0/24", $1,$2,$3}')
  proxy=$(uci show passwall2 | grep "sources='${subnet}'" | cut -d. -f2 | while read -r s; do
    uci get passwall2.$s.node 2>/dev/null
  done)

neigh_output=$(ip neigh show dev "$device" | grep -E 'REACHABLE|DELAY' | grep -v 'FAILED' | grep -v 'fe80::')

  [ $first_entry -eq 0 ] && echo ","
  first_entry=0

  echo "  {"
  echo "    \"iface\": \"$device\","
  echo "    \"interface\": \"$section\","
  echo "    \"ip\": \"$ipaddr\","
  echo "    \"mac\": \"$mac\","
  echo "    \"rx\": \"$rx\","
  echo "    \"tx\": \"$tx\","
  echo "    \"proxy\": \"$proxy\","
  echo "    \"status\": \"connected\","
  echo "    \"devices\": ["

  count=0
  while read -r ip _ mac _; do
    hostname=$(awk -v ip="$ip" '$3 == ip { print $4 }' /tmp/dhcp.leases)
    [ -z "$hostname" ] && hostname="*"

    wifi_ssid=""
    for wlan in $(iw dev | awk '/Interface/ {print $2}'); do
      iw dev "$wlan" station dump 2>/dev/null | grep -iq "$mac" && {
        wifi_ssid=$(iw dev "$wlan" info | awk -F'ssid ' '/ssid / {print $2}')
        break
      }
    done

    lan_iface=""
    [ -z "$wifi_ssid" ] && lan_iface="$device"

    [ $count -gt 0 ] && echo ","
    echo "      { \"hostname\": \"$hostname\", \"ip\": \"$ip\", \"mac\": \"$mac\", \"wifi\": \"$wifi_ssid\", \"lan\": \"$lan_iface\" }"
    count=$((count + 1))
  done <<EOF
$neigh_output
EOF

  echo "    ]"
  echo "  }"
done

echo "],"

# 📶 Thêm danh sách WiFi đang phát
echo "\"wifi\": ["
first=1
for cfg in $(uci show wireless | grep '=wifi-iface' | cut -d. -f2 | cut -d= -f1); do
  ssid=$(uci -q get wireless.$cfg.ssid)
  network=$(uci -q get wireless.$cfg.network)
  ifname=$(uci -q get wireless.$cfg.ifname)

  # Lấy IP nếu có
  ip=$(ip -4 addr show dev "$ifname" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
  [ -z "$ip" ] && ip="0.0.0.0"

  [ -n "$ssid" ] || continue

  [ "$first" -eq 0 ] && echo ","
  first=0

  key=$(uci -q get wireless.$cfg.key)
  encryption=$(uci -q get wireless.$cfg.encryption)
  device=$(uci -q get wireless.$cfg.device)
  band=$(uci -q get wireless.$device.band)
  channel=$(uci -q get wireless.$device.channel)
  opmode=$(uci -q get wireless.$cfg.mode)
  width=$(uci -q get wireless.$device.htmode)
  mac=$(uci -q get wireless.$cfg.macaddr)
  
  # --- Thêm trường enabled ---
  disabled=$(uci -q get wireless.$cfg.disabled)
  if [ "$disabled" = "1" ]; then
    enabled="false"
  else
    enabled="true"
  fi

  echo -n "  {\"ssid\": \"$ssid\", \"network\": \"$network\", \"ifname\": \"$ifname\", \"ip\": \"$ip\", \"key\": \"$key\", \"encryption\": \"$encryption\", \"band\": \"$band\", \"channel\": \"$channel\", \"opmode\": \"$opmode\", \"width\": \"$width\", \"mac\": \"$mac\", \"enabled\": $enabled}"
done
echo "]"
echo "}"
