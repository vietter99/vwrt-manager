#!/usr/bin/lua
print("Content-Type: application/json\n")

local json = require "luci.jsonc"
local result = {}

local f = io.open("/etc/vwrt_token", "r")
if f then
  local token = f:read("*a")
  f:close()
  result.token = token
else
  result.token = nil
end

print(json.stringify(result))
