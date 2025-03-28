---@class CoverageTransformer
---@field transform fun(source: string, file_id: string): string, table Transform Lua source code by injecting coverage tracking statements
---@field create_file_id fun(file_path: string): string Create a unique ID for a file
---@field instrument_line fun(line: string, file_id: string, line_number: number): string Instrument a line with coverage tracking
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local parser = require("lib.coverage.instrumentation.parser")
local central_config = require("lib.core.central_config")

-- Version
M._VERSION = "0.1.0"

--- Helper function to escape special characters in string for use in patterns
---@private
---@param text string Text to escape
---@return string escaped_text The text with special characters escaped
local function escape_pattern(text)
  return text:gsub("([%(%)%.%%%+%-%*%?%[%^%$%]])", "%%%1")
end

-- Create a unique identifier for a file
---@param file_path string The path to the file
---@return string file_id A unique identifier for the file
function M.create_file_id(file_path)
  -- Hash the file path to create a unique ID
  local id = ""
  for i = 1, #file_path do
    id = id .. string.format("%02x", string.byte(file_path, i))
  end
  
  -- Truncate to reasonable length (32 characters is plenty for uniqueness)
  if #id > 32 then
    id = id:sub(1, 32)
  end
  
  return "file_" .. id
end

--- Generate tracking statement for a line of code
---@private
---@param file_id string The unique identifier for the file
---@param line_number number The line number to track
---@return string tracking_code The Lua code that tracks execution of the line
local function generate_tracking_statement(file_id, line_number)
  return string.format("do require('lib.coverage.runtime.tracker').track(%q, %d) end;", file_id, line_number)
end

-- Instrument a single line with coverage tracking
---@param line string The line of code to instrument
---@param file_id string The unique identifier for the file
---@param line_number number The line number
---@return string instrumented_line The instrumented line
function M.instrument_line(line, file_id, line_number)
  -- Don't instrument empty lines or comment-only lines
  if line:match("^%s*$") or line:match("^%s*%-%-") then
    return line
  end
  
  -- Don't try to instrument function declarations, they need special handling
  if line:match("^%s*function%s+") then
    return line
  end
  
  -- Don't instrument return statements or end statements directly
  if line:match("^%s*return%s+") or line:match("^%s*end%s*$") then
    return line
  end
  
  -- Add tracking statement at the beginning of the line
  local tracking_code = generate_tracking_statement(file_id, line_number)
  local indentation = line:match("^(%s*)")
  
  return indentation .. tracking_code .. " " .. line:sub(#indentation + 1)
end

-- Transform Lua source code by injecting coverage tracking statements
---@param source string The original Lua source code
---@param file_id string The unique identifier for the file
---@return string instrumented_code The instrumented Lua code
---@return table sourcemap Mapping between original and instrumented line numbers
function M.transform(source, file_id)
  -- Parameter validation
  error_handler.assert(type(source) == "string", "source must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Parse the source code
  local parsed = parser.parse(source)
  
  -- Lines of the instrumented code
  local instrumented_lines = {}
  -- Source map (maps instrumented line numbers to original line numbers)
  local sourcemap = {
    original_to_instrumented = {},
    instrumented_to_original = {}
  }
  
  -- Index of current instrumented line
  local instrumented_line_index = 0
  
  -- Get original lines
  local lines = {}
  for line in source:gmatch("([^\r\n]*)[\r\n]?") do
    table.insert(lines, line)
  end
  
  -- Process each line
  for i, line in ipairs(lines) do
    if parsed.line_is_executable and parsed.line_is_executable[i] then
      -- Instrument executable lines
      local instrumented_line = M.instrument_line(line, file_id, i)
      
      -- Add the instrumented line
      table.insert(instrumented_lines, instrumented_line)
      
      -- Update source map
      instrumented_line_index = instrumented_line_index + 1
      sourcemap.original_to_instrumented[i] = instrumented_line_index
      sourcemap.instrumented_to_original[instrumented_line_index] = i
    else
      -- Keep non-executable lines unchanged
      table.insert(instrumented_lines, line)
      
      -- Update source map
      instrumented_line_index = instrumented_line_index + 1
      sourcemap.original_to_instrumented[i] = instrumented_line_index
      sourcemap.instrumented_to_original[instrumented_line_index] = i
    end
  end
  
  -- Combine instrumented lines into a single string
  local instrumented_code = table.concat(instrumented_lines, "\n")
  
  return instrumented_code, sourcemap
end

return M