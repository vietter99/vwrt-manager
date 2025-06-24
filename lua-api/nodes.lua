#!/usr/bin/lua
local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"

-- Hàm trả JSON
local function json_response(tbl)
  print("Content-Type: application/json\n")
  print(json.stringify(tbl, true))
end

-- 1. Thu thập danh sách node
local nodes = {}

uci:foreach("passwall2", "nodes", function(s)
  table.insert(nodes, {
    id = s[".name"],
    remark = s.remark or s.name or s[".name"],
    type = s.type
  })
end)

-- 2. Đánh dấu node nào đang được sử dụng trong ACL
local used_nodes = {}
uci:foreach("passwall2", "acl_rule", function(s)
  if s.node then
    used_nodes[s.node] = true
  end
end)

-- 3. Thêm trường used cho từng node
for _, node in ipairs(nodes) do
  node.used = used_nodes[node.id] or false
end

json_response({status="ok", nodes=nodes})
