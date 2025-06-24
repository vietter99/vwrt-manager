#!/bin/sh
printf 'Content-Type: application/json\n\n'
sleep 1 && (/etc/init.d/passwall2 restart >/dev/null 2>&1) & 
echo '{ "success": true }'