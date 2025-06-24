#!/bin/sh

# Set content type
echo "Content-Type: application/json"
echo ""

# IP Public
IP=$(curl -s --max-time 2 https://api.ipify.org || echo "0.0.0.0")

# Proxy Enabled (passwall2)
PROXY_ENABLED=$(uci get passwall2.@global[0].acl_enable 2>/dev/null || echo "0")

# Uptime (tách đẹp)
UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime)
YEARS=$((UPTIME_SEC/31536000))
MONTHS=$(( (UPTIME_SEC%31536000)/2592000 ))
DAYS=$(( (UPTIME_SEC%2592000)/86400 ))
HOURS=$(( (UPTIME_SEC%86400)/3600 ))
MINS=$(( (UPTIME_SEC%3600)/60 ))
SECS=$((UPTIME_SEC%60))
UPTIME_FORMAT=""
if [ $YEARS -gt 0 ]; then
  UPTIME_FORMAT="${YEARS} Năm "
fi
if [ $MONTHS -gt 0 ]; then
  UPTIME_FORMAT="${UPTIME_FORMAT}${MONTHS} Tháng "
fi
if [ $DAYS -gt 0 ]; then
  UPTIME_FORMAT="${UPTIME_FORMAT}${DAYS} Ngày "
fi
UPTIME_FORMAT="${UPTIME_FORMAT}${HOURS}:${MINS}:${SECS}"

# RAM
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERCENT=$((100 * MEM_USED / MEM_TOTAL))
MEM_CACHE=$(free -m | awk '/Mem:/ {print $6}')
MEM_BUFFER=$(free -m | awk '/Mem:/ {print $4}')

#ROM (LẤY KB)
ROM_TOTAL=$(df -k /overlay | awk 'NR==2 {print $2}')
ROM_USED=$(df -k /overlay | awk 'NR==2 {print $3}')
ROM_FREE=$(df -k /overlay | awk 'NR==2 {print $4}')
ROM_PERCENT=$(df -h /overlay | awk 'NR==2 {print $5}' | tr -d '%')

# Load Average
LOADAVG=$(cut -d ' ' -f1-3 /proc/loadavg)

# Hostname, model, version, IP WAN
KERNEL=$(uname -r)
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null)
MODEL=$(cat /tmp/sysinfo/model 2>/dev/null)
# IPWAN=$(ubus call network.interface.wan status 2>/dev/null | jsonfilter -e "@.ipv4_address[0].address")
VERSION=$(cat /etc/openwrt_version 2>/dev/null)

# proxy
PROXIES_JSON="["
NODES=$(uci show passwall2 | grep '=nodes' | cut -d'.' -f2 | cut -d'=' -f1)

for NODE_ID in $NODES; do
  ALIAS=$(uci get passwall2.$NODE_ID.remarks 2>/dev/null)
  [ -z "$ALIAS" ] && ALIAS="$NODE_ID"
  REMARKS=$(uci get passwall2.$NODE_ID.remarks 2>/dev/null)
  [ -z "$REMARKS" ] && REMARKS="$NODE_ID"
  USERNAME=$(uci get passwall2.$NODE_ID.username 2>/dev/null)
  PASSWORD=$(uci get passwall2.$NODE_ID.password 2>/dev/null)
  PROTOCOL=$(uci get passwall2.$NODE_ID.protocol 2>/dev/null)
  IP=$(uci get passwall2.$NODE_ID.address 2>/dev/null)
  PORT=$(uci get passwall2.$NODE_ID.port 2>/dev/null)

  PING_RESULT=$(ping -c1 -W1 "$IP" 2>/dev/null)
  if echo "$PING_RESULT" | grep -q "time="; then
    PING_TIME=$(echo "$PING_RESULT" | grep "time=" | sed -n 's/.*time=\([0-9.]*\).*/\1/p')
    PING_STATUS="online"
  else
    PING_TIME=""
    PING_STATUS="offline"
  fi

PROXIES_JSON="${PROXIES_JSON}{\"alias\":\"$ALIAS\",\"real_name\":\"$NODE_ID\",\"remarks\":\"$REMARKS\",\"ip\":\"$IP\",\"port\":\"$PORT\",\"protocol\":\"$PROTOCOL\",\"status\":\"$PING_STATUS\",\"ping\":\"$PING_TIME\",\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"},"
done

# Remove trailing comma
PROXIES_JSON=$(echo "$PROXIES_JSON" | sed 's/,\]$/]/' | sed 's/,$//')
PROXIES_JSON="$PROXIES_JSON]"
# Gọi device-mapping.sh và lưu kết quả vào biến
DEVICE_JSON=$(sh /www/cgi-bin/device-mapping.sh | sed '1d') # bỏ dòng Content-Type

# Output JSON
echo "{
  \"ip\": \"$IP\",
  \"proxy_enabled\": \"$PROXY_ENABLED\",
  \"uptime\": \"$UPTIME_FORMAT\",
  \"ram_used\": \"$MEM_USED\",
  \"ram_total\": \"$MEM_TOTAL\",
  \"ram_percent\": \"$MEM_PERCENT\",
  \"ram_buffer\": \"$MEM_BUFFER\",
  \"ram_cache\": \"$MEM_CACHE\",
  \"rom_total\": \"$ROM_TOTAL\",
  \"rom_used\": \"$ROM_USED\",
  \"rom_free\": \"$ROM_FREE\",
  \"rom_percent\": \"$ROM_PERCENT\",
  \"loadavg\": \"$LOADAVG\",
  \"hostname\": \"$HOSTNAME\",
  \"model\": \"$MODEL\",
  \"kernel\": \"$KERNEL\",
  \"version\": \"$VERSION\",
  \"proxies\": $PROXIES_JSON
}"


