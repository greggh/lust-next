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

-- Lazy-loaded v3 module
local v3 = nil

-- Get v3 module implementation
local function get_v3()
  if not v3 then
    local success, result = pcall(function()
      return require("lib.coverage.v3.init")
    end)
    
    if success and type(result) == "table" then
      v3 = result
      logger.info("Loaded v3 coverage module")
    else
      logger.warn("Failed to load v3 coverage module, using v2 fallback", {
        error = tostring(result)
      })
    end
  end
  
  return v3
end

-- Version
M._VERSION = "3.0.0"

-- Module state (for v2 fallback)
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
        version = 3,  -- Default to v3
        enabled = false,
        include = function(path) return path:match("%.lua$") ~= nil end,
        exclude = function(path) return path:match("/tests/") ~= nil or path:match("test%.lua$") ~= nil end,
        report = {
          dir = "./coverage-reports"
        }
      }
    }
  end
  
  return config
end

-- Check if we should use v3
local function should_use_v3()
  local config = get_config()
  return config.coverage.version == 3
end

-- Start coverage tracking
---@return boolean success Whether tracking was successfully started
function M.start()
  -- Check if v3 is enabled
  if should_use_v3() then
    local v3_module = get_v3()
    if v3_module then
      local result = v3_module.start()
      return result ~= nil
    end
  end
  
  -- v2 fallback implementation
  if coverage_active then
    logger.warn("Coverage tracking is already active")
    return false
  end
  
  -- Load fallback components for v2
  local components_success, components = pcall(function()
    return {
      loader_hook = require("lib.coverage.loader.hook"),
      tracker = require("lib.coverage.runtime.tracker"),
      data_store = require("lib.coverage.runtime.data_store"),
      assertion_hook = require("lib.coverage.assertion.hook")
    }
  end)
  
  if not components_success then
    logger.error("Failed to load coverage components", {
      error = tostring(components)
    })
    return false
  end
  
  -- Create data store
  coverage_data = components.data_store.create()
  
  -- Install hooks
  components.loader_hook.install()
  components.assertion_hook.install()
  
  -- Start tracker
  components.tracker.start()
  
  coverage_active = true
  logger.info("Started coverage tracking (v2 fallback)")
  
  return true
end

-- Stop coverage tracking
---@return boolean success Whether tracking was successfully stopped
function M.stop()
  -- Check if v3 is enabled
  if should_use_v3() then
    local v3_module = get_v3()
    if v3_module then
      local result = v3_module.stop()
      return result ~= nil
    end
  end
  
  -- v2 fallback implementation
  if not coverage_active then
    logger.warn("Coverage tracking is not active")
    return false
  end
  
  -- Load fallback components for v2
  local components_success, components = pcall(function()
    return {
      loader_hook = require("lib.coverage.loader.hook"),
      tracker = require("lib.coverage.runtime.tracker"),
      data_store = require("lib.coverage.runtime.data_store"),
      assertion_hook = require("lib.coverage.assertion.hook")
    }
  end)
  
  if not components_success then
    logger.error("Failed to load coverage components", {
      error = tostring(components)
    })
    return false
  end
  
  -- Stop tracker
  components.tracker.stop()
  
  -- Uninstall hooks
  components.assertion_hook.uninstall()
  components.loader_hook.uninstall()
  
  -- Update coverage data
  local tracker_data = components.tracker.get_data()
  
  -- Add tracked data to our data store
  for file_id, lines in pairs(tracker_data.execution_data or {}) do
    for line_number, count in pairs(lines) do
      for i = 1, count do
        components.data_store.add_execution(coverage_data, file_id, line_number)
      end
    end
  end
  
  for file_id, lines in pairs(tracker_data.coverage_data or {}) do
    for line_number, _ in pairs(lines) do
      components.data_store.add_coverage(coverage_data, file_id, line_number)
    end
  end
  
  -- Copy file mappings
  for file_id, file_path in pairs(tracker_data.file_map or {}) do
    if type(file_path) == "string" then  -- Only copy string->string mappings
      components.data_store.register_file(coverage_data, file_id, file_path)
    end
  end
  
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
  components.data_store.calculate_summary(coverage_data)
  
  coverage_active = false
  logger.info("Stopped coverage tracking (v2 fallback)")
  
  return true
end

-- Reset coverage data
---@return boolean success Whether data was successfully reset
function M.reset()
  -- Check if v3 is enabled
  if should_use_v3() then
    local v3_module = get_v3()
    if v3_module then
      local result = v3_module.reset()
      return result ~= nil
    end
  end
  
  -- v2 fallback implementation
  if coverage_active then
    logger.warn("Cannot reset while coverage tracking is active")
    return false
  end
  
  -- Load data store component for v2
  local data_store_success, data_store = pcall(function()
    return require("lib.coverage.runtime.data_store")
  end)
  
  if not data_store_success then
    logger.error("Failed to load data store component", {
      error = tostring(data_store)
    })
    return false
  end
  
  coverage_data = data_store.create()
  
  logger.info("Reset coverage data (v2 fallback)")
  return true
end

-- Check if coverage tracking is active
---@return boolean is_active Whether coverage tracking is active
function M.is_active()
  -- Check if v3 is enabled
  if should_use_v3() then
    local v3_module = get_v3()
    if v3_module then
      return v3_module.is_active()
    end
  end
  
  -- v2 fallback implementation
  return coverage_active
end

-- Get the current coverage data
---@return table data The current coverage data
function M.get_data()
  -- Check if v3 is enabled
  if should_use_v3() then
    local v3_module = get_v3()
    if v3_module then
      return v3_module.get_data()
    end
  end
  
  -- v2 fallback implementation
  if not coverage_data then
    -- Load data store component for v2
    local data_store_success, data_store = pcall(function()
      return require("lib.coverage.runtime.data_store")
    end)
    
    if data_store_success then
      coverage_data = data_store.create()
    else
      logger.error("Failed to load data store component", {
        error = tostring(data_store)
      })
      return {}
    end
  end
  
  return coverage_data
end

-- Generate a coverage report
---@param format string The report format (html, json, lcov)
---@param output_path string The path to write the report to
---@return boolean success Whether the report was successfully generated
function M.generate_report(format, output_path)
  -- Parameter validation
  error_handler.assert(type(format) == "string", "format must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Check if v3 is enabled
  if should_use_v3() then
    local v3_module = get_v3()
    if v3_module then
      local result = v3_module.report(format, {
        output_dir = output_path
      })
      return result or false
    end
  end
  
  -- v2 fallback implementation
  error_handler.assert(type(output_path) == "string", "output_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Get configuration
  local config = get_config()
  
  -- Use default output path if not specified
  if not output_path or output_path == "" then
    output_path = config.coverage.report.dir or "./coverage-reports"
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
  local generator_path = string.format("lib.coverage.report.%s", format:lower())
  local success, generator = pcall(require, generator_path)
  
  if not success then
    logger.error("Failed to load report generator", {
      format = format,
      error = tostring(generator)
    })
    return false
  end
  
  -- Generate the report
  local gen_success, err = generator.generate(coverage_data, output_path)
  if not gen_success then
    logger.error("Failed to generate report", {
      format = format,
      output_path = output_path,
      error = error_handler.format_error(err)
    })
    return false
  end
  
  logger.info("Generated coverage report (v2 fallback)", {
    format = format,
    output_path = output_path
  })
  
  return true
end

return M