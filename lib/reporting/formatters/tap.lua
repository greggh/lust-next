-- TAP (Test Anything Protocol) formatter
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:TAP")

-- Configure module logging
logging.configure_from_config("Reporting:TAP")

-- Define default configuration
local DEFAULT_CONFIG = {
  version = 13,                  -- TAP version (12 or 13)
  include_yaml_diagnostics = true, -- Include YAML diagnostics for failures
  include_summary = true,        -- Include summary comments at the end
  include_stack_traces = true,   -- Include stack traces in diagnostics
  default_skip_reason = "Not implemented yet", -- Default reason for skipped tests
  indent_yaml = 2                -- Number of spaces to indent YAML blocks
}

-- Get configuration for this formatter
local function get_config()
  -- Try reporting module first
  local ok, reporting = pcall(require, "lib.reporting")
  if ok and reporting.get_formatter_config then
    local formatter_config = reporting.get_formatter_config("tap")
    if formatter_config then return formatter_config end
  end
  
  -- Try central_config directly
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local formatter_config = central_config.get("reporting.formatters.tap")
    if formatter_config then return formatter_config end
  end
  
  -- Fall back to defaults
  return DEFAULT_CONFIG
end

-- Helper function to format test case result
local function format_test_case(test_case, test_number, config)
  -- Basic TAP test line
  local line
  
  if test_case.status == "pass" then
    line = string.format("ok %d - %s", test_number, test_case.name)
  elseif test_case.status == "pending" or test_case.status == "skipped" then
    line = string.format("ok %d - %s # SKIP %s", 
      test_number, 
      test_case.name,
      test_case.skip_message or test_case.skip_reason or config.default_skip_reason)
  else
    -- Failed or errored test
    line = string.format("not ok %d - %s", test_number, test_case.name)
    
    -- Add diagnostic info if available and configured
    if config.include_yaml_diagnostics and (test_case.failure or test_case.error) then
      local message = test_case.failure and test_case.failure.message or 
                      test_case.error and test_case.error.message or "Test failed"
      
      local details = test_case.failure and test_case.failure.details or 
                      test_case.error and test_case.error.details or ""
      
      -- Skip stack traces if configured
      if not config.include_stack_traces and details and details ~= "" then
        -- Simple stack trace removal - this is basic and could be improved
        local simplified_details = {}
        for line in details:gmatch("([^\n]+)") do
          if not line:match("stack traceback:") and not line:match("%.lua:%d+:") then
            table.insert(simplified_details, line)
          end
        end
        details = table.concat(simplified_details, "\n")
      end
      
      local indent = string.rep(" ", config.indent_yaml)
      
      local diag = {
        "  ---",
        indent .. "message: " .. (message or ""),
        indent .. "severity: " .. (test_case.status == "error" and "error" or "fail"),
        "  ..."
      }
      
      if details and details ~= "" then
        diag[3] = indent .. "data: |"
        local detail_lines = {}
        for line in details:gmatch("([^\n]+)") do
          table.insert(detail_lines, indent .. "  " .. line)
        end
        table.insert(diag, 3, table.concat(detail_lines, "\n"))
      end
      
      -- Append diagnostic lines
      line = line .. "\n" .. table.concat(diag, "\n")
    end
  end
  
  return line
end

-- Format test results as TAP (Test Anything Protocol)
function M.format_results(results_data)
  local config = get_config()
  
  logger.debug("Generating TAP format test results", {
    has_data = results_data ~= nil,
    has_test_cases = results_data and results_data.test_cases ~= nil,
    test_count = results_data and results_data.test_cases and #results_data.test_cases or 0,
    failures = results_data and results_data.failures or 0,
    errors = results_data and results_data.errors or 0,
    config = config
  })
  
  -- Validate the input data
  if not results_data or not results_data.test_cases then
    logger.warn("Missing or invalid test results data for TAP report, returning empty report")
    return "1..0\n# No tests run"
  end
  
  local lines = {}
  
  -- TAP version header
  table.insert(lines, "TAP version " .. config.version)
  
  -- Plan line with total number of tests
  local test_count = #results_data.test_cases
  table.insert(lines, string.format("1..%d", test_count))
  
  -- Add test case results
  for i, test_case in ipairs(results_data.test_cases) do
    table.insert(lines, format_test_case(test_case, i, config))
  end
  
  -- Add summary line if configured
  if config.include_summary then
    table.insert(lines, string.format("# tests %d", test_count))
    table.insert(lines, string.format("# pass %d", test_count - (results_data.failures or 0) - (results_data.errors or 0)))
    
    if results_data.failures and results_data.failures > 0 then
      table.insert(lines, string.format("# fail %d", results_data.failures))
    end
    
    if results_data.errors and results_data.errors > 0 then
      table.insert(lines, string.format("# error %d", results_data.errors))
    end
    
    if results_data.skipped and results_data.skipped > 0 then
      table.insert(lines, string.format("# skip %d", results_data.skipped))
    end
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Register formatter
return function(formatters)
  formatters.results.tap = M.format_results
end