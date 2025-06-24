#!/bin/sh

echo "Content-Type: application/json"
echo ""

# Giải mã query string
for param in $(echo "$QUERY_STRING" | tr '&' '\n'); do
  key=$(echo "$param" | cut -d= -f1)
  value=$(echo "$param" | cut -d= -f2-)
  value=$(printf "%b" "${value//%/\\x}") # URL decode

  case "$key" in
    oldAlias) OLD_ALIAS="$value" ;;
    alias) ALIAS="$value" ;;
    remarks) REMARKS="$value" ;;
    protocol) PROTOCOL="$value" ;;
    ip) IP="$value" ;;
    port) PORT="$value" ;;
    username) USERNAME="$value" ;;
    password) PASSWORD="$value" ;;
  esac
done

# Nếu thêm mới, alias là remarks (tên section)
if [ -z "$ALIAS" ] && [ -n "$OLD_ALIAS" ]; then
  ALIAS="$OLD_ALIAS"
fi

SECTION="$ALIAS"

# Kiểm tra tối thiểu
if [ -z "$PROTOCOL" ] || [ -z "$IP" ] || [ -z "$PORT" ]; then
  echo '{ "success": false, "error": "Thiếu tham số bắt buộc (protocol, ip, port)" }'
  exit 1
fi

# Nếu sửa đổi tên alias
if [ -n "$OLD_ALIAS" ] && [ "$OLD_ALIAS" != "$ALIAS" ]; then
  if uci get passwall2."$OLD_ALIAS" >/dev/null 2>&1; then
    uci rename passwall2."$OLD_ALIAS"="$ALIAS"
  fi
fi

# Tạo mới section nếu chưa có
uci set passwall2."$SECTION"=nodes

# Gán remarks nếu chưa có
if [ -z "$REMARKS" ]; then
  i=1
  while uci show passwall2 | grep -q "remarks='proxy$i'"; do
    i=$((i + 1))
  done
  REMARKS="proxy$i"
fi

uci set passwall2."$SECTION".remarks="${REMARKS:-$IP}"
uci set passwall2."$SECTION".type="Xray"
uci set passwall2."$SECTION".protocol="$(echo "$PROTOCOL" | tr 'A-Z' 'a-z')"
uci set passwall2."$SECTION".address="$IP"
uci set passwall2."$SECTION".port="$PORT"

[ -n "$USERNAME" ] && uci set passwall2."$SECTION".username="$USERNAME" || uci delete passwall2."$SECTION".username 2>/dev/null
[ -n "$PASSWORD" ] && uci set passwall2."$SECTION".password="$PASSWORD" || uci delete passwall2."$SECTION".password 2>/dev/null

uci set passwall2."$SECTION".tls="0"
uci set passwall2."$SECTION".tcpMptcp="0"
uci set passwall2."$SECTION".tcpNoDelay="0"

uci commit passwall2

echo "{\"success\": true, \"alias\": \"$ALIAS\"}"
