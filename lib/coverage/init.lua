---@class Coverage
---@field start fun(): boolean Start coverage tracking
---@field stop fun(): boolean Stop coverage tracking
---@field reset fun(): boolean Reset coverage data
---@field is_active fun(): boolean Check if coverage is active
---@field get_data fun(): table Get the current coverage data
---@field generate_report fun(format: string, output_path: string): boolean Generate a coverage report
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")

-- Instrumentation components
local loader_hook = require("lib.coverage.loader.hook")
local tracker = require("lib.coverage.runtime.tracker")
local data_store = require("lib.coverage.runtime.data_store")
local assertion_hook = require("lib.coverage.assertion.hook")

-- Version
M._VERSION = "3.0.0"

-- Module state
local coverage_active = false
local coverage_data = nil

-- Get configuration with default fallbacks
local function get_config()
  local config = {}
  
  -- Try to get central configuration
  local success, result = pcall(function()
    if central_config and type(central_config.get_config) == "function" then
      return central_config.get_config()
    end
    return nil
  end)
  
  if success and type(result) == "table" and type(result.coverage) == "table" then
    config = result
  else
    -- Use default configuration
    config = {
      coverage = {
        include = {"**/*.lua"},
        exclude = {"**/vendor/**", "**/lib/coverage/**"},
        report_dir = "./coverage-reports"
      }
    }
  end
  
  return config
end

-- Start coverage tracking
---@return boolean success Whether tracking was successfully started
function M.start()
  if coverage_active then
    logger.warn("Coverage tracking is already active")
    return false
  end
  
  -- Create data store
  coverage_data = data_store.create()
  
  -- Install loader hook
  loader_hook.install()
  
  -- Install assertion hook
  assertion_hook.install()
  
  -- Start tracker
  tracker.start()
  
  coverage_active = true
  logger.info("Started coverage tracking (v3)")
  
  return true
end

-- Stop coverage tracking
---@return boolean success Whether tracking was successfully stopped
function M.stop()
  if not coverage_active then
    logger.warn("Coverage tracking is not active")
    return false
  end
  
  -- Stop tracker
  tracker.stop()
  
  -- Uninstall hooks
  assertion_hook.uninstall()
  loader_hook.uninstall()
  
  -- Update coverage data
  local tracker_data = tracker.get_data()
  
  -- Add tracked data to our data store
  for file_id, lines in pairs(tracker_data.execution_data) do
    for line_number, count in pairs(lines) do
      for i = 1, count do
        data_store.add_execution(coverage_data, file_id, line_number)
      end
    end
  end
  
  for file_id, lines in pairs(tracker_data.coverage_data) do
    for line_number, _ in pairs(lines) do
      data_store.add_coverage(coverage_data, file_id, line_number)
    end
  end
  
  -- Copy file mappings
  for file_id, file_path in pairs(tracker_data.file_map) do
    if type(file_path) == "string" then  -- Only copy string->string mappings
      data_store.register_file(coverage_data, file_id, file_path)
    end
  end
  
  -- We no longer need to artificially add coverage data
  -- The assertion hooks now properly mark covered lines
  -- Log coverage data for diagnostic purposes
  local file_ids = {}
  -- Count execution data
  if coverage_data.execution_data then
    for file_id, _ in pairs(coverage_data.execution_data) do
      file_ids[file_id] = true
    end
  end
  
  -- Count coverage data
  if coverage_data.coverage_data then
    for file_id, _ in pairs(coverage_data.coverage_data) do
      file_ids[file_id] = true
    end
  end
  
  -- Log tracked files
  for file_id, _ in pairs(file_ids) do
    local file_path = coverage_data.file_map and coverage_data.file_map[file_id] or file_id
    logger.info("Tracked file in coverage", {
      file_id = file_id,
      file_path = file_path,
      has_execution = coverage_data.execution_data and coverage_data.execution_data[file_id] ~= nil,
      has_coverage = coverage_data.coverage_data and coverage_data.coverage_data[file_id] ~= nil
    })
  end
  
  -- Calculate summary
  data_store.calculate_summary(coverage_data)
  
  coverage_active = false
  logger.info("Stopped coverage tracking")
  
  return true
end

-- Reset coverage data
---@return boolean success Whether data was successfully reset
function M.reset()
  if coverage_active then
    logger.warn("Cannot reset while coverage tracking is active")
    return false
  end
  
  coverage_data = data_store.create()
  tracker.reset()
  
  logger.info("Reset coverage data")
  return true
end

-- Check if coverage tracking is active
---@return boolean is_active Whether coverage tracking is active
function M.is_active()
  return coverage_active
end

-- Get the current coverage data
---@return table data The current coverage data
function M.get_data()
  if not coverage_data then
    coverage_data = data_store.create()
  end
  
  -- Debug log the coverage data
  local file_count = 0
  if coverage_data and coverage_data.execution_data then
    for file_id, _ in pairs(coverage_data.execution_data) do
      file_count = file_count + 1
      logger.debug("Coverage data contains file", {
        file_id = file_id,
        file_path = data_store.get_file_path(coverage_data, file_id),
        execution_count = (next(coverage_data.execution_data[file_id]) ~= nil) and "has executions" or "no executions"
      })
    end
  end
  
  -- Count entries in the file map
  local file_map_entries = 0
  if coverage_data.file_map then
    for _, _ in pairs(coverage_data.file_map) do
      file_map_entries = file_map_entries + 1
    end
  end
  
  logger.info("Returning coverage data", {
    files_count = file_count,
    has_file_map = coverage_data.file_map ~= nil,
    file_map_entries = file_map_entries
  })
  
  return coverage_data
end

-- Load a report generator
---@param format string The report format (html, json, lcov)
---@return table|nil generator The report generator or nil if not found
local function load_report_generator(format)
  local generator_path = string.format("lib.coverage.report.%s", format:lower())
  
  local success, generator = pcall(require, generator_path)
  if not success then
    logger.error("Failed to load report generator", {
      format = format,
      error = tostring(generator)
    })
    return nil
  end
  
  return generator
end

-- Generate a coverage report
---@param format string The report format (html, json, lcov)
---@param output_path string The path to write the report to
---@return boolean success Whether the report was successfully generated
function M.generate_report(format, output_path)
  -- Parameter validation
  error_handler.assert(type(format) == "string", "format must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Get configuration
  local config = get_config()
  
  -- Use default output path if not specified
  if not output_path or output_path == "" then
    output_path = config.coverage.report_dir or "./coverage-reports"
  end
  
  -- Ensure the output directory exists
  local dir_path = output_path:match("(.+)/[^/]*$") or output_path
  local mkdir_success, mkdir_err = fs.ensure_directory_exists(dir_path)
  if not mkdir_success then
    logger.error("Failed to create output directory", {
      directory = dir_path,
      error = error_handler.format_error(mkdir_err)
    })
    return false
  end
  
  -- Load the report generator
  local generator = load_report_generator(format)
  if not generator then
    logger.error("Unsupported report format", {
      format = format
    })
    return false
  end
  
  -- Generate the report
  local success, err = generator.generate(coverage_data, output_path)
  if not success then
    logger.error("Failed to generate report", {
      format = format,
      output_path = output_path,
      error = error_handler.format_error(err)
    })
    return false
  end
  
  logger.info("Generated coverage report", {
    format = format,
    output_path = output_path
  })
  
  return true
end

return M