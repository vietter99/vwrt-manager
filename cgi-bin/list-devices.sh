#!/bin/sh

echo "Content-Type: application/json"
echo ""

echo "["

first=1
used_mac=""

# Lấy danh sách IP-MAC từ ARP, lọc chỉ IPv4
ip neigh show | grep "lladdr" | awk '{print $1, $5}' | grep -Eo '^([0-9]{1,3}\.){3}[0-9]{1,3} [a-f0-9:]{17}$' | sort -u | while read ip mac; do
  # Bỏ nếu MAC đã xử lý rồi
  echo "$used_mac" | grep -q "$mac" && continue
  used_mac="$used_mac $mac"

  # hostname từ DHCP lease nếu có
  hostname=$(grep "$mac" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}')
  [ -z "$hostname" ] && hostname=""

  [ "$first" -eq 0 ] && echo ","
  first=0

  printf '{ "ip": "%s", "mac": "%s", "hostname": "%s" }' "$ip" "$mac" "$hostname"
done

echo "]"
