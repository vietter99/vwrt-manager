#!/usr/bin/lua

local json = require "luci.jsonc"

-- Đọc POST data
local function read_body()
  local len = tonumber(os.getenv("CONTENT_LENGTH") or 0)
  if len > 0 then
    local body = io.read(len)
    return json.parse(body)
  end
  return nil
end

print("Content-Type: application/json\n")

local data = read_body()
local service = data and data.name

if not service or #service == 0 then
  print('{"status":"error","msg":"Thiếu tên dịch vụ"}')
  return
end

-- Thực thi lệnh restart
os.execute(string.format("/etc/init.d/%s restart", service))

print('{"status":"ok"}')
