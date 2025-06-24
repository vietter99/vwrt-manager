#!/bin/sh
echo "Content-Type: application/json"
echo ""

REPO="vietter99/vwrt-manager"
DEST="/www/vwrt"
ZIP_URL="https://github.com/$REPO/archive/refs/heads/master.zip"
VERSION_URL="https://raw.githubusercontent.com/$REPO/master/VERSION"
OUT_ZIP="/tmp/vwrt.zip"
WORKDIR="/tmp/vwrt_update"

# Lấy phiên bản local
LOCAL_VER=$(cat "$DEST/VERSION" 2>/dev/null || echo "unknown")

# Lấy phiên bản mới nhất từ repo public
LATEST_VER=$(curl -s -f "$VERSION_URL" 2>/dev/null || echo "unknown")

# So sánh phiên bản
if [ "$LOCAL_VER" = "$LATEST_VER" ]; then
  echo '{"status":"skip","msg":"Đã là phiên bản mới nhất!","version":"'"$LOCAL_VER"'"}'
  exit 0
fi

# Dọn dẹp
rm -rf "$OUT_ZIP" "$WORKDIR"
mkdir -p "$WORKDIR"

# Tải zip về
curl -s -L -o "$OUT_ZIP" "$ZIP_URL"

# Kiểm tra zip hợp lệ
if ! unzip -tq "$OUT_ZIP" > /dev/null 2>&1; then
  echo '{"status":"error","msg":"Downloaded file is not a valid zip"}'
  exit 0
fi

# Xoá thư mục đích
rm -rf "$DEST"

# Giải nén
unzip -q "$OUT_ZIP" -d "$WORKDIR"

# Lấy thư mục con bên trong
FIRSTDIR=$(ls "$WORKDIR")
mv "$WORKDIR/$FIRSTDIR" "$DEST"

# Set quyền
chmod -R 755 "$DEST"

# Xoá file dev nếu có
rm -f "$DEST/vwrtdev.js"

# Dọn dẹp
rm -f "$OUT_ZIP"
rm -rf "$WORKDIR"

# Thêm cấu hình uhttpd nếu chưa có
UHTTPD_CONF="/etc/config/uhttpd"
if ! grep -q "config uhttpd 'vwrt'" "$UHTTPD_CONF"; then
cat >> "$UHTTPD_CONF" <<EOF

config uhttpd 'vwrt'
    option listen_http '0.0.0.0:2222'
    option home '/www/vwrt'
    option cgi_prefix '/cgi-bin'
    list interpreter '.sh=/bin/sh'
    list interpreter '.lua=/usr/bin/lua'
    option lua_prefix '/lua-api'
    option lua_handler '/usr/bin/lua'
    option script_timeout '60'
    option network_timeout '30'
    option max_requests '10'
    option max_connections '100'
    option tcp_keepalive '1'
    option ubus_prefix '/ubus'
EOF
fi

# Khởi động lại uhttpd để áp dụng config
/etc/init.d/uhttpd restart

# Trả kết quả
echo '{"status":"ok","msg":"Update & extract done","old_ver":"'"$LOCAL_VER"'","new_ver":"'"$LATEST_VER"'"}'
