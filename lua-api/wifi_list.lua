#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"

-- Lấy danh sách interfaces thuộc firewall zone 'lan'
local lan_interfaces = {}
uci:foreach("firewall", "zone", function(s)
    if s.name == "lan" and s.network then
        for net in tostring(s.network):gmatch("%S+") do
            lan_interfaces[net] = true
        end
    end
end)

-- Đọc device statistics (rx/tx) + MAC
local function read_file(path)
    local f = io.open(path)
    if not f then return "" end
    local val = f:read("*l") or ""
    f:close()
    return val
end

local function human_readable(size)
    size = tonumber(size or 0)
    if size >= 1073741824 then
        return string.format("%.1f GB", size / 1073741824)
    elseif size >= 1048576 then
        return string.format("%.1f MB", size / 1048576)
    elseif size >= 1024 then
        return string.format("%.1f KB", size / 1024)
    else
        return tostring(size) .. " B"
    end
end

local interfaces = {}

uci:foreach("network", "interface", function(s)
    if not lan_interfaces[s[".name"]] then return end
    local device = s.device or s.ifname or ""
    if not device or device == "" then return end
    local ipaddr = s.ipaddr or ""
    local mac = read_file("/sys/class/net/"..device.."/address")
    local rx_bytes = read_file("/sys/class/net/"..device.."/statistics/rx_bytes")
    local tx_bytes = read_file("/sys/class/net/"..device.."/statistics/tx_bytes")
    local rx = human_readable(rx_bytes)
    local tx = human_readable(tx_bytes)

    -- Tính subnet dạng /24
    local subnet = ipaddr:match("^(%d+%.%d+%.%d+)%.%d+$")
    subnet = subnet and (subnet .. ".0/24") or ""
    local proxy = ""
    if subnet ~= "" then
        uci:foreach("passwall2", "acl", function(a)
            if tostring(a.sources or ""):find(subnet, 1, true) then
                proxy = a.node or ""
            end
        end)
    end

    -- Thiết bị đang kết nối (IP/MAC)
    local devices = {}
    local neigh = io.popen("ip neigh show dev "..device.." | grep -E 'REACHABLE|DELAY' | grep -v 'FAILED' | grep -v 'fe80::'")
    if neigh then
        for line in neigh:lines() do
            local ip, _, mac = line:match("^(%d+%.%d+%.%d+%.%d+)%s+dev%s+%S+%s+lladdr%s+([%x:]+)%s+")
            if ip and mac then
                table.insert(devices, {ip=ip, mac=mac})
            end
        end
        neigh:close()
    end

    table.insert(interfaces, {
        iface = device,
        interface = s[".name"],
        ip = ipaddr,
        mac = mac,
        rx = rx,
        tx = tx,
        proxy = proxy,
        status = "connected",
        devices = devices
    })
end)

-- Đọc toàn bộ map SSID -> {ifname, mac}
local function get_wifi_ifname_mac()
    local map = {}
    local f = io.popen("iw dev 2>/dev/null")
    if not f then return map end
    local ifname, mac, ssid
    for line in f:lines() do
        if line:match("^%s*Interface ") then
            ifname = line:match("Interface%s+([%w%-_]+)")
            mac, ssid = nil, nil
        elseif line:match("^%s*addr ") then
            mac = line:match("addr%s+([%x:]+)")
        elseif line:match("^%s*ssid ") then
            ssid = line:match("ssid%s+(.+)")
            if ifname and mac and ssid then
                map[ssid] = {ifname = ifname, mac = mac}
            end
        end
    end
    f:close()
    return map
end

local ifmap = get_wifi_ifname_mac()
local wifi = {}

uci:foreach("wireless", "wifi-iface", function(s)
    local ssid = s.ssid or ""
    if ssid == "" then return end

    local dev_name = s.device
    local dev = dev_name and uci:get_all("wireless", dev_name) or {}

    local disabled = tonumber(s.disabled or dev.disabled or 0)
    local enabled = (not disabled or disabled == 0) and true or false

    -- Map ifname và mac từ iw dev
    local ifinfo = ifmap[ssid] or {}
    local ifname = ifinfo.ifname or ""
    local mac = ifinfo.mac or ""

    -- Chuẩn hóa band
    local band = dev.band or ""
    if band == "2g" then band = "2.4GHz"
    elseif band == "5g" then band = "5GHz"
    end

    -- Lấy IP trên ifname
    local ip = ""
    if ifname ~= "" then
        local pip = io.popen("ip -4 addr show dev " .. ifname .. " 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1")
        ip = pip:read("*l") or ""
        pip:close()
    end

    table.insert(wifi, {
        band = band,
        ifname = ifname,
        ssid = ssid,
        encryption = s.encryption or "",
        opmode = s.mode or "",
        ip = ip,
        key = s.key or "",
        channel = dev.channel or "auto",
        network = s.network or "",
        width = dev.htmode or dev.vhtmode or dev.he_bss_color or "",
        mac = mac,
        enabled = enabled
    })
end)

print("Content-Type: application/json\n")
print(json.stringify({interfaces = interfaces, wifi = wifi}, true))
