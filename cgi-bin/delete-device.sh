#!/bin/sh
echo "Content-Type: application/json"
echo ""

# Lấy iface từ QUERY_STRING
iface=$(echo "$QUERY_STRING" | sed -n 's/^.*iface=\([^&]*\).*$/\1/p')

if [ -z "$iface" ]; then
  echo '{ "status": "error", "message": "Thiếu iface" }'
  exit 1
fi

# Lấy tên proxy tương ứng từ UCI
proxy_name=$(uci show network | grep "device='$iface'" | cut -d. -f2)

if [ -z "$proxy_name" ]; then
  echo '{ "status": "error", "message": "Không tìm thấy cấu hình tương ứng" }'
  exit 1
fi

# Xoá cấu hình network và reload lại
uci delete network.$proxy_name
uci commit network
/etc/init.d/network reload >/dev/null 2>&1 &
# Optionally: xoá cả firewall nếu cần
# uci delete firewall.@zone[n].list.network='$proxy_name'
# uci commit firewall

echo "{ \"status\": \"success\", \"proxy\": \"$proxy_name\" }"
