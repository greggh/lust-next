# Firmo Logging Examples

This document provides comprehensive examples of using the firmo logging system, demonstrating various features and integration patterns.

## Basic Usage Example

```lua
-- Basic logging example with different levels and module-specific configuration
local logging = require("lib.tools.logging")

-- Configure global logging
logging.configure({
  level = logging.LEVELS.INFO,     -- Global level
  timestamps = true,               -- Show timestamps
  use_colors = true,               -- Use ANSI colors
  output_file = "app.log",         -- Write to file
  log_dir = "logs"                 -- Log directory
})

-- Create loggers for different modules
local app_logger = logging.get_logger("App")
local db_logger = logging.get_logger("Database")
local ui_logger = logging.get_logger("UI")

-- Set specific log levels for some modules
logging.set_module_level("Database", logging.LEVELS.WARN)  -- Less verbose
logging.set_module_level("UI", logging.LEVELS.DEBUG)       -- More verbose

-- Application logs (INFO level)
app_logger.error("Critical application error")
app_logger.warn("Application warning")
app_logger.info("Application information")
app_logger.debug("Debug information - not shown with INFO level")

-- Database logs (WARN level)
db_logger.error("Database connection error")
db_logger.warn("Slow query warning")
db_logger.info("Database info - not shown with WARN level")

-- UI logs (DEBUG level)
ui_logger.info("UI component loaded")
ui_logger.debug("UI render details") -- Shows because UI is set to DEBUG level

-- Log with structured context data
app_logger.info("User authentication successful", {
  user_id = 12345,
  username = "example_user",
  login_time = os.time(),
  session_id = "sess_abc123"
})

-- Error with detailed context
db_logger.error("Database query failed", {
  query = "SELECT * FROM users WHERE id = ?",
  params = {42},
  error_code = "ER_ACCESS_DENIED",
  db_host = "localhost",
  retry_attempt = 2
})
```

## Configuration with Central Config

```lua
-- In your .firmo-config.lua file:
return {
  -- Other configuration...
  
  logging = {
    level = 3,  -- INFO level
    timestamps = true,
    use_colors = true,
    output_file = "app.log",
    log_dir = "logs",
    max_file_size = 10 * 1024 * 1024,  -- 10MB
    max_log_files = 5,
    
    -- Module-specific log levels
    module_levels = {
      coverage = 4,   -- DEBUG level for coverage module
      database = 2,   -- WARN level for database
      ui = 3          -- INFO level for UI
    }
  }
}

-- In your modules:
local logging = require("lib.tools.logging")
local logger = logging.get_logger("database")
logging.configure_from_config("database")

-- Use the logger
logger.warn("Connection pool saturated") -- Will appear (WARN level)
logger.info("Query executed") -- Won't appear (below WARN level)
```

## Log Rotation Example

```lua
-- Example demonstrating log rotation
local logging = require("lib.tools.logging")

-- Configure with a small size limit for demonstration
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "rotation_demo.log",
  log_dir = "logs",
  max_file_size = 10 * 1024,      -- 10KB (small for demo)
  max_log_files = 3               -- Keep 3 rotated files
})

local logger = logging.get_logger("rotation_demo")

-- Generate enough log entries to trigger rotation
for i = 1, 100 do
  logger.info("Log entry " .. i)
  
  -- Add some larger entries periodically
  if i % 10 == 0 then
    logger.debug("Detailed state information", {
      index = i,
      large_data = string.rep("data", 50),  -- Generate some bulk
      timestamp = os.time()
    })
  end
end

-- After running, you'll see:
-- logs/rotation_demo.log     (current log)
-- logs/rotation_demo.log.1   (first rotated log)
-- logs/rotation_demo.log.2   (second rotated log)
-- The oldest logs will be deleted when max_log_files is exceeded
```

## Structured Logging with JSON Output

```lua
-- Example demonstrating structured logging with JSON output
local logging = require("lib.tools.logging")

-- Configure with JSON output
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  output_file = "text_log.log",
  json_file = "structured_log.json",
  log_dir = "logs",
  format = "text",              -- Console/text file format
  standard_metadata = {         -- Added to all JSON log entries
    app_version = "1.0.0",
    environment = "development"
  }
})

local logger = logging.get_logger("json_example")

-- Simple log with context data
logger.info("Application started", {
  startup_time_ms = 230,
  config_file = "app.conf"
})

-- Complex nested data
logger.debug("System state", {
  memory = {
    total = 8 * 1024 * 1024,
    used = 3 * 1024 * 1024,
    free = 5 * 1024 * 1024
  },
  cpu_usage = 0.35,
  active_connections = 12,
  cache_stats = {
    hits = 342,
    misses = 18,
    efficiency = 0.95
  }
})

-- The JSON file will contain:
-- {"timestamp":"2025-03-26T10:15:32","level":"INFO","module":"json_example","message":"Application started","params":{"startup_time_ms":230,"config_file":"app.conf"},"app_version":"1.0.0","environment":"development"}
-- {"timestamp":"2025-03-26T10:15:32","level":"DEBUG","module":"json_example","message":"System state","params":{"memory":{"total":8388608,"used":3145728,"free":5242880},"cpu_usage":0.35,"active_connections":12,"cache_stats":{"hits":342,"misses":18,"efficiency":0.95}},"app_version":"1.0.0","environment":"development"}
```

## Performance Optimization Example

```lua
-- Example showing performance optimization techniques
local logging = require("lib.tools.logging")
local logger = logging.get_logger("perf_example")

-- Configure logging
logging.configure({
  level = logging.LEVELS.INFO,
  timestamps = true,
  use_colors = true,
  buffering = true,              -- Enable buffering
  buffer_size = 50,              -- Buffer size
  buffer_flush_interval = 5000   -- Flush every 5 seconds
})

-- Function that does expensive data calculation
local function calculate_expensive_metrics()
  -- Simulate expensive operation
  local start = os.clock()
  local result = {}
  
  for i = 1, 100000 do
    -- Expensive calculation
    result[i] = i * i / (i + 1)
  end
  
  local duration = os.clock() - start
  print("Calculated expensive metrics in " .. duration .. " seconds")
  
  return {
    sample_count = #result,
    average = result[50000],
    calculations_per_sec = #result / duration
  }
end

-- Example function with level check for performance
function process_data(items)
  -- This logging always happens
  logger.info("Processing items", {count = #items})
  
  -- This expensive operation only happens if debug logging is enabled
  if logger.is_debug_enabled() then
    local metrics = calculate_expensive_metrics()
    logger.debug("Performance metrics", metrics)
  end
  
  -- Process items
  for i, item in ipairs(items) do
    -- For frequent operations, check log level first
    if i % 100 == 0 and logger.is_info_enabled() then
      logger.info("Processing progress", {
        current = i,
        total = #items,
        percent_complete = (i / #items) * 100
      })
    end
  end
  
  logger.info("Processing complete", {
    items_processed = #items,
    duration_ms = 1000 -- In a real app, measure this
  })
end

-- Call with sample data
local items = {}
for i = 1, 1000 do
  items[i] = {id = i, value = "item" .. i}
end

process_data(items)

-- Don't forget to flush at the end when using buffering
logging.flush()
```

## Error Handling Integration Example

```lua
-- Example demonstrating integration with error handling
local firmo = require("firmo")
local logging = require("lib.tools.logging")
local error_handler = require("lib.tools.error_handler")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure logging
logging.configure({
  level = logging.LEVELS.INFO,
  timestamps = true,
  use_colors = true
})

-- Create a logger
local logger = logging.get_logger("error_example")

-- Create a module with error handling
local calculator = {
  divide = function(a, b)
    -- Input validation
    if type(a) ~= "number" or type(b) ~= "number" then
      return nil, error_handler.validation_error(
        "Both arguments must be numbers",
        {a_type = type(a), b_type = type(b)}
      )
    end
    
    -- Division by zero check
    if b == 0 then
      logger.error("Division by zero attempted", {a = a, b = b})
      return nil, error_handler.validation_error(
        "Division by zero",
        {operation = "divide", b = b}
      )
    end
    
    -- Success case
    logger.debug("Performing division", {a = a, b = b})
    return a / b
  end
}

-- Normal operation
local result, err = calculator.divide(10, 2)
if result then
  logger.info("Division result", {result = result})
else
  logger.error("Division failed", {
    error = error_handler.format_error(err),
    error_category = err.category
  })
end

-- Error case with proper structured logging
local result, err = calculator.divide(10, 0)
if err then
  logger.error("Division failed", {
    error = error_handler.format_error(err),
    error_category = err.category,
    a = 10,
    b = 0
  })
}

-- Test with expected error
describe("Calculator", function()
  it("should handle division by zero", { expect_error = true }, function()
    -- This error will be downgraded to DEBUG level with [EXPECTED] prefix
    -- in the logs, because of the expect_error = true flag
    local result, err = calculator.divide(10, 0)
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Division by zero")
  end)
end)

-- After running tests with expected errors, you can access them
local expected_errors = error_handler.get_expected_test_errors()
for i, err in ipairs(expected_errors) do
  print("Expected error " .. i .. ": " .. err.message)
end
```

## Test Formatter Integration Example

```lua
-- Example demonstrating integration with test formatters
local firmo = require("firmo")
local logging = require("lib.tools.logging")
local formatter_integration = require("lib.tools.logging.formatter_integration")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "test_logs.log",
  log_dir = "logs"
})

-- Enhance formatters with logging capabilities
formatter_integration.enhance_formatters()

-- Create a test-specific logger with context
local test_logger = formatter_integration.create_test_logger(
  "Calculator Test",
  { component = "math", type = "unit" }
)

-- Mock calculator for testing
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then error("Division by zero") end
    return a / b
  end
}

-- Test suite with logging
describe("Calculator", function()
  -- Log test initialization
  test_logger.info("Initializing calculator test")
  
  it("should add two numbers correctly", function()
    -- Create a step-specific logger
    local step_logger = test_logger.step("Addition Test")
    
    -- Log the test values
    step_logger.debug("Testing addition", {a = 5, b = 3, expected = 8})
    
    -- Perform the test
    local result = calculator.add(5, 3)
    
    -- Log the result
    step_logger.debug("Got result", {actual = result})
    
    -- Verify the result
    expect(result).to.equal(8)
    
    -- Log test completion
    step_logger.info("Addition test passed")
  end)
  
  it("should subtract two numbers correctly", function()
    local step_logger = test_logger.step("Subtraction Test")
    step_logger.debug("Testing subtraction", {a = 10, b = 4, expected = 6})
    
    local result = calculator.subtract(10, 4)
    expect(result).to.equal(6)
    
    step_logger.info("Subtraction test passed")
  end)
  
  it("should handle division by zero", { expect_error = true }, function()
    local error_logger = test_logger.step("Division by Zero Test")
    error_logger.debug("Testing division by zero", {a = 10, b = 0})
    
    expect(function()
      calculator.divide(10, 0)
    end).to.fail()
    
    error_logger.info("Division by zero test passed")
  end)
  
  -- Log test suite completion
  test_logger.info("Calculator test completed")
end)
```

## Log Export Example

```lua
-- Example demonstrating log export to external platforms
local logging = require("lib.tools.logging")
local log_export = require("lib.tools.logging.export")

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "app.log",
  json_file = "app.json",
  log_dir = "logs"
})

local logger = logging.get_logger("export_example")

-- Generate sample logs
logger.info("Application started")
logger.debug("Initializing components", {
  components = {"database", "api", "ui"}
})
logger.error("Failed to connect to service", {
  service = "payment-gateway",
  error_code = "ECONNREFUSED",
  retry_count = 3
})

-- Flush logs to ensure they're written
logging.flush()

-- Get supported platforms
local platforms = log_export.get_supported_platforms()
-- Returns: {"elasticsearch", "logstash", "splunk", "datadog", "loki"}

-- Export logs to each platform
for _, platform in ipairs(platforms) do
  -- Export to platform format
  local result = log_export.create_platform_file(
    "logs/app.json",           -- Source JSON logs
    platform,                  -- Target platform
    "logs/export_" .. platform .. ".json",
    {                          -- Platform-specific options
      environment = "development",
      service_name = "firmo-example"
    }
  )
  
  if result then
    print("Exported " .. result.entries_processed .. " entries to " .. platform)
  end
  
  -- Create configuration file for the platform
  local config_result = log_export.create_platform_config(
    platform,
    "logs/config_" .. platform .. ".conf",
    {
      environment = "development",
      service = "firmo-example"
    }
  )
  
  if config_result then
    print("Created " .. platform .. " configuration")
  end
end

-- Create a real-time exporter
local exporter = log_export.create_realtime_exporter(
  "elasticsearch",
  {
    es_host = "localhost:9200",
    index = "firmo-logs",
    environment = "development"
  }
)

-- Export a log entry in real-time
local log_entry = {
  timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
  level = "INFO",
  module = "export_example",
  message = "Real-time log export example",
  params = {
    transaction_id = "tx-123",
    operation = "export"
  }
}

local formatted = exporter.export(log_entry)
print("Exported log entry to Elasticsearch format")
```

## Silent Mode Example

```lua
-- Example demonstrating silent mode for testing
local firmo = require("firmo")
local logging = require("lib.tools.logging")

-- Extract testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Function under test that uses logging
local function process_with_logging(data)
  local logger = logging.get_logger("processor")
  
  logger.info("Processing data", {size = #data})
  
  local result = {}
  for i, value in ipairs(data) do
    logger.debug("Processing item", {index = i, value = value})
    result[i] = value * 2
  end
  
  logger.info("Processing complete", {output_size = #result})
  return result
end

-- Test that verifies function output not logging
describe("Processor", function()
  -- Enable silent mode for this test
  logging.silent_mode(true)
  
  it("should double all values", function()
    local input = {1, 2, 3, 4, 5}
    local expected = {2, 4, 6, 8, 10}
    
    local result = process_with_logging(input)
    
    expect(result).to.equal(expected)
  end)
  
  -- Restore normal logging
  logging.silent_mode(false)
end)
```

## Command-Line Option Integration

```lua
-- Example showing integration with command-line options
local logging = require("lib.tools.logging")

-- Parse command-line arguments
local function parse_args(args)
  local options = {
    debug = false,
    verbose = false,
    quiet = false
  }
  
  for _, arg in ipairs(args) do
    if arg == "--debug" then
      options.debug = true
    elseif arg == "--verbose" then
      options.verbose = true
    elseif arg == "--quiet" then
      options.quiet = true
    end
  end
  
  return options
end

-- Configure logging based on command-line options
local options = parse_args(arg)
logging.configure_from_options("cli_example", options)

local logger = logging.get_logger("cli_example")

-- These logs will appear or not based on the command-line options:
-- lua example.lua             # INFO and above
-- lua example.lua --debug     # DEBUG and above
-- lua example.lua --verbose   # TRACE (all levels)
-- lua example.lua --quiet     # ERROR and above only

logger.error("This is an error message")   -- Always shown unless --quiet
logger.warn("This is a warning message")   -- Not shown with --quiet
logger.info("This is an info message")     -- Standard visibility
logger.debug("This is a debug message")    -- Only with --debug or --verbose
logger.trace("This is a trace message")    -- Only with --verbose
```