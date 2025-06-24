#!/bin/sh

echo "Content-Type: application/json"
echo ""

echo "["

first=1

for section in $(uci show passwall2 2>/dev/null | grep '=nodes' | cut -d. -f2 | cut -d= -f1); do
  name=$(uci -q get passwall2.${section}.remarks)
  type=$(uci -q get passwall2.${section}.protocol)

  [ -z "$type" ] && continue

  # Escape chuỗi JSON bằng printf
  escaped_name=$(printf '%s' "$name" | sed 's/"/\\"/g')
  escaped_type=$(printf '%s' "$type" | sed 's/"/\\"/g')

  [ "$first" -eq 0 ] && echo ","
  first=0

  echo -n "{\"name\":\"$escaped_name\",\"type\":\"$escaped_type\"}"
done

echo "]"
