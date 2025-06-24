print("Content-Type: application/json\n")
local function get_mac(ifname)
  local f = io.open("/sys/class/net/" .. ifname .. "/address")
  if not f then return "" end
  local mac = f:read("*l") or ""
  f:close()
  return mac
end

local mac = get_mac("eth0")
print('{"mac": "' .. mac .. '"}')
