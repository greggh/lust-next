---@class JSONReportGenerator
---@field generate fun(data: table, output_path: string): boolean, string|nil Generate a JSON coverage report
---@field encode_json fun(value: any): string Encode a Lua value as JSON
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local data_store = require("lib.coverage.runtime.data_store")

-- Version
M._VERSION = "3.0.0"

-- Simple JSON encoder (note: this is a simplified version, not a full JSON encoder)
---@param value any The value to encode
---@return string json The JSON-encoded string
function M.encode_json(value)
  local t = type(value)
  
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return value and "true" or "false"
  elseif t == "number" then
    return tostring(value)
  elseif t == "string" then
    return '"' .. value:gsub('[\\"]', '\\%0'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
  elseif t == "table" then
    -- Check if it's an array (all keys are numbers)
    local is_array = true
    local max_index = 0
    
    for k, _ in pairs(value) do
      if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
        is_array = false
        break
      end
      max_index = math.max(max_index, k)
    end
    
    if is_array and max_index > 0 then
      local parts = {}
      for i = 1, max_index do
        parts[i] = M.encode_json(value[i] or nil)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then
          table.insert(parts, M.encode_json(tostring(k)) .. ":" .. M.encode_json(v))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    error("Cannot encode " .. t .. " to JSON")
  end
end

-- Generate a JSON coverage report
---@param data table The coverage data
---@param output_path string The path to write the report to
---@return boolean success Whether the report was successfully generated
---@return string|nil error Error message if generation failed
function M.generate(data, output_path)
  -- Parameter validation
  error_handler.assert(type(data) == "table", "data must be a table", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Calculate summary if not already calculated
  if not data.summary or not data.summary.line_coverage_percent then
    data_store.calculate_summary(data)
  end
  
  -- Ensure the output path has the right extension
  if not output_path:match("%.json$") then
    output_path = output_path .. "/coverage-report.json"
  end
  
  -- Ensure the output directory exists
  local dir_path = output_path:match("(.+)/[^/]*$") or output_path
  local mkdir_success, mkdir_err = fs.ensure_directory_exists(dir_path)
  if not mkdir_success then
    logger.error("Failed to create output directory", {
      directory = dir_path,
      error = error_handler.format_error(mkdir_err)
    })
    return false, "Failed to create output directory: " .. tostring(mkdir_err)
  end
  
  -- Get all file IDs
  local file_ids = {}
  for file_id, _ in pairs(data.execution_data or {}) do
    file_ids[file_id] = true
  end
  for file_id, _ in pairs(data.coverage_data or {}) do
    file_ids[file_id] = true
  end
  
  -- Convert to a sorted list
  local file_id_list = {}
  for file_id, _ in pairs(file_ids) do
    table.insert(file_id_list, file_id)
  end
  table.sort(file_id_list)
  
  -- Prepare the report data
  local report_data = {
    summary = data.summary,
    files = {},
    timestamp = os.time(),
    version = M._VERSION
  }
  
  -- Process each file
  for _, file_id in ipairs(file_id_list) do
    local file_data = data_store.get_file_data(data, file_id)
    if file_data then
      local file_path = file_data.file_path or file_id
      
      -- Prepare line data
      local lines = {}
      for line_number, line_data in pairs(file_data.lines) do
        lines[tostring(line_number)] = {
          execution_count = line_data.execution_count,
          is_executable = line_data.is_executable,
          is_executed = line_data.is_executed,
          is_covered = line_data.is_covered,
          status = line_data.status
        }
      end
      
      -- Add file to report
      report_data.files[file_path] = {
        summary = file_data.summary,
        lines = lines
      }
    end
  end
  
  -- Encode the report data as JSON
  local json = M.encode_json(report_data)
  
  -- Write the JSON to the output file
  local write_success, write_err = fs.write_file(output_path, json)
  if not write_success then
    logger.error("Failed to write JSON report", {
      output_path = output_path,
      error = error_handler.format_error(write_err)
    })
    return false, "Failed to write JSON report: " .. tostring(write_err)
  end
  
  logger.info("Generated JSON coverage report", {
    output_path = output_path
  })
  
  return true
end

return M