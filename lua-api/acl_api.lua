#!/usr/bin/lua

local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"
local fs = require "nixio.fs"

-- Hàm trả JSON
local function json_out(tbl)
  print("Content-Type: application/json\n")
  print(json.stringify(tbl, true))
end

-- Lấy query string
local function get_param(name)
  local qs = os.getenv("QUERY_STRING") or ""
  return qs:match(name.."=([^&]*)")
end

local action = get_param("action") or "list"

-- Lấy danh sách ACL thực tế
local function get_acl_list()
  local result = {}
uci:foreach("passwall2", "acl_rule", function(s)
      local routing_type = "-"
    if s.remote_fakedns == "1" then
      routing_type = "WebRTC"
    elseif s.remote_dns_protocol == "doh" then
      routing_type = "DoH"
    elseif s.remote_dns_protocol == "udp" then
      routing_type = "DNS UDP"
    end
  table.insert(result, {
    id = s[".name"],
    enabled = (s.enabled == "1"),
    remarks = s.remarks,
    sources = (s.sources and (s.sources):gmatch("%S+")) and (function(str) local t = {}; for v in (s.sources):gmatch("%S+") do table.insert(t, v) end; return t end)() or {},
    target = s.node,
    action = s.action or s.tcp_redir_port,
    write_ipset_direct = s.write_ipset_direct,
    remote_fakedns = s.remote_fakedns,
    remote_dns_protocol = s.remote_dns_protocol,
    remote_dns_doh = s.remote_dns_doh,
    remote_dns = s.remote_dns,
    remote_dns_detour = s.remote_dns_detour,
    remote_dns_query_strategy = s.remote_dns_query_strategy,
    dns_hosts = s.dns_hosts,
    tcp_no_redir_ports = s.tcp_no_redir_ports,
    udp_no_redir_ports = s.udp_no_redir_ports,
    tcp_redir_ports = s.tcp_redir_ports,
    udp_redir_ports = s.udp_redir_ports,
    routing_type = routing_type
  })
end)
  return result
end

-- Đọc dữ liệu POST
local function read_body()
  local len = tonumber(os.getenv("CONTENT_LENGTH") or 0)
  if len > 0 then
    local body = io.read(len)
    return json.parse(body)
  end
  return nil
end

if action == "list" then
  local data = get_acl_list()
  json_out(data)
  return
end

if action == "set_main_switch" then
  local input = read_body()
  local val = input.enabled and "1" or "0"
  local sid
  uci:foreach("passwall2", "global", function(s)
    sid = s[".name"]
  end)
  if sid then
    uci:set("passwall2", sid, "acl_enable", val)
    uci:commit("passwall2")
    json_out({success=true})
  else
    json_out({success=false, msg="Không tìm thấy section global"})
  end
  return
end

if action == "add" then
  local acl = read_body()
  if not acl then
    json_out({success=false, msg="Thiếu dữ liệu"})
    return
  end
  -- Sinh id mới (random, hoặc dùng thời gian/uuid)
  local id = os.time() .. math.random(100,999)
  local sid = uci:add("passwall2", "acl_rule")
  uci:set("passwall2", sid, "enabled", acl.enabled and "1" or "0")
  uci:set("passwall2", sid, "remarks", acl.remarks or "")
  uci:set("passwall2", sid, "sources", table.concat(acl.sources or {}, " "))
  uci:set("passwall2", sid, "node", acl.target or "")
  uci:set("passwall2", sid, "action", acl.action or "")
uci:set("passwall2", sid, "write_ipset_direct", acl.write_ipset_direct and "1" or "0")
uci:set("passwall2", sid, "remote_fakedns", acl.remote_fakedns and "1" or "0")
uci:set("passwall2", sid, "remote_dns_protocol", acl.remote_dns_protocol or "")
uci:set("passwall2", sid, "remote_dns_doh", acl.remote_dns_doh or "")
uci:set("passwall2", sid, "remote_dns", acl.remote_dns or "")
uci:set("passwall2", sid, "remote_dns_detour", acl.remote_dns_detour or "")
uci:set("passwall2", sid, "remote_dns_query_strategy", acl.remote_dns_query_strategy or "")
uci:set("passwall2", sid, "dns_hosts", acl.dns_hosts or "")
uci:set("passwall2", sid, "tcp_no_redir_ports", acl.tcp_no_redir_ports or "")
uci:set("passwall2", sid, "udp_no_redir_ports", acl.udp_no_redir_ports or "")
uci:set("passwall2", sid, "tcp_redir_ports", acl.tcp_redir_ports or "")
uci:set("passwall2", sid, "udp_redir_ports", acl.udp_redir_ports or "")
  -- (Bạn có thể bổ sung thêm field khác nếu muốn)
  uci:commit("passwall2")
  json_out({success=true, id=sid})
  return
end
if action == "edit" then
  local acl = read_body()
  if not acl or not acl.id then
    json_out({success=false, msg="Thiếu id"})
    return
  end
  local sid = acl.id
  uci:set("passwall2", sid, "enabled", acl.enabled and "1" or "0")
  uci:set("passwall2", sid, "remarks", acl.remarks or "")
  uci:set("passwall2", sid, "sources", table.concat(acl.sources or {}, " "))
  uci:set("passwall2", sid, "node", acl.target or "")
  uci:set("passwall2", sid, "action", acl.action or "")
  uci:set("passwall2", sid, "write_ipset_direct", acl.write_ipset_direct and "1" or "0")
  uci:set("passwall2", sid, "remote_fakedns", acl.remote_fakedns and "1" or "0")
  uci:set("passwall2", sid, "remote_dns_protocol", acl.remote_dns_protocol or "")
  uci:set("passwall2", sid, "remote_dns_doh", acl.remote_dns_doh or "")
  uci:set("passwall2", sid, "remote_dns", acl.remote_dns or "")
  uci:set("passwall2", sid, "remote_dns_detour", acl.remote_dns_detour or "")
  uci:set("passwall2", sid, "remote_dns_query_strategy", acl.remote_dns_query_strategy or "")
  uci:set("passwall2", sid, "dns_hosts", acl.dns_hosts or "")
  uci:set("passwall2", sid, "tcp_no_redir_ports", acl.tcp_no_redir_ports or "")
  uci:set("passwall2", sid, "udp_no_redir_ports", acl.udp_no_redir_ports or "")
  uci:set("passwall2", sid, "tcp_redir_ports", acl.tcp_redir_ports or "")
  uci:set("passwall2", sid, "udp_redir_ports", acl.udp_redir_ports or "")
  uci:commit("passwall2")
  json_out({success=true})
  return
end
if action == "delete" then
  local acl = read_body()
  if not acl or not acl.id then
    json_out({status="error", msg="Thiếu id"})
    return
  end
  uci:delete("passwall2", acl.id)
  uci:commit("passwall2")
  json_out({status="ok"})
  return
end

json_out({success=false, msg="API không hợp lệ!"})
