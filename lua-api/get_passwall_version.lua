#!/usr/bin/lua
local json = require "luci.jsonc"

local function get_passwall_version()
  local pipe = io.popen("PATH=/usr/sbin:/usr/bin:/sbin:/bin opkg list-installed | grep luci-app-passwall2")
  if not pipe then return "-" end
  local output = pipe:read("*a")
  pipe:close()

for line in output:gmatch("[^\r\n]+") do
    local version = line:match("luci%-app%-passwall2%s%-%s*([%d%.%-]+)")
    if version then
      return version
    end
end

  return "-"
end

local version = get_passwall_version()

print("Content-Type: application/json\n")
print(json.stringify({ version = version }))
