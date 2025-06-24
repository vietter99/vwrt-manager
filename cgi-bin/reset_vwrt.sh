#!/bin/sh
echo "Content-Type: application/json"
echo ""

# Ví dụ: xóa config, khôi phục file mẫu
VWRT_CONFIG_DIR="/www/vwrt"
DEFAULT_CONFIG_DIR="/www/vwrt_default"

if [ -d "$DEFAULT_CONFIG_DIR" ]; then
  rm -rf "$VWRT_CONFIG_DIR"
  cp -r "$DEFAULT_CONFIG_DIR" "$VWRT_CONFIG_DIR"
  echo '{"status":"ok"}'
else
  echo '{"status":"error","msg":"Không tìm thấy cấu hình mặc định!"}'
fi
