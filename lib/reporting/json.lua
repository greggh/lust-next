---@class ReportingJSON
---@field _VERSION string Module version
---@field encode fun(tbl: any, options?: {pretty?: boolean, indent?: number, limit?: number}): string Encodes a Lua value into JSON
---@field decode fun(json_str: string, options?: {strict?: boolean, safe?: boolean}): any|nil, string? Decodes a JSON string into a Lua value
---@field encode_sparse_array fun(array: table, options?: {pretty?: boolean}): string Encodes a sparse array (with non-contiguous keys)
---@field encode_ordered fun(tbl: table, key_order: string[], options?: {pretty?: boolean}): string Encodes a table with specific key ordering
---@field is_valid_json fun(json_str: string): boolean Checks if a string is valid JSON
---@field format fun(json_str: string, options?: {indent?: number}): string Formats JSON string with indentation
---@field get_path fun(tbl: table, path: string): any|nil Gets a value from a table using a JSON path (e.g., "users.0.name")
-- Simple JSON encoder/decoder for firmo
-- Minimalist implementation for coverage reports optimized for performance

local M = {}

--- Convert a Lua value to its JSON string representation
---@private
---@param val any The Lua value to encode (string, number, boolean, nil, or table)
---@return string encoded_value The JSON-encoded value as a string
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

--- Determine if a table should be encoded as a JSON array or object
---@private
---@param tbl table The table to analyze
---@return boolean is_array Whether the table should be encoded as a JSON array (true) or object (false)
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

--- Encode a Lua value as a JSON string
---@param tbl any Value to encode (table, string, number, boolean, or nil)
---@return string json_string The JSON-encoded string representation
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
