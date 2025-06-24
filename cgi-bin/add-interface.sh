#!/bin/sh
# /cgi-bin/add-interface.sh

echo "Content-Type: application/json"
echo ""

# Đọc toàn bộ POST body
POST_DATA="$(cat)"

iface=$(echo "$POST_DATA" | jsonfilter -e '@.iface')
ipaddr=$(echo "$POST_DATA" | jsonfilter -e '@.ipaddr')
netmask=$(echo "$POST_DATA" | jsonfilter -e '@.netmask')
dns=$(echo "$POST_DATA" | jsonfilter -e '@.dns')
oldIface=$(echo "$POST_DATA" | jsonfilter -e '@.oldIface')

# Validate tên iface
if [ -n "$iface" ]; then
    echo "$iface" | grep -Eq '^[a-zA-Z0-9_-]+$'
    if [ $? -ne 0 ]; then
        echo '{"status":"error","error":"Tên interface không hợp lệ!"}'
        exit 0
    fi
    # Kiểm tra trùng tên khi tạo mới hoặc rename sang tên đã có
    if uci get network.$iface >/dev/null 2>&1; then
        if [ -z "$oldIface" ] || [ "$oldIface" != "$iface" ]; then
            echo '{"status":"error","error":"Tên interface đã tồn tại!"}'
            exit 0
        fi
    fi
    num=$(echo "$iface" | grep -o '[0-9]\+')
    [ -n "$num" ] && bridge="br-lan$num" || bridge="br-lan"
else
    index=1
    while uci get network.proxy$index >/dev/null 2>&1; do index=$((index+1)); done
    iface="proxy$index"
    bridge="br-lan$index"
    while uci get network.$bridge >/dev/null 2>&1; do
        index=$((index+1))
        bridge="br-lan$index"
        iface="proxy$index"
    done
fi

# Nếu là update (đổi tên), xoá cấu hình cũ
if [ -n "$oldIface" ] && [ "$oldIface" != "$iface" ]; then
    uci delete network.$oldIface >/dev/null 2>&1
    uci delete dhcp.$oldIface >/dev/null 2>&1
fi

# Khai báo bridge nếu chưa tồn tại
bridge_exists=0
for section in $(uci show network | grep "=device" | cut -d. -f2 | cut -d= -f1); do
    n=$(uci get network.$section.name 2>/dev/null)
    if [ "$n" = "$bridge" ]; then
        bridge_exists=1
        break
    fi
done

if [ "$bridge_exists" = "0" ]; then
    last_section=$(uci add network device 2>/dev/null)
    uci set network.$last_section.type="bridge" >/dev/null 2>&1
    uci set network.$last_section.name="$bridge" >/dev/null 2>&1
    uci set network.$last_section.bridge_empty="1" >/dev/null 2>&1
    uci set network.$last_section.description="Bridge device" >/dev/null 2>&1
fi

# Gán interface static IP
uci set network.$iface="interface" >/dev/null 2>&1
uci set network.$iface.proto="static" >/dev/null 2>&1
uci set network.$iface.device="$bridge" >/dev/null 2>&1
uci set network.$iface.ipaddr="$ipaddr" >/dev/null 2>&1
uci set network.$iface.netmask="$netmask" >/dev/null 2>&1
[ -n "$dns" ] && uci set network.$iface.dns="$dns" >/dev/null 2>&1

# Bật DHCP
uci set dhcp.$iface="dhcp" >/dev/null 2>&1
uci set dhcp.$iface.interface="$iface" >/dev/null 2>&1
uci set dhcp.$iface.start="2" >/dev/null 2>&1
uci set dhcp.$iface.limit="100" >/dev/null 2>&1
uci set dhcp.$iface.leasetime="12h" >/dev/null 2>&1

uci commit network >/dev/null 2>&1
uci commit dhcp >/dev/null 2>&1

ip link add name "$bridge" type bridge >/dev/null 2>&1
ip link set "$bridge" up >/dev/null 2>&1

/etc/init.d/network reload >/dev/null 2>&1
/etc/init.d/dnsmasq restart >/dev/null 2>&1

# Add interface vào zone lan nếu có
zone_idx=$(uci show firewall | grep "=zone" | awk -F'[][]' '{print $2}')
zone_lan=""
for idx in $zone_idx; do
    name=$(uci get firewall.@zone[$idx].name 2>/dev/null)
    [ "$name" = "lan" ] && zone_lan="@zone[$idx]" && break
done

if [ -n "$zone_lan" ]; then
    # Kiểm tra xem iface đã tồn tại trong danh sách chưa
    if ! uci get firewall.$zone_lan.network 2>/dev/null | grep -qw "$iface"; then
        uci add_list firewall.$zone_lan.network="$iface" >/dev/null 2>&1
        uci commit firewall >/dev/null 2>&1
        /etc/init.d/firewall reload >/dev/null 2>&1
    fi
fi

# CHỈ trả về 1 dòng JSON hợp lệ duy nhất
echo '{"status":"ok","bridge":"'$bridge'","iface":"'$iface'"}'
exit 0
