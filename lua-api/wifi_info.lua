#!/usr/bin/lua
local function exec(cmd)
  local f = io.popen(cmd)
  if not f then return "" end
  local o = f:read("*a")
  f:close()
  return o or ""
end
local function has(s, pat)
  return s:match(pat) ~= nil
end
local function detect_bands()
  local bands = {}
  local iw = exec("iw list 2>/dev/null")
  if iw == "" then return bands end
  local band_blocks = {}
  local curr = nil
  for line in iw:gmatch("[^\r\n]+") do
    if line:match("^%s*Band%s+%d+:") then
      curr = {header = line, lines = {}}
      table.insert(band_blocks, curr)
    elseif curr then
      table.insert(curr.lines, line)
    end
  end
  for _, block in ipairs(band_blocks) do
    local bandname = block.header:match("Band%s+%d+:%s*([%d%.]+)%s*GHz")
    if not bandname then
      if block.header:match("Band%s+1") then bandname = "2.4"
      elseif block.header:match("Band%s+2") then bandname = "5"
      elseif block.header:match("Band%s+3") then bandname = "6"
      end
    end
    if bandname then
      bandname = (bandname == "2.4" and "2.4GHz") or (bandname == "5" and "5GHz") or (bandname == "6" and "6GHz") or (bandname .. "GHz")
    else
      bandname = "unknown"
    end
    -- Detect modes
    local modes = {}
    local widths = {}
    local block_str = table.concat(block.lines, "\n")
    if has(block_str, "HE PHY Capabilities") or has(block_str, "HE Iftypes") then table.insert(modes, "ax") end
    if has(block_str, "VHT Capabilities") then table.insert(modes, "ac") end
    if has(block_str, "HT20/HT40") or has(block_str, "HT Capabilities") then table.insert(modes, "n") end
    table.insert(modes, "legacy")
    -- AX: 20/40/80/160 MHz, AC: 20/40/80/160, N: 20/40, legacy: 20
    if has(block_str, "HE PHY Capabilities") or has(block_str, "HE Iftypes") then
      widths["ax"] = {"20", "40"}
      if bandname == "5GHz" or bandname == "6GHz" then
        widths["ax"] = {"20", "40", "80", "160"}
      end
    end
    if has(block_str, "VHT Capabilities") then
      widths["ac"] = {"20", "40", "80"}
      if bandname == "5GHz" or bandname == "6GHz" then
        if not widths["ac"] then widths["ac"] = {"20", "40", "80"} end
      end
    end
    if has(block_str, "HT20/HT40") or has(block_str, "HT Capabilities") then
      widths["n"] = {"20", "40"}
    end
    widths["legacy"] = {"20"}
  -- Lọc mode hợp lệ từng band (chặn ac cho 2.4GHz)
    local filtered_modes = {}
    local filtered_widths = {}
for _, m in ipairs(modes) do
  if bandname == "2.4GHz" and m == "ac" then
    -- skip ac on 2.4GHz
  elseif bandname == "5GHz" and m == "ac" then
    table.insert(filtered_modes, m)
    filtered_widths[m] = widths[m]
  elseif bandname == "6GHz" and m == "ac" then
    -- skip ac on 6GHz (chuẩn hóa)
  elseif bandname ~= "2.4GHz" and m == "legacy" then
    -- skip legacy on 5G/6G
  else
    -- luôn cho ax, n (và legacy nếu 2.4G)
    table.insert(filtered_modes, m)
    filtered_widths[m] = widths[m]
  end
end
-- Tìm các channel khả dụng
local channels = {}
for _, line in ipairs(block.lines) do
  local freq, ch = line:match("^%s*%*%s*(%d+%.?%d*)%s+MHz%s+%[(%d+)%]")
  if freq and ch then
    table.insert(channels, { channel = ch, freq = freq })
  end
end
    table.insert(bands, {
      band = bandname,
      modes = filtered_modes,    
      widths = filtered_widths,
      channels = channels     
    })
  end

  return bands
end
-- Output JSON
local json = require "luci.jsonc"
print("Content-Type: application/json\n")
print(json.stringify({bands = detect_bands()}, true))
