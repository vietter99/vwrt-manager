#!/usr/bin/lua
local json = require "luci.jsonc"
local input = io.read("*a")
local data = json.parse(input or "")

print("Content-Type: application/json\n")

if data and data.token then
  local f = io.open("/etc/vwrt_token", "w")
  if f then
    f:write(data.token)
    f:close()
    print('{"status":"ok"}')
    return
  end
end

print('{"status":"fail"}')
