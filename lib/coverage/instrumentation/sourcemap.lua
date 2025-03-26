---@class CoverageSourceMap
---@field create fun(): table Create a new source map
---@field add_mapping fun(sourcemap: table, instrumented_line: number, original_line: number) Add a mapping to the source map
---@field get_original_line fun(sourcemap: table, instrumented_line: number): number|nil Get the original line for an instrumented line
---@field get_instrumented_line fun(sourcemap: table, original_line: number): number|nil Get the instrumented line for an original line
---@field translate_error fun(sourcemap: table, error_message: string, file_path: string): string Translate error messages to use original line numbers
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")

-- Version
M._VERSION = "0.1.0"

--- Create a new source map
---@return table sourcemap The newly created source map
function M.create()
  return {
    original_to_instrumented = {},  -- Maps original line numbers to instrumented line numbers
    instrumented_to_original = {},  -- Maps instrumented line numbers to original line numbers
    file_path = nil,                -- The file path this sourcemap is for
    file_id = nil                   -- The unique ID for this file
  }
end

--- Add a mapping to the source map
---@param sourcemap table The source map
---@param instrumented_line number The instrumented line number
---@param original_line number The original line number
function M.add_mapping(sourcemap, instrumented_line, original_line)
  -- Parameter validation
  error_handler.assert(type(sourcemap) == "table", "sourcemap must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(instrumented_line) == "number", "instrumented_line must be a number", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(original_line) == "number", "original_line must be a number", error_handler.CATEGORY.VALIDATION)

  sourcemap.instrumented_to_original[instrumented_line] = original_line
  sourcemap.original_to_instrumented[original_line] = instrumented_line
end

--- Get the original line for an instrumented line
---@param sourcemap table The source map
---@param instrumented_line number The instrumented line number
---@return number|nil original_line The original line number, or nil if not found
function M.get_original_line(sourcemap, instrumented_line)
  -- Parameter validation
  error_handler.assert(type(sourcemap) == "table", "sourcemap must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(instrumented_line) == "number", "instrumented_line must be a number", error_handler.CATEGORY.VALIDATION)

  return sourcemap.instrumented_to_original[instrumented_line]
end

--- Get the instrumented line for an original line
---@param sourcemap table The source map
---@param original_line number The original line number
---@return number|nil instrumented_line The instrumented line number, or nil if not found
function M.get_instrumented_line(sourcemap, original_line)
  -- Parameter validation
  error_handler.assert(type(sourcemap) == "table", "sourcemap must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(original_line) == "number", "original_line must be a number", error_handler.CATEGORY.VALIDATION)

  return sourcemap.original_to_instrumented[original_line]
end

--- Translate error messages to use original line numbers instead of instrumented line numbers
---@param sourcemap table The source map
---@param error_message string The error message to translate
---@param file_path string The file path to look for in the error message
---@return string translated_message The translated error message
function M.translate_error(sourcemap, error_message, file_path)
  -- Parameter validation
  error_handler.assert(type(sourcemap) == "table", "sourcemap must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(error_message) == "string", "error_message must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)

  -- Extract file path and line number from error message
  local translated_message = error_message
  
  -- Standard Lua error format: "file:line: message"
  local pattern = "([^:]+):(%d+): (.+)"
  local path, line_str, message = error_message:match(pattern)
  
  if path and line_str and message then
    -- Check if this is the file we're looking for
    if path == file_path or path:match(file_path .. "$") then
      local instrumented_line = tonumber(line_str)
      local original_line = M.get_original_line(sourcemap, instrumented_line)
      
      if original_line then
        -- Replace the instrumented line number with the original line number
        translated_message = path .. ":" .. original_line .. ": " .. message
      end
    end
  end
  
  -- Alternative format with line and column: "file:line:column: message"
  local pattern2 = "([^:]+):(%d+):(%d+): (.+)"
  local path2, line_str2, col_str, message2 = error_message:match(pattern2)
  
  if path2 and line_str2 and col_str and message2 then
    -- Check if this is the file we're looking for
    if path2 == file_path or path2:match(file_path .. "$") then
      local instrumented_line = tonumber(line_str2)
      local original_line = M.get_original_line(sourcemap, instrumented_line)
      
      if original_line then
        -- Replace the instrumented line number with the original line number
        translated_message = path2 .. ":" .. original_line .. ":" .. col_str .. ": " .. message2
      end
    end
  end
  
  return translated_message
end

return M