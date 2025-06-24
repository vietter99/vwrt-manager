#!/usr/bin/lua

local json = require "luci.jsonc"
local uci = require "luci.model.uci".cursor()
print("Content-Type: application/json\n")

-- Đọc dữ liệu POST (body)
local input = io.read("*a")
local acl = json.parse(input)

if not acl or not acl.remarks or #acl.remarks == 0 then
  print(json.stringify({status="error", msg="Thiếu tên ACL"}))
  os.exit(1)
end

-- Tạo hoặc sửa section ACL theo remarks (hoặc id)
local sid = nil
uci:foreach("passwall2", "acl", function(s)
  if s.remarks == acl.remarks then
    sid = s[".name"]
  end
end)
if not sid then
  sid = uci:add("passwall2", "acl_rule")

end

-- Gán các trường
uci:set("passwall2", sid, "enabled", acl.enabled and "1" or "0")
uci:set("passwall2", sid, "remarks", acl.remarks or "")
uci:set("passwall2", sid, "sources", table.concat(acl.sources or {}, " "))
uci:set("passwall2", sid, "node", acl.node or "default")
uci:set("passwall2", sid, "tcp_no_redir_ports", acl.tcp_no_redir_ports or "default")
uci:set("passwall2", sid, "udp_no_redir_ports", acl.udp_no_redir_ports or "default")
uci:set("passwall2", sid, "tcp_redir_ports", acl.tcp_redir_ports or "default")
uci:set("passwall2", sid, "udp_redir_ports", acl.udp_redir_ports or "default")
uci:set("passwall2", sid, "remote_dns_protocol", acl.remote_dns_protocol or "tcp")
uci:set("passwall2", sid, "remote_dns", acl.remote_dns or "1.1.1.1")
uci:set("passwall2", sid, "remote_dns_doh", acl.remote_dns_doh or "")
uci:set("passwall2", sid, "remote_dns_detour", acl.remote_dns_detour or "remote")
uci:set("passwall2", sid, "remote_fakedns", acl.remote_fakedns and "1" or "0")
uci:set("passwall2", sid, "remote_dns_query_strategy", acl.remote_dns_query_strategy or "UseIPv4")
uci:set("passwall2", sid, "dns_hosts", acl.dns_hosts or "")
uci:set("passwall2", sid, "write_ipset_direct", acl.write_ipset_direct and "1" or "0")

uci:commit("passwall2")

print(json.stringify({status="ok"}))
