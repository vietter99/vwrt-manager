#!/usr/bin/lua

local json = require "luci.jsonc"
local uci = require "luci.model.uci".cursor()

-- Đọc request body (POST)
local function get_post_json()
  local len = tonumber(os.getenv("CONTENT_LENGTH") or "0")
  if len < 1 then return {} end
  local body = io.read(len)
  return json.parse(body or "") or {}
end

-- Tìm section theo ssid (nếu có)
local function find_section_by_ssid(ssid)
  local f = io.popen("uci show wireless | grep '.ssid='")
  for line in f:lines() do
    local sect, val = line:match("wireless%.([^.]+)%.ssid='([^']+)'")
    if sect and val == ssid then
      f:close()
      return sect
    end
  end
  f:close()
  return nil
end

-- MAIN LOGIC
print("Content-Type: application/json\n")

local req = get_post_json()
local section = req.section
local ssid = req.ssid
local enabled = req.enabled
if enabled == nil then enabled = true end -- Mặc định bật

if not section and ssid then
  section = find_section_by_ssid(ssid)
end

if not section then
  print(json.stringify({success=false, error="Không tìm thấy section WiFi!"}))
  os.exit(0)
end

-- Bật/tắt WiFi
local ok1 = os.execute("uci set wireless."..section..".disabled="..(enabled and "0" or "1"))
local ok2 = os.execute("uci commit wireless")
local ok3 = os.execute("wifi reload >/dev/null 2>&1 &")

-- Đọc lại trạng thái thực tế sau khi thay đổi
local disabled = uci:get("wireless", section, "disabled")
local enabled_actual = (disabled ~= "1")

print(json.stringify({
  success = true,
  section = section,
  ssid = ssid or "",
  enabled = enabled_actual
}))
