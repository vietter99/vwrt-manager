#!/usr/bin/lua

print("Content-Type: application/json\n")
local json = require "luci.jsonc"

-- Đọc dữ liệu POST dạng form-urlencoded
local len = tonumber(os.getenv("CONTENT_LENGTH") or 0)
local data = ""
if len > 0 then
  data = io.read(len)
end

local port = tostring(data):match("port=([0-9]+)")
local new_port = tonumber(port)

if not new_port or new_port < 1 or new_port > 65535 then
  print(string.format('{"status":"error","msg":"Port không hợp lệ", "debug_port":"%s", "debug_body":"%s"}', tostring(port), data))
  return
end

-- Chỉ sửa block 'vwrt'
local uci = require "luci.model.uci".cursor()
uci:set("uhttpd", "vwrt", "listen_http", "0.0.0.0:"..new_port)
uci:commit("uhttpd")
os.execute("/etc/init.d/uhttpd restart &")
print('{"status":"ok"}')
