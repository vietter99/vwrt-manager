#!/bin/sh
echo "Content-Type: application/json; charset=utf-8"
echo ""

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Redirect toàn bộ output của script về null (CHẮN DỨT ĐIỂM)
exec 3>&1 4>&2
exec 1>/dev/null 2>/dev/null

POST_DATA="$(cat)"
# echo "RUN: $(date) POST_DATA=[$POST_DATA]" >> /tmp/wifi-debug.txt

get_json() { echo "$POST_DATA" | jsonfilter -e "$1"; }

ssid=$(get_json '@.ssid')
key=$(get_json '@.key')
band=$(get_json '@.band')
mac=$(get_json '@.mac')
channel=$(get_json '@.channel')
encryption=$(get_json '@.encryption')
mode=$(get_json '@.opmode')
width=$(get_json '@.width')
interface=$(get_json '@.interface')
old_ssid=$(get_json '@.oldSSID')

if [ -z "$ssid" ]; then
  exec 1>&3 2>&4
  echo '{"status":"error","error":"SSID không hợp lệ"}'
  exit 0
fi

# -- Block DUY NHẤT xác định iface, ƯU TIÊN tìm theo old_ssid để sửa --
iface=""

# Nếu có old_ssid (đổi tên), ưu tiên tìm section theo tên cũ
if [ -n "$old_ssid" ]; then
  for cfg in $(uci show wireless | grep '=wifi-iface' | cut -d. -f2 | cut -d= -f1); do
    this_ssid=$(uci -q get wireless.$cfg.ssid)
    if [ "$this_ssid" = "$old_ssid" ]; then
      iface="$cfg"
      break
    fi
  done
fi

# Nếu không có old_ssid hoặc không tìm thấy, thử tìm theo ssid mới
if [ -z "$iface" ]; then
  for cfg in $(uci show wireless | grep '=wifi-iface' | cut -d. -f2 | cut -d= -f1); do
    this_ssid=$(uci -q get wireless.$cfg.ssid)
    if [ "$this_ssid" = "$ssid" ]; then
      iface="$cfg"
      break
    fi
  done
fi

# Nếu vẫn không có, thì tạo mới
if [ -z "$iface" ]; then
  index=1
  while uci get wireless.proxy$index 2>/dev/null; do
    index=$((index+1))
  done
  iface="proxy$index"
  uci set wireless.$iface="wifi-iface"
fi

# Tìm device radio theo band
device=""
for d in $(uci show wireless | grep "=wifi-device" | cut -d'.' -f2 | cut -d'=' -f1); do
  dev_band=$(uci get wireless.$d.band 2>/dev/null)
  if [ "$band" = "5GHz" ] && ( [ "$dev_band" = "5g" ] || [ "$dev_band" = "5G" ] ); then
    device="$d"
    break
  fi
  if [ "$band" = "2.4GHz" ] && ( [ "$dev_band" = "2.4g" ] || [ "$dev_band" = "2.4G" ] ); then
    device="$d"
    break
  fi
done

# Fallback nếu không tìm được
if [ -z "$device" ]; then
  for p in $(ls /sys/class/ieee80211/); do
    freq=$(iw dev | grep -A10 $p | grep -oE 'channel [0-9]+ \(([0-9]+) MHz\)' | grep -oE '[0-9]+' | head -n1)
    if [ "$band" = "5GHz" ] && [ -n "$freq" ] && [ "$freq" -ge 4900 ]; then
      phy=$p
      break
    fi
    if [ "$band" = "2.4GHz" ] && [ -n "$freq" ] && [ "$freq" -lt 4900 ]; then
      phy=$p
      break
    fi
  done
  [ -z "$phy" ] && phy=$(ls /sys/class/ieee80211/ | head -n1)
  phy_index=$(echo "$phy" | sed 's/[^0-9]//g')
  device="radio${phy_index}"
fi

uci set wireless.$iface.device="$device"
uci set wireless.$iface.network="$interface"
uci set wireless.$iface.mode="ap"
uci set wireless.$iface.ssid="$ssid"
uci set wireless.$iface.encryption="$encryption"

if [ "$encryption" != "none" ] && [ "$encryption" != "owe" ] && [ -n "$key" ]; then
  uci set wireless.$iface.key="$key"
else
  uci delete wireless.$iface.key
fi

[ -n "$mac" ] && uci set wireless.$iface.macaddr="$mac"
[ -n "$channel" ] && [ "$channel" != "0" ] && uci set wireless.$device.channel="$channel"

# Xác định htmode
htmode=""
case "$width" in
  20) htmode="HT20";;
  40) htmode="HT40";;
  80) htmode="VHT80";;
  160) htmode="VHT160";;
esac

if [ "$mode" = "ax" ]; then
  [ "$width" = "20" ] && htmode="HE20"
  [ "$width" = "40" ] && htmode="HE40"
  [ "$width" = "80" ] && htmode="HE80"
  [ "$width" = "160" ] && htmode="HE160"
fi
if [ "$mode" = "ac" ]; then
  [ "$width" = "80" ] && htmode="VHT80"
  [ "$width" = "160" ] && htmode="VHT160"
fi

if ! uci get wireless.$device 2>/dev/null; then
  uci set wireless.$device="wifi-device"
  uci set wireless.$device.type="mac80211"
  # Không set phy/band ở đây nếu đã có
fi

# Chuyển interface name như br-lan về config name như lan
uci_interface=""
for name in $(uci show network | grep "=interface" | cut -d. -f2 | cut -d= -f1); do
  ifname=$(uci -q get network.$name.ifname)
  [ "$ifname" = "$interface" ] && uci_interface="$name" && break
done

[ -z "$uci_interface" ] && uci_interface="$interface"
uci set wireless.$iface.network="$uci_interface"

[ -n "$htmode" ] && uci set wireless.$device.htmode="$htmode"

uci commit wireless
(wifi reload &)  # reload nền

# Trả kết quả JSON Duy Nhất
exec 1>&3 2>&4
echo '{"status":"ok"}'
