---@class JSONReporter
---@field generate fun(data: table, options: table): boolean|nil, table|nil Generate a JSON coverage report
---@field _VERSION string Module version
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")

-- Version
M._VERSION = "3.0.0"

-- Encode a value as JSON
---@param value any The value to encode
---@return string json The JSON string
local function encode_json(value)
  if value == nil then
    return "null"
  elseif type(value) == "string" then
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return '"' .. value .. '"'
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  elseif type(value) == "table" then
    local is_array = #value > 0
    local parts = {}
    
    if is_array then
      for i, v in ipairs(value) do
        table.insert(parts, encode_json(v))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      for k, v in pairs(value) do
        -- Arrays are encoded differently, so ignore numeric keys
        if type(k) == "string" then
          table.insert(parts, encode_json(k) .. ":" .. encode_json(v))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    return '"' .. tostring(value) .. '"'
  end
end

-- Generate a JSON coverage report
---@param data table The coverage data
---@param options table The report options
---@return boolean|nil success Whether the report was successfully generated
---@return table|nil error Error object if failed to generate
function M.generate(data, options)
  -- Parameter validation
  if type(data) ~= "table" then
    return nil, error_handler.validation_error(
      "Coverage data must be a table",
      {parameter = "data", provided_type = type(data)}
    )
  end
  
  if type(options) ~= "table" then
    return nil, error_handler.validation_error(
      "Options must be a table",
      {parameter = "options", provided_type = type(options)}
    )
  end
  
  -- Get configuration
  local config = central_config.get_config()
  
  -- Prepare options with defaults
  options = options or {}
  options.output_dir = options.output_dir or config.coverage.report.dir or "./coverage-reports"
  options.pretty = options.pretty or true
  
  -- Ensure the output directory exists
  local dir_success, dir_err = fs.ensure_directory_exists(options.output_dir)
  if not dir_success then
    return nil, error_handler.io_error(
      "Failed to create output directory",
      {directory = options.output_dir, error = error_handler.format_error(dir_err)}
    )
  end
  
  -- Encode as JSON
  local json = nil
  
  if options.pretty then
    -- Simple pretty printing
    json = encode_json(data):gsub("{\"([^{}]+)\":", "\n  {\"\1\":"):gsub(",\"([^{}]+)\":", ",\n    \"\1\":"):gsub("\n\n", "\n")
  else
    json = encode_json(data)
  end
  
  -- Write the JSON file
  local json_path = options.output_dir .. "/coverage-report.json"
  local write_success, write_err = fs.write_file(json_path, json)
  
  if not write_success then
    return nil, error_handler.io_error(
      "Failed to write JSON report",
      {file_path = json_path, error = error_handler.format_error(write_err)}
    )
  end
  
  logger.info("Generated JSON coverage report", {
    file_path = json_path,
    summary = {
      total_files = data.summary and data.summary.total_files or 0,
      coverage_percent = data.summary and string.format("%.2f%%", data.summary.coverage_percent) or "0.00%",
      execution_percent = data.summary and string.format("%.2f%%", data.summary.execution_percent) or "0.00%"
    }
  })
  
  return true
end

return M