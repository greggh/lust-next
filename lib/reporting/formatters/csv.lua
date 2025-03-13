-- CSV formatter for test results
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:CSV")

-- Configure module logging
logging.configure_from_config("Reporting:CSV")

-- Define default configuration
local DEFAULT_CONFIG = {
  delimiter = ",",               -- Field delimiter character
  quote = "\"",                  -- Quote character for fields
  double_quote = true,           -- Double quotes for escaping
  include_header = true,         -- Include header row
  include_summary = false,       -- Include summary row at end
  date_format = "%Y-%m-%dT%H:%M:%S", -- Date format for timestamps
  fields = {                     -- Fields to include in output (in order)
    "test_id", 
    "test_suite", 
    "test_name", 
    "status", 
    "duration", 
    "message", 
    "error_type", 
    "details", 
    "timestamp"
  }
}

-- Get configuration for this formatter
local function get_config()
  -- Try reporting module first
  local ok, reporting = pcall(require, "lib.reporting")
  if ok and reporting.get_formatter_config then
    local formatter_config = reporting.get_formatter_config("csv")
    if formatter_config then return formatter_config end
  end
  
  -- Try central_config directly
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local formatter_config = central_config.get("reporting.formatters.csv")
    if formatter_config then return formatter_config end
  end
  
  -- Fall back to defaults
  return DEFAULT_CONFIG
end

-- Helper to escape CSV field values based on configuration
local function escape_csv(s, config)
  if type(s) ~= "string" then
    return tostring(s or "")
  end
  
  local needs_quotes = false
  
  -- Check if the string contains characters requiring quotes
  if s:find('[' .. config.delimiter .. config.quote .. '\r\n]') then
    needs_quotes = true
  end
  
  if needs_quotes then
    if config.double_quote then
      -- Double the quote characters for escaping
      local escaped = s:gsub(config.quote, config.quote .. config.quote)
      return config.quote .. escaped .. config.quote
    else
      -- Simple quoting without doubling
      return config.quote .. s .. config.quote
    end
  else
    return s
  end
end

-- Helper to create a CSV line from field values
local function csv_line(config, ...)
  local fields = {...}
  for i, field in ipairs(fields) do
    fields[i] = escape_csv(field, config)
  end
  return table.concat(fields, config.delimiter)
end

-- Format test results as CSV (comma-separated values)
function M.format_results(results_data)
  local config = get_config() or DEFAULT_CONFIG
  
  -- Ensure config.fields exists
  if not config.fields then
    config.fields = DEFAULT_CONFIG.fields
    logger.warn("Missing fields in CSV formatter config, using defaults", {
      config_source = config ~= DEFAULT_CONFIG and "custom" or "default"
    })
  end
  
  logger.debug("Generating CSV format test results", {
    has_data = results_data ~= nil,
    has_test_cases = results_data and results_data.test_cases ~= nil,
    test_count = results_data and results_data.test_cases and #results_data.test_cases or 0,
    failures = results_data and results_data.failures or 0,
    errors = results_data and results_data.errors or 0,
    config_fields_count = config.fields and #config.fields or 0
  })
  
  -- REMOVED: Special hardcoded test case handling for the tap_csv_format_test.lua test
  -- This was an anti-pattern where implementation knew about specific tests
  -- Implementation code should not contain test-specific behavior
  
  -- Validate the input data
  if not results_data or not results_data.test_cases then
    logger.warn("Missing or invalid test results data for CSV report, returning header only")
    if config.include_header and config.fields then
      return table.concat(config.fields, config.delimiter)
    else
      return ""
    end
  end
  
  local lines = {}
  
  -- CSV header
  if config.include_header and config.fields then
    table.insert(lines, table.concat(config.fields, config.delimiter))
  end
  
  -- Add test case results
  for i, test_case in ipairs(results_data.test_cases) do
    -- Prepare test data
    local status = test_case.status or "unknown"
    local message = ""
    local error_type = ""
    local details = ""
    
    if status == "fail" and test_case.failure then
      message = test_case.failure.message or ""
      error_type = test_case.failure.type or ""
      details = test_case.failure.details or ""
    elseif status == "error" and test_case.error then
      message = test_case.error.message or ""
      error_type = test_case.error.type or ""
      details = test_case.error.details or ""
    end
    
    -- Create a data table that will be used to generate the row
    local data = {
      test_id = i,
      test_suite = test_case.classname or "Test Suite",
      test_name = test_case.name,
      status = status,
      duration = test_case.time,
      message = message,
      error_type = error_type,
      details = details,
      timestamp = results_data.timestamp or os.date(config.date_format)
    }
    
    -- Format and add the row based on configured fields
    local row = {}
    if config.fields then
      for _, field in ipairs(config.fields) do
        table.insert(row, escape_csv(data[field], config))
      end
    else
      -- Fallback if fields are missing
      for _, field in ipairs(DEFAULT_CONFIG.fields) do
        table.insert(row, escape_csv(data[field], config))
      end
    end
    
    table.insert(lines, table.concat(row, config.delimiter))
  end
  
  -- Add summary line if configured
  if config.include_summary and #results_data.test_cases > 0 then
    -- Create summary data
    local summary_data = {
      test_id = "summary",
      test_suite = "TestSuite",
      test_name = "Summary",
      status = "info", 
      duration = results_data.time or 0,
      message = string.format("Total: %d, Pass: %d, Fail: %d, Error: %d, Skip: %d", 
        #results_data.test_cases,
        #results_data.test_cases - (results_data.failures or 0) - (results_data.errors or 0) - (results_data.skipped or 0),
        results_data.failures or 0,
        results_data.errors or 0,
        results_data.skipped or 0
      ),
      error_type = "",
      details = "",
      timestamp = results_data.timestamp or os.date(config.date_format)
    }
    
    -- Format and add the summary row
    local row = {}
    if config.fields then
      for _, field in ipairs(config.fields) do
        table.insert(row, escape_csv(summary_data[field], config))
      end
    else
      -- Fallback if fields are missing
      for _, field in ipairs(DEFAULT_CONFIG.fields) do
        table.insert(row, escape_csv(summary_data[field], config))
      end
    end
    
    table.insert(lines, table.concat(row, config.delimiter))
  end
  
  -- Join all lines with newlines
  return table.concat(lines, "\n")
end

-- Register formatter
return function(formatters)
  formatters.results.csv = M.format_results
end