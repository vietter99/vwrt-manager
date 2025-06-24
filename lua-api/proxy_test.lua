#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"

local function json_out(tbl)
  print("Content-Type: application/json\n")
  print(json.stringify(tbl, true))
end

local function get_param(name)
  local qs = os.getenv("QUERY_STRING") or ""
  return qs:match(name.."=([^&]*)")
end

local action = get_param("action") or ""
local id = get_param("id")

if not id then
  json_out({ success = false, msg = "Thiếu id" })
  return
end

-- Lấy info proxy từ passwall2 config
local ip = uci:get("passwall2", id, "address")
local port = uci:get("passwall2", id, "port")
local protocol = uci:get("passwall2", id, "protocol") or "http"
local username = uci:get("passwall2", id, "username")
local password = uci:get("passwall2", id, "password")

if not ip or not port then
  json_out({ success = false, msg = "Không tìm thấy IP/Port của node!" })
  return
end

-- Lọc lại cho an toàn (tránh code injection)
if not ip:match("^%d+%.%d+%.%d+%.%d+$") or not port:match("^%d+$") then
  json_out({ success = false, msg = "IP hoặc Port không hợp lệ!" })
  return
end

if action == "ping" then
  local f = io.popen("ping -c1 -W1 "..ip.." 2>&1")
  local out = f:read("*a")
  f:close()
  local ping = out:match("time=([%d%.]+) ms")
  if ping then
    json_out({ success = true, ping = ping.." ms" })
  else
    json_out({ success = false, msg = "Ping fail: "..out })
  end
  return
end

if action == "tcping" then
  local portnum = tonumber(port or "0")
  if not ip or not portnum or portnum < 1 then
    json_out({success=false, msg="IP hoặc port không hợp lệ!"})
    return
  end
  local cmd = string.format("nc %s %d < /dev/null 2>&1", ip, portnum)
  local f = io.popen(cmd)
  local out = f:read("*a") or ""
  f:close()
  if out:match("Connection refused") then
    json_out({success=false, msg="TCPing fail: Connection refused"})
  elseif out == "" then
    json_out({success=true, time="OK"})
  else
    json_out({success=false, msg="TCPing fail: " .. (out or "")})
  end
  return
end

if action == "urltest" then
  local url = "http://example.com"
  local cmd
  if protocol:match("socks") then
    if username and password then
      cmd = string.format("curl --socks5 %s:%s@%s:%s -m 4 -s %s", username, password, ip, port, url)
    else
      cmd = string.format("curl --socks5 %s:%s -m 4 -s %s", ip, port, url)
    end
  else -- http/https proxy
    if username and password then
      cmd = string.format("curl --proxy http://%s:%s@%s:%s -m 4 -s %s", username, password, ip, port, url)
    else
      cmd = string.format("curl --proxy http://%s:%s -m 4 -s %s", ip, port, url)
    end
  end

  local f = io.popen(cmd)
  local result = f:read("*a")
  f:close()
  if result and #result > 10 then
    json_out({ success = true })
  else
    json_out({ success = false, msg = "URL test fail: " .. (result or "") })
  end
  return
end

json_out({ success = false, msg = "API không hợp lệ!" })
