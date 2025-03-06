-- Simple JSON encoder for lust-next
-- Minimalist implementation for coverage reports

local M = {}

-- Encode basic Lua values to JSON
local function encode_value(val)
  local val_type = type(val)
  
  if val == nil then
    return "null"
  elseif val_type == "boolean" then
    return val and "true" or "false"
  elseif val_type == "number" then
    return tostring(val)
  elseif val_type == "string" then
    -- Escape special characters
    local escaped = val:gsub('\\', '\\\\')
      :gsub('"', '\\"')
      :gsub('\n', '\\n')
      :gsub('\r', '\\r')
      :gsub('\t', '\\t')
      :gsub('\b', '\\b')
      :gsub('\f', '\\f')
    return '"' .. escaped .. '"'
  elseif val_type == "table" then
    return M.encode(val)
  else
    return '"[' .. val_type .. ']"'
  end
end

-- Determine if a table should be encoded as an array or object
local function is_array(tbl)
  local max_index = 0
  local count = 0
  
  for k, v in pairs(tbl) do
    if type(k) == "number" and k > 0 and math.floor(k) == k then
      max_index = math.max(max_index, k)
      count = count + 1
    else
      return false
    end
  end
  
  return max_index <= 2 * count
end

-- Encode a Lua table to JSON
function M.encode(tbl)
  if type(tbl) ~= "table" then
    return encode_value(tbl)
  end
  
  local result = {}
  
  if is_array(tbl) then
    -- Encode as JSON array
    result[1] = "["
    local items = {}
    
    for i = 1, #tbl do
      items[i] = encode_value(tbl[i])
    end
    
    result[2] = table.concat(items, ",")
    result[3] = "]"
  else
    -- Encode as JSON object
    result[1] = "{"
    local items = {}
    local index = 1
    
    for k, v in pairs(tbl) do
      items[index] = encode_value(k) .. ":" .. encode_value(v)
      index = index + 1
    end
    
    result[2] = table.concat(items, ",")
    result[3] = "}"
  end
  
  return table.concat(result)
end

-- Return the module
return M