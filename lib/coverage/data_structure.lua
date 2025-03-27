---@class CoverageDataStructure
---@field normalize_path fun(path: string): string Normalizes a file path
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Version
M._VERSION = "0.1.0 (Compatibility)"

-- Add a warning
logger.warn("Using compatibility data_structure module", {
  message = "This module is deprecated and should be replaced with instrumentation-based coverage",
  version = M._VERSION
})

--- Normalizes a file path for consistent lookup
---@param path string The file path to normalize
---@return string normalized_path The normalized path
function M.normalize_path(path)
  if not path then
    return nil
  end
  
  -- Replace backslashes with forward slashes
  local normalized = path:gsub("\\", "/")
  
  -- Remove trailing slashes
  normalized = normalized:gsub("/$", "")
  
  -- Remove duplicate slashes
  while normalized:match("//") do
    normalized = normalized:gsub("//", "/")
  end
  
  return normalized
end

return M