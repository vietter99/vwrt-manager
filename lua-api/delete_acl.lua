#!/usr/bin/lua

local json = require "luci.jsonc"
local uci = require "luci.model.uci".cursor()

print("Content-Type: application/json\n")

-- Đọc request body (POST)
local input = io.read("*a") or ""
local data = {}
if input and #input > 0 then
  data = json.parse(input) or {}
end

local id = data.id or ""

if not id or #id == 0 then
  print(json.stringify({status="error", msg="Thiếu id"}))
  os.exit(1)
end

-- Tìm section cần xóa
local found = false
uci:foreach("passwall2", "acl_rule", function(s)
  if s[".name"] == id then found = true end
end)

if not found then
  print(json.stringify({status="error", msg="Không tìm thấy ACL!"}))
  os.exit(1)
end

uci:delete("passwall2", id)
uci:commit("passwall2")
print(json.stringify({status="ok", id = id}))
