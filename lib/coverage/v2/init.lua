---@class CoverageV2
---@field start fun(): boolean Starts coverage tracking
---@field stop fun(): boolean Stops coverage tracking
---@field reset fun(): boolean Resets coverage data
---@field is_running fun(): boolean Checks if coverage tracking is running
---@field get_report_data fun(): table|nil Gets coverage data for reporting
---@field generate_reports fun(output_dir: string, formats: string[]): boolean, string|nil Generate coverage reports in specified formats
---@field get_available_formats fun(): string[] Gets a list of available report formats
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")

-- Internal modules
local debug_hook = require("lib.coverage.v2.debug_hook")
local data_structure = require("lib.coverage.v2.data_structure")
local line_classifier = require("lib.coverage.v2.line_classifier")

-- Formatters
local formatters = require("lib.coverage.v2.formatters")

-- Version
M._VERSION = "0.1.0"

--- Starts coverage tracking
---@return boolean success Whether coverage tracking was successfully started
function M.start()
  logger.info("Starting coverage tracking (v2)")
  
  -- Initialize fresh coverage data
  local success = debug_hook.start()
  
  if not success then
    logger.error("Failed to start coverage tracking")
    return false
  end
  
  return true
end

--- Stops coverage tracking and processes the results
---@return boolean success Whether coverage tracking was successfully stopped
function M.stop()
  logger.info("Stopping coverage tracking (v2)")
  
  -- Check if tracking is running
  if not debug_hook.is_running() then
    logger.warn("Coverage tracking is not running")
    return false
  end
  
  -- Stop the debug hook
  local success = debug_hook.stop()
  if not success then
    logger.error("Failed to stop coverage tracking")
    return false
  end
  
  -- Get the collected coverage data
  local coverage_data = debug_hook.get_coverage_data()
  if not coverage_data then
    logger.error("No coverage data available after stopping tracking")
    return false
  end
  
  -- Process all files to classify lines
  for file_path, _ in pairs(coverage_data.files) do
    line_classifier.classify_lines(coverage_data, file_path)
  end
  
  -- Calculate final summary
  data_structure.calculate_summary(coverage_data)
  
  -- Validate the final data structure
  local is_valid, error_message = data_structure.validate(coverage_data)
  if not is_valid then
    logger.error("Coverage data validation failed", {
      error = error_message
    })
    return false
  end
  
  logger.info("Coverage tracking stopped successfully", {
    total_files = coverage_data.summary.total_files,
    executed_files = coverage_data.summary.executed_files,
    total_lines = coverage_data.summary.total_lines,
    executed_lines = coverage_data.summary.executed_lines,
    line_coverage_percent = coverage_data.summary.line_coverage_percent .. "%"
  })
  
  return true
end

--- Resets coverage data
---@return boolean success Whether the reset was successful
function M.reset()
  return debug_hook.reset()
end

--- Checks if coverage tracking is currently running
---@return boolean is_running Whether coverage tracking is running
function M.is_running()
  return debug_hook.is_running()
end

--- Gets the current coverage data for reporting
---@return table|nil coverage_data The coverage data or nil if not available
function M.get_report_data()
  -- Get the raw coverage data
  local coverage_data = debug_hook.get_coverage_data()
  if not coverage_data then
    return nil
  end
  
  -- Return a deep copy to prevent modification
  -- In a real implementation, we would create a deep copy here
  -- For now, we'll just return the data directly
  return coverage_data
end

--- Gets all tracked file paths
---@return string[] file_paths List of normalized file paths being tracked
function M.get_tracked_files()
  local coverage_data = debug_hook.get_coverage_data()
  if not coverage_data then
    return {}
  end
  
  local file_paths = {}
  for file_path, _ in pairs(coverage_data.files) do
    table.insert(file_paths, file_path)
  end
  
  return file_paths
end

--- Gets coverage summary
---@return table|nil summary Coverage summary statistics or nil if not available
function M.get_summary()
  local coverage_data = debug_hook.get_coverage_data()
  if not coverage_data then
    return nil
  end
  
  return coverage_data.summary
end

--- Gets coverage data for a specific file
---@param file_path string The file path
---@return table|nil file_data Coverage data for the file or nil if not available
function M.get_file_coverage(file_path)
  local coverage_data = debug_hook.get_coverage_data()
  if not coverage_data then
    return nil
  end
  
  local normalized_path = data_structure.normalize_path(file_path)
  return coverage_data.files[normalized_path]
end

--- Generates coverage reports in specified formats
---@param output_dir string Directory where reports should be saved
---@param formats string[] List of formats to generate (html, lcov, json)
---@return boolean success Whether report generation was successful
---@return string|nil error_message Error message if generation failed
function M.generate_reports(output_dir, formats)
  -- Parameter validation
  error_handler.assert(type(output_dir) == "string", "output_dir must be a string", error_handler.CATEGORY.VALIDATION)
  error_handler.assert(type(formats) == "table", "formats must be a table", error_handler.CATEGORY.VALIDATION)
  
  -- Ensure output directory exists
  local mkdir_success, mkdir_err = fs.ensure_directory_exists(output_dir)
  if not mkdir_success then
    return false, "Failed to create output directory: " .. error_handler.format_error(mkdir_err)
  end
  
  -- Normalize output path
  if output_dir:sub(-1) ~= "/" then
    output_dir = output_dir .. "/"
  end
  
  -- Get coverage data
  local coverage_data = M.get_report_data()
  if not coverage_data then
    return false, "No coverage data available"
  end
  
  -- Recalculate summary to ensure accurate data
  data_structure.calculate_summary(coverage_data)
  
  -- Track successes
  local successes = {}
  local errors = {}
  
  -- Generate reports in each requested format
  for _, format in ipairs(formats) do
    local formatter = formatters.get_formatter(format)
    if formatter then
      local output_path = output_dir .. "coverage-report-v2." .. format
      local success, err = formatter.generate(coverage_data, output_path)
      
      if success then
        table.insert(successes, format)
      else
        table.insert(errors, format .. ": " .. (err or "Unknown error"))
      end
    else
      table.insert(errors, format .. ": Unsupported format")
    end
  end
  
  -- Log results
  if #successes > 0 then
    logger.info("Generated coverage reports", {
      output_dir = output_dir,
      formats = table.concat(successes, ", "),
      total_files = coverage_data.summary.total_files,
      line_coverage = coverage_data.summary.line_coverage_percent .. "%",
      function_coverage = coverage_data.summary.function_coverage_percent .. "%"
    })
  end
  
  -- Return results
  if #errors > 0 then
    return #successes > 0, "Failed to generate some reports: " .. table.concat(errors, "; ")
  end
  
  return true
end

--- Gets a list of available report formats
---@return string[] formats List of available format names
function M.get_available_formats()
  return formatters.get_available_formats()
end

return M