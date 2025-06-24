#!/bin/sh
echo "Content-Type: application/json"
echo ""

ENABLED=$(echo "$QUERY_STRING" | grep -o 'enable=[01]' | cut -d= -f2)
ENABLE_ACL=$(echo "$QUERY_STRING" | grep -o 'acl_enable=[01]' | cut -d= -f2)

if [ "$ENABLED" = "1" ]; then
  uci set passwall2.@global[0].enabled='1'
elif [ "$ENABLED" = "0" ]; then
  uci set passwall2.@global[0].enabled='0'
fi

if [ "$ENABLE_ACL" = "1" ]; then
  uci set passwall2.@global[0].acl_enable='1'
elif [ "$ENABLE_ACL" = "0" ]; then
  uci set passwall2.@global[0].acl_enable='0'
fi

uci commit passwall2
/etc/init.d/passwall2 restart

echo "{\"status\":\"ok\",\"passwall_enabled\":\"$ENABLED\",\"acl_enabled\":\"$ENABLE_ACL\"}"
exit 0
