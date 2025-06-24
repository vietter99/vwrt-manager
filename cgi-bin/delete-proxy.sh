#!/bin/sh

echo "Content-Type: application/json"
echo ""

# Lấy alias từ query string, decode percent-encoding
ALIAS_RAW=$(echo "$QUERY_STRING" | tr '&' '\n' | awk -F= '$1=="alias"{print $2}')
ALIAS=$(printf '%b' "${ALIAS_RAW//%/\\x}")
ALIAS_CLEAN=$(echo "$ALIAS" | tr -d '\r\n' | sed 's/ *$//g')

if [ -z "$ALIAS_CLEAN" ]; then
  echo '{"status":"error","message":"Alias không hợp lệ hoặc rỗng"}'
  exit 1
fi

# Tìm section nodes có tên alias đó
KEY=""
for k in $(uci show passwall2 | grep "=nodes" | cut -d'.' -f2 | cut -d'=' -f1); do
  if [ "$k" = "$ALIAS_CLEAN" ]; then
    KEY=$k
    break
  fi
done

if [ -z "$KEY" ]; then
  echo "{\"status\":\"error\",\"message\":\"Không tìm thấy section tên '$ALIAS_CLEAN'\"}"
  exit 1
fi

# Xoá section và commit
uci delete passwall2."$KEY"
uci commit passwall2

ESCAPED_ALIAS=$(printf "%s" "$ALIAS_CLEAN" | sed 's/\\/\\\\/g; s/"/\\"/g')

echo "{\"status\":\"ok\",\"message\":\"Đã xoá section '$ESCAPED_ALIAS'\"}"
exit 0
