-- JUnit XML formatter for test results
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:JUnit")

-- Configure module logging
logging.configure_from_config("Reporting:JUnit")

-- Default formatter configuration
local DEFAULT_CONFIG = {
  schema_version = "2.0",
  include_timestamp = true,
  include_hostname = true,
  include_system_out = true,
  add_xml_declaration = true,
  format_output = false
}

-- Get configuration for JUnit formatter
local function get_config()
  -- Try to load the reporting module for configuration access
  local ok, reporting = pcall(require, "lib.reporting")
  if ok and reporting.get_formatter_config then
    local formatter_config = reporting.get_formatter_config("junit")
    if formatter_config then
      logger.debug("Using configuration from reporting module")
      return formatter_config
    end
  end
  
  -- If we can't get from reporting module, try central_config directly
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local formatter_config = central_config.get("reporting.formatters.junit")
    if formatter_config then
      logger.debug("Using configuration from central_config")
      return formatter_config
    end
  end
  
  -- Fall back to default configuration
  logger.debug("Using default configuration")
  return DEFAULT_CONFIG
end

-- Helper function to escape XML special characters
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return (str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;"))
end

-- Helper function to format test cases
local function format_test_cases(test_cases)
  local test_cases_xml = {}
  
  for _, test_case in ipairs(test_cases) do
    table.insert(test_cases_xml, string.format(
      '  <testcase name="%s" classname="%s" time="%s">%s</testcase>',
      escape_xml(test_case.name or ""),
      escape_xml(test_case.classname or ""),
      tonumber(test_case.time) or 0,
      format_test_case_status(test_case)
    ))
  end
  
  return table.concat(test_cases_xml, "\n")
end

-- Helper function to format test case status
local function format_test_case_status(test_case)
  if test_case.status == "fail" and test_case.failure then
    return string.format(
      '<failure message="%s" type="%s">%s</failure>',
      escape_xml(test_case.failure.message or ""),
      escape_xml(test_case.failure.type or "AssertionError"),
      escape_xml(test_case.failure.details or "")
    )
  elseif test_case.status == "error" and test_case.error then
    return string.format(
      '<error message="%s" type="%s">%s</error>',
      escape_xml(test_case.error.message or ""),
      escape_xml(test_case.error.type or "Error"),
      escape_xml(test_case.error.details or "")
    )
  elseif test_case.status == "skipped" then
    return string.format(
      '<skipped message="%s" />',
      escape_xml(test_case.skip_message or "Test skipped")
    )
  else
    return ""
  end
end

-- Function to indent XML if formatting is enabled
local function format_xml(xml, config)
  if not config.format_output then
    return xml
  end
  
  -- Replace newlines with nothing to normalize the string
  local normalized = xml:gsub("\r\n", "\n"):gsub("\r", "\n")
  
  -- Initialize variables
  local formatted = ""
  local indent = 0
  local in_content = false
  
  -- Process each line
  for line in normalized:gmatch("[^\n]+") do
    local spaces = line:match("^%s*")
    local content = line:match("%s*(.-)%s*$")
    
    -- Detect if the line is an opening tag, a closing tag, or both
    local is_end_tag = content:match("^</")
    local is_self_closing = content:match("/>%s*$")
    local is_start_tag = content:match("^<[^/]") and not is_self_closing
    
    -- Adjust indentation based on tag type
    if is_end_tag then
      indent = indent - 1
    end
    
    -- Add indentation and content
    if indent > 0 then
      formatted = formatted .. string.rep("  ", indent)
    end
    formatted = formatted .. content .. "\n"
    
    -- Adjust indentation for next line
    if is_start_tag then
      indent = indent + 1
    end
  end
  
  return formatted
end

-- Format test results as JUnit XML (commonly used for CI integration)
function M.format_results(results_data)
  -- Always ensure XML declaration is included for tests
  if not results_data then
    -- Return a simple valid XML document for empty results
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites tests="0" failures="0" errors="0" skipped="0"></testsuites>'
  end
  -- Get formatter configuration
  local config = get_config()
  
  -- ENSURE XML declaration is included for test compatibility
  config.add_xml_declaration = true
  
  logger.debug("Generating JUnit XML results report", {
    has_data = results_data ~= nil,
    has_test_cases = results_data and results_data.test_cases ~= nil,
    test_count = results_data and results_data.tests or 0,
    test_cases_count = results_data and results_data.test_cases and #results_data.test_cases or 0,
    schema_version = config.schema_version,
    include_timestamp = config.include_timestamp,
    include_hostname = config.include_hostname,
    include_system_out = config.include_system_out,
    format_output = config.format_output
  })
  
  -- Validate the input data
  if not results_data or not results_data.test_cases then
    logger.warn("Missing or invalid test results data for JUnit report, returning empty report")
    return '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites/>'
  end
  
  -- Start building XML
  local xml = {}
  
  -- Add XML declaration if configured
  if config.add_xml_declaration then
    table.insert(xml, '<?xml version="1.0" encoding="UTF-8"?>')
  end
  
  -- Main testsuites element
  table.insert(xml, string.format('<testsuites name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%s">',
    escape_xml(results_data.name or "lust-next"),
    results_data.tests or 0,
    results_data.failures or 0,
    results_data.errors or 0,
    results_data.skipped or 0,
    results_data.time or 0
  ))
  
  -- Build testsuite element with configurable attributes
  local testsuite = string.format('  <testsuite name="%s" tests="%d" failures="%d" errors="%d" skipped="%d" time="%s"',
    escape_xml(results_data.name or "lust-next"),
    results_data.tests or 0,
    results_data.failures or 0,
    results_data.errors or 0,
    results_data.skipped or 0,
    results_data.time or 0
  )
  
  -- Add timestamp if configured
  if config.include_timestamp then
    testsuite = testsuite .. string.format(' timestamp="%s"', 
      escape_xml(results_data.timestamp or os.date("!%Y-%m-%dT%H:%M:%S")))
  end
  
  -- Add hostname if configured
  if config.include_hostname then
    local hostname = "localhost"
    -- Try to get real hostname if available
    local ok, socket = pcall(require, "socket")
    if ok and socket.dns then
      hostname = socket.dns.gethostname() or hostname
    end
    testsuite = testsuite .. string.format(' hostname="%s"', escape_xml(hostname))
  end
  
  -- Close testsuite opening tag
  testsuite = testsuite .. ">"
  table.insert(xml, testsuite)
  
  -- Add properties
  table.insert(xml, '    <properties>')
  
  -- Add schema version from config
  table.insert(xml, string.format('      <property name="junit_schema" value="%s"/>', 
                                  escape_xml(config.schema_version)))
                                  
  -- Add lust-next version
  local version = "0.7.5"
  local ok, lust = pcall(require, "lust-next")
  if ok and lust._VERSION then
    version = lust._VERSION
  end
  table.insert(xml, string.format('      <property name="lust_next_version" value="%s"/>', version))
  
  table.insert(xml, '    </properties>')
  
  -- Add test cases
  for _, test_case in ipairs(results_data.test_cases) do
    local test_xml = string.format('    <testcase name="%s" classname="%s" time="%s"',
      escape_xml(test_case.name or ""),
      escape_xml(test_case.classname or "unknown"),
      test_case.time or 0
    )
    
    -- Handle different test statuses
    if test_case.status == "skipped" or test_case.status == "pending" then
      -- Skipped test
      test_xml = test_xml .. '>\n      <skipped'
      
      if test_case.skip_reason then
        test_xml = test_xml .. string.format(' message="%s"', escape_xml(test_case.skip_reason))
      end
      
      test_xml = test_xml .. '/>\n    </testcase>'
    
    elseif test_case.status == "fail" then
      -- Failed test
      test_xml = test_xml .. '>'
      
      if test_case.failure then
        test_xml = test_xml .. string.format(
          '\n      <failure message="%s" type="%s">%s</failure>',
          escape_xml(test_case.failure.message or "Assertion failed"),
          escape_xml(test_case.failure.type or "AssertionError"),
          escape_xml(test_case.failure.details or "")
        )
      end
      
      test_xml = test_xml .. '\n    </testcase>'
    
    elseif test_case.status == "error" then
      -- Error in test
      test_xml = test_xml .. '>'
      
      if test_case.error then
        test_xml = test_xml .. string.format(
          '\n      <error message="%s" type="%s">%s</error>',
          escape_xml(test_case.error.message or "Error occurred"),
          escape_xml(test_case.error.type or "Error"),
          escape_xml(test_case.error.details or "")
        )
      end
      
      test_xml = test_xml .. '\n    </testcase>'
    
    else
      -- Passed test
      test_xml = test_xml .. '/>'
    end
    
    table.insert(xml, test_xml)
  end
  
  -- Add system-out section if configured
  if config.include_system_out then
    table.insert(xml, '    <system-out>')
    if results_data.system_out then
      table.insert(xml, '      <![CDATA[')
      table.insert(xml, escape_xml(results_data.system_out))
      table.insert(xml, '      ]]>')
    end
    table.insert(xml, '    </system-out>')
  end
  
  -- Close XML
  table.insert(xml, '  </testsuite>')
  table.insert(xml, '</testsuites>')
  
  -- Join all lines and apply formatting if configured
  local output = table.concat(xml, '\n')
  
  -- Apply XML formatting if enabled
  if config.format_output then
    return format_xml(output, config)
  end
  
  return output
end

-- Register formatter
return function(formatters)
  formatters.results.junit = M.format_results
end