-- Hash utility module for firmo
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("tools.hash")

---@class tools_hash
---@field hash_string fun(str: string): string Generate a hash for a string
---@field hash_file fun(path: string): string|nil, table? Generate a hash for a file's contents
---@field _VERSION string Module version
local M = {
  _VERSION = "1.0.0"
}

-- Helper to convert bytes to hex string
local function bytes_to_hex(str)
  return (str:gsub(".", function(c)
    return string.format("%02x", string.byte(c))
  end))
end

-- Generate a hash for a string using a simple but fast algorithm
---@param str string The string to hash
---@return string hash The hash string
function M.hash_string(str)
  if type(str) ~= "string" then
    error(error_handler.validation_error(
      "Input must be a string",
      {provided_type = type(str)}
    ))
  end

  -- Use a simple FNV-1a hash algorithm
  local hash = 2166136261 -- FNV offset basis
  for i = 1, #str do
    hash = hash ~ string.byte(str, i)
    hash = (hash * 16777619) & 0xFFFFFFFF -- FNV prime
  end

  -- Convert to hex string
  return string.format("%08x", hash)
end

-- Generate a hash for a file's contents
---@param path string Path to the file
---@return string|nil hash The hash string, or nil if file couldn't be read
---@return table? error Error information if reading failed
function M.hash_file(path)
  local fs = require("lib.tools.filesystem")

  -- Read the file
  local content, err = fs.read_file(path)
  if not content then
    logger.error("Failed to read file for hashing", {
      path = path,
      error = err
    })
    return nil, err
  end

  -- Hash the content
  return M.hash_string(content)
end

return M