-- V3 Coverage Reporting Module
-- Handles report generation and validation

local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("coverage.v3.reporting")

local M = {
  _VERSION = "3.0.0"
}

-- Create a new report from coverage data
---@param data table Coverage data from data store
---@param config table Coverage configuration
---@return CoverageReport report Generated report
function M.create_report(data, config)
  local report = {
    files = {},
    assertions = {},
    statistics = {
      total_lines = 0,
      executed_lines = 0,
      covered_lines = 0,
      total_functions = 0,
      executed_functions = 0,
      covered_functions = 0,
      total_assertions = 0,
      async_assertions = 0
    },
    metadata = {
      timestamp = os.time(),
      version = M._VERSION,
      config = config
    }
  }
  
  -- Process file coverage
  for file, file_data in pairs(data.files) do
    report.files[file] = {
      executed_lines = file_data.executed_lines,
      covered_lines = file_data.covered_lines,
      functions = file_data.functions,
      source = file_data.source,
      source_lines = file_data.source_lines,
      source_map = file_data.source_map
    }
    
    -- Update statistics
    report.statistics.total_lines = report.statistics.total_lines + #file_data.source_lines
    
    local executed_count = 0
    for _ in pairs(file_data.executed_lines) do
      executed_count = executed_count + 1
    end
    report.statistics.executed_lines = report.statistics.executed_lines + executed_count
    
    local covered_count = 0
    for _ in pairs(file_data.covered_lines) do
      covered_count = covered_count + 1
    end
    report.statistics.covered_lines = report.statistics.covered_lines + covered_count
    
    -- Count functions
    for _, func in pairs(file_data.functions) do
      report.statistics.total_functions = report.statistics.total_functions + 1
      if func.executed then
        report.statistics.executed_functions = report.statistics.executed_functions + 1
      end
      if func.covered then
        report.statistics.covered_functions = report.statistics.covered_functions + 1
      end
    end
  end
  
  -- Process assertion data
  for file, assertion_data in pairs(data.assertions) do
    report.assertions[file] = {
      assertions = assertion_data.assertions,
      covered_lines = assertion_data.covered_lines,
      async_context = assertion_data.async_context
    }
    
    -- Update statistics
    report.statistics.total_assertions = report.statistics.total_assertions + #assertion_data.assertions
    
    -- Count async assertions
    for _, assertion in ipairs(assertion_data.assertions) do
      if assertion.async_context then
        report.statistics.async_assertions = report.statistics.async_assertions + 1
      end
    end
  end
  
  return report
end

-- Validate report data structure
---@param report CoverageReport Report to validate
---@return boolean success Whether validation passed
---@return string? error Error message if validation failed
function M.validate_report(report)
  if type(report) ~= "table" then
    return false, "Report must be a table"
  end
  
  -- Check required sections
  if not report.files then
    return false, "Missing files section"
  end
  if not report.assertions then
    return false, "Missing assertions section"
  end
  if not report.statistics then
    return false, "Missing statistics section"
  end
  if not report.metadata then
    return false, "Missing metadata section"
  end
  
  -- Validate each file report
  for file, file_report in pairs(report.files) do
    if type(file_report) ~= "table" then
      return false, string.format("Invalid file report for %s", file)
    end
    if type(file_report.executed_lines) ~= "table" then
      return false, string.format("Missing executed_lines for %s", file)
    end
    if type(file_report.covered_lines) ~= "table" then
      return false, string.format("Missing covered_lines for %s", file)
    end
    if type(file_report.functions) ~= "table" then
      return false, string.format("Missing functions for %s", file)
    end
    if type(file_report.source_lines) ~= "table" then
      return false, string.format("Missing source_lines for %s", file)
    end
  end
  
  -- Validate assertion data
  for file, assertion_report in pairs(report.assertions) do
    if type(assertion_report) ~= "table" then
      return false, string.format("Invalid assertion report for %s", file)
    end
    if type(assertion_report.assertions) ~= "table" then
      return false, string.format("Missing assertions for %s", file)
    end
    if type(assertion_report.covered_lines) ~= "table" then
      return false, string.format("Missing covered_lines for %s", file)
    end
  end
  
  -- Validate statistics
  local stats = report.statistics
  if type(stats.total_lines) ~= "number" then
    return false, "Invalid total_lines in statistics"
  end
  if type(stats.executed_lines) ~= "number" then
    return false, "Invalid executed_lines in statistics"
  end
  if type(stats.covered_lines) ~= "number" then
    return false, "Invalid covered_lines in statistics"
  end
  
  -- Validate metadata
  local meta = report.metadata
  if type(meta.timestamp) ~= "number" then
    return false, "Invalid timestamp in metadata"
  end
  if type(meta.version) ~= "string" then
    return false, "Invalid version in metadata"
  end
  if type(meta.config) ~= "table" then
    return false, "Invalid config in metadata"
  end
  
  return true
end

return M