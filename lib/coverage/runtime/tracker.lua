---@class CoverageTracker
---@field track fun(file_id: string, line_number: number) Mark a line as executed
---@field mark_covered fun(file_id: string, line_number: number) Mark a line as covered (executed + verified)
---@field reset fun() Reset the tracking data
---@field get_data fun(): table Get the current tracking data
---@field start fun() Start tracking coverage
---@field stop fun() Stop tracking coverage
---@field is_active fun(): boolean Check if tracking is active
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local fs = require("lib.tools.filesystem")
local central_config = require("lib.core.central_config")

-- Version
M._VERSION = "0.1.0"

-- Module state
local tracking_active = false
local execution_data = {}  -- Tracks line execution by file_id and line number
local coverage_data = {}   -- Tracks lines covered by tests
local file_map = {}        -- Maps file_id to file path and vice versa
local sourcemaps = {}      -- Source maps for instrumented files

--- Start tracking coverage data
---@return boolean success Whether tracking was successfully started
function M.start()
  if tracking_active then
    logger.warn("Coverage tracking is already active")
    return false
  end
  
  -- Reset data
  execution_data = {}
  coverage_data = {}
  
  -- Mark as active
  tracking_active = true
  
  logger.info("Started coverage tracking")
  return true
end

--- Stop tracking coverage and finalize data collection
---@return boolean success Whether tracking was successfully stopped
function M.stop()
  if not tracking_active then
    logger.warn("Coverage tracking is not active")
    return false
  end
  
  -- Mark as inactive
  tracking_active = false
  
  logger.info("Stopped coverage tracking")
  return true
end

-- Check if tracking is active
---@return boolean is_active Whether tracking is active
function M.is_active()
  return tracking_active
end

--- Reset all tracking data and clear state
---@return boolean success Whether data was successfully reset
function M.reset()
  execution_data = {}
  coverage_data = {}
  file_map = {}
  sourcemaps = {}
  
  logger.info("Reset coverage tracking data")
  return true
end

--- Register a file in the file map for tracking
---@param file_id string The unique identifier for the file
---@param file_path string The path to the file
---@return boolean success Whether the file was successfully registered
function M.register_file(file_id, file_path)
  -- Parameter validation
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(file_path) == "string", "file_path must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Register mappings in both directions
  file_map[file_id] = file_path
  file_map[file_path] = file_id
  
  -- Initialize data structures for this file
  if not execution_data[file_id] then
    execution_data[file_id] = {}
  end
  
  if not coverage_data[file_id] then
    coverage_data[file_id] = {}
  end
  
  return true
end

--- Register a source map for a file to enable line number mapping
---@param file_id string The unique identifier for the file
---@param sourcemap table The source map with mapping between original and instrumented lines
---@return boolean success Whether the sourcemap was successfully registered
function M.register_sourcemap(file_id, sourcemap)
  -- Parameter validation
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(sourcemap) == "table", "sourcemap must be a table", error_handler.CATEGORY.VALIDATION)
  
  sourcemaps[file_id] = sourcemap
  return true
end

-- Mark a line as executed
---@param file_id string The unique identifier for the file
---@param line_number number The line number that was executed
function M.track(file_id, line_number)
  -- Only track if active
  if not tracking_active then
    return
  end
  
  -- Parameter validation
  if type(file_id) ~= "string" or type(line_number) ~= "number" then
    return -- Silent failure for performance reasons
  end
  
  -- Initialize data structures if needed
  if not execution_data[file_id] then
    execution_data[file_id] = {}
  end
  
  -- Mark line as executed
  execution_data[file_id][line_number] = (execution_data[file_id][line_number] or 0) + 1
  
  -- Log for debugging
  logger.debug("Tracked line execution", {
    file_id = file_id,
    line_number = line_number,
    execution_count = execution_data[file_id][line_number]
  })
end

-- Mark a line as covered (executed + verified by assertions)
---@param file_id string The unique identifier for the file
---@param line_number number The line number that was covered
function M.mark_covered(file_id, line_number)
  -- Only track if active
  if not tracking_active then
    return
  end
  
  -- Parameter validation
  error_handler.assert(type(file_id) == "string", "file_id must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(line_number) == "number", "line_number must be a number", error_handler.CATEGORY.VALIDATION)
  
  -- Initialize data structures if needed
  if not execution_data[file_id] then
    execution_data[file_id] = {}
  end
  
  if not coverage_data[file_id] then
    coverage_data[file_id] = {}
  end
  
  -- Mark line as executed
  execution_data[file_id][line_number] = (execution_data[file_id][line_number] or 0) + 1
  
  -- Mark line as covered
  coverage_data[file_id][line_number] = true
end

-- Get the current tracking data
---@return table data The current tracking data
function M.get_data()
  return {
    execution_data = execution_data,
    coverage_data = coverage_data,
    file_map = file_map,
    sourcemaps = sourcemaps
  }
end

return M