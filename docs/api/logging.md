# Logging API

The logging system in firmo provides a centralized way to handle log messages with different severity levels, module-specific configuration, output options, search capabilities, external tool integration, and test result integration.

## Basic Usage

```lua
-- Import the logging module
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")

-- Use various logging levels
logger.fatal("Severe error requiring immediate attention")
logger.error("Critical error: database connection failed")
logger.warn("Warning: configuration file missing, using defaults")
logger.info("Server started on port 8080")
logger.debug("Request parameters: " .. json.encode(params))
logger.trace("Function called with arguments: " .. table.concat(args, ", "))

-- Structured logging with parameters
logger.info("User logged in", {
  user_id = 123,
  ip_address = "192.168.1.1",
  login_time = os.time()
})
```

## Log Levels

The logging system supports 6 severity levels:

| Level   | Constant          | Description                                         |
|---------|-------------------|-----------------------------------------------------|
| FATAL   | logging.LEVELS.FATAL   | Severe errors that prevent application operation   |
| ERROR   | logging.LEVELS.ERROR   | Critical errors that prevent normal operation      |
| WARN    | logging.LEVELS.WARN    | Unexpected conditions that don't stop execution    |
| INFO    | logging.LEVELS.INFO    | Normal operational messages                        |
| DEBUG   | logging.LEVELS.DEBUG   | Detailed information useful for debugging          |
| TRACE   | logging.LEVELS.TRACE   | Extremely detailed diagnostic information          |

## Configuration

### Basic Configuration

You can configure the logging system with various options:

```lua
logging.configure({
  level = logging.LEVELS.INFO,   -- Global default level
  timestamps = true,             -- Include timestamps in log messages
  use_colors = true,             -- Use ANSI colors in console output
  output_file = "firmo.log", -- Log to file (nil = console only)
  log_dir = "logs",              -- Directory for log files
  max_file_size = 1024 * 1024,   -- 1MB max file size before rotation
  max_log_files = 5,             -- Keep 5 rotated log files
  format = "text",               -- Log format: "text" or "json"
  json_file = "firmo.json",  -- Separate JSON structured log file
  buffering = false,             -- Buffer logs for higher performance
  buffer_size = 100,             -- Buffer size when buffering is enabled
  buffer_flush_interval = 5000,  -- Auto-flush buffer every 5 seconds
  silent_mode = false,           -- Disable all output (for testing)
  parameter_format = "structured" -- Format for parameter logging
})
```

### Module-Specific Levels

You can set different log levels for specific modules:

```lua
-- Set levels for specific modules
logging.set_module_level("ui", logging.LEVELS.ERROR)
logging.set_module_level("network", logging.LEVELS.DEBUG)

-- Or configure multiple modules at once
logging.configure({
  module_levels = {
    ui = logging.LEVELS.ERROR,
    network = logging.LEVELS.DEBUG,
    database = logging.LEVELS.WARN
  }
})
```

### Module Filtering

You can filter logs to only show specific modules:

```lua
-- Only show logs from the UI and API modules
logging.filter_module("ui")
logging.filter_module("api")

-- Use wildcards to match multiple modules
logging.filter_module("test*")  -- Any module starting with "test"

-- Clear filters to show all modules again
logging.clear_module_filters()
```

### Module Blacklisting

You can also exclude specific modules from logging:

```lua
-- Hide logs from the database module
logging.blacklist_module("database")

-- Use wildcards to hide multiple modules
logging.blacklist_module("debug*")  -- Hide any module starting with "debug"

-- Clear the blacklist
logging.clear_blacklist()
```

## Structured Logging (JSON)

For machine processing and log analysis tools, the logging system supports JSON structured output:

```lua
logging.configure({
  format = "text",              -- Console format remains human-readable
  json_file = "app.json",       -- Separate machine-readable JSON log
  output_file = "app.log"       -- Regular text log still available
})
```

The JSON log file format is one JSON object per line (newline-delimited JSON):

```
{"timestamp":"2025-03-10T14:32:45","level":"INFO","module":"app","message":"Application started"}
{"timestamp":"2025-03-10T14:32:46","level":"ERROR","module":"database","message":"Connection failed","params":{"host":"db.example.com","retries":3}}
```

### Structured Parameter Logging

You can attach structured parameters to any log message:

```lua
logger.info("Processing completed", {
  items_processed = 157,
  duration_ms = 432,
  success_rate = 0.98,
  source = "monthly_report"
})
```

The parameters appear in JSON logs as a `params` object and in text logs in parentheses:

```
[INFO] [my_module] Processing completed (items_processed=157, duration_ms=432, success_rate=0.98, source=monthly_report)
```

## Log Rotation

The logging system automatically rotates log files when they reach the configured size:

```lua
logging.configure({
  output_file = "app.log",     -- Log file name
  log_dir = "logs",            -- Log directory
  max_file_size = 10 * 1024,   -- 10KB max file size (small for demo)
  max_log_files = 3            -- Keep 3 rotated log files
})
```

When rotation occurs:
- The current log file (app.log) is moved to app.log.1
- Previous rotated files move up: app.log.1 → app.log.2, etc.
- The oldest rotated file is deleted if max_log_files is exceeded

## Integration with Global Config

The logging system integrates with firmo's global configuration system:

```lua
-- In your .firmo-config.lua file:
return {
  -- Test configuration
  filter = ".*test",
  verbose = true,
  
  -- Logging configuration
  logging = {
    level = 3,  -- INFO level
    timestamps = true,
    output_file = "firmo.log",
    log_dir = "logs",
    module_levels = {
      coverage = 4,  -- DEBUG level for coverage module
      reporting = 2  -- WARN level for reporting module
    },
    format = "text",
    json_file = "firmo.json",
    module_filter = {"coverage", "reporting", "test*"},
    buffering = true,
    buffer_size = 100
  }
}
```

To configure a module using the global config:

```lua
local logging = require("lib.tools.logging")
logging.configure_from_config("my_module")
```

## Checking Log Level Availability

You can check if a specific log level is enabled before performing expensive operations:

```lua
local logger = logging.get_logger("database")

if logger.is_debug_enabled() then
  -- Only do this expensive operation if debug logging is enabled
  local stats = calculate_detailed_stats()
  logger.debug("Database stats: " .. table.concat(stats, ", "))
end
```

## Log Search and Query

The logging system includes powerful search capabilities to find and analyze log entries:

```lua
local log_search = require("lib.tools.logging.search")

-- Search logs with filtering
local results = log_search.search_logs({
  log_file = "logs/application.log",
  level = "ERROR",              -- Filter by log level
  module = "database",          -- Filter by module
  message_pattern = "timeout",  -- Filter by message content
  from_date = "2025-03-01",     -- Filter by date range
  to_date = "2025-03-10",
  limit = 100                   -- Limit results (default 1000)
})

-- Process search results
print("Found " .. results.count .. " matching entries")
for i, entry in ipairs(results.entries) do
  print(entry.timestamp .. " | " .. entry.level .. " | " .. entry.message)
end

-- Use wildcard patterns for module filtering
local db_errors = log_search.search_logs({
  log_file = "logs/application.log",
  level = "ERROR",
  module = "database*"          -- Matches database.query, database.connection, etc.
})

-- Get log statistics
local stats = log_search.get_log_stats("logs/application.log")
print("Total log entries: " .. stats.total_entries)
print("Error count: " .. stats.errors)
print("Warning count: " .. stats.warnings)
print("First log: " .. stats.first_timestamp)
print("Last log: " .. stats.last_timestamp)
print("Log file size: " .. stats.file_size .. " bytes")

-- Modules with most errors
for module, count in pairs(stats.by_module) do
  print(module .. ": " .. count .. " entries")
end

-- Export logs to different formats
log_search.export_logs(
  "logs/application.log",       -- Source log file
  "logs/exported.csv",          -- Output file
  "csv",                        -- Format (csv, json, html, text)
  { source_format = "text" }    -- Options
)

-- Create a real-time log processor
local processor = log_search.get_log_processor({
  output_file = "logs/filtered.log",
  format = "json",
  level = "ERROR",              -- Only process ERROR level
  module = "database*",         -- Only process database modules
  callback = function(entry)    -- Optional processing callback
    print("Filtered log: " .. entry.message)
  end
})

-- Process a log entry
local entry = {
  timestamp = "2025-03-10 12:34:56",
  level = "ERROR",
  module = "database.connection",
  message = "Connection timeout"
}

processor.process(entry)        -- Returns true if processed (passed filters)
processor.close()               -- Close processor when done
```

## External Tool Integration

The logging system can export logs to popular log analysis platforms:

```lua
local log_export = require("lib.tools.logging.export")

-- Get supported platforms
local platforms = log_export.get_supported_platforms()
-- Returns: {"elasticsearch", "logstash", "splunk", "datadog", "loki"}

-- Create configuration file for a platform
log_export.create_platform_config(
  "elasticsearch",                  -- Platform name
  "config/elasticsearch.json",      -- Output configuration file
  { es_host = "logs.example.com" }  -- Platform-specific options
)

-- Export logs in platform-specific format
log_export.create_platform_file(
  "logs/application.log",          -- Source log file
  "splunk",                        -- Target platform
  "logs/splunk_format.json",       -- Output file
  {                                -- Platform-specific options
    source = "my-application",
    sourcetype = "firmo:application",
    environment = "production"
  }
)

-- Create real-time exporter for external platform
local exporter = log_export.create_realtime_exporter(
  "datadog",
  {
    api_key = "your-datadog-api-key",
    service = "my-service",
    environment = "production",
    tags = { "component:api", "version:1.2.3" }
  }
)

-- Export a log entry
local formatted = exporter.export({
  timestamp = "2025-03-10 12:34:56",
  level = "ERROR",
  module = "database",
  message = "Connection failed"
})

-- Get HTTP endpoint information for the platform
local endpoint = exporter.http_endpoint
-- { method = "POST", url = "https://http-intake.logs.datadoghq.com/v1/input", headers = {...} }

-- Export multiple entries in platform-specific format
local entries = log_export.export_to_platform(
  {  -- Array of log entries
    {
      timestamp = "2025-03-10 12:34:56",
      level = "ERROR",
      module = "database",
      message = "Connection failed"
    }
  },
  "loki",  -- Target platform
  { environment = "production" }  -- Platform-specific options
)
```

## Test Formatter Integration

The logging system integrates with the test reporting system:

```lua
local formatter_integration = require("lib.tools.logging.formatter_integration")

-- Enhance all test formatters with logging capabilities
formatter_integration.enhance_formatters()

-- Create a test-specific logger with context
local test_logger = formatter_integration.create_test_logger(
  "Database Connection Test",      -- Test name
  { component = "database" }       -- Test context
)

-- Log with test context
test_logger.info("Starting database connection test")
-- Result: "[INFO] [test.Database_Connection_Test] Starting database connection test (test_name=Database Connection Test, component=database)"

-- Create a step-specific logger
local step_logger = test_logger.step("Connection establishment")
step_logger.info("Connecting to database")
-- Result: "[INFO] [test.Database_Connection_Test] Connecting to database (test_name=Database Connection Test, component=database, step=Connection establishment)"

-- Integrate with the test reporting system
formatter_integration.integrate_with_reporting({
  include_parameters = true,     -- Include test parameters in logs
  log_test_starts = true,        -- Log when tests start
  log_test_completions = true    -- Log when tests complete
})

-- Create a specialized log formatter for test results
formatter_integration.create_log_formatter()

-- Use the log formatter in reporting
local reporting = require("lib.reporting")
reporting.generate(test_results, {"log"})  -- Output in log-friendly format
```

## Buffering for High-Volume Logging

For high-performance scenarios, the logging system supports buffering:

```lua
-- Enable buffering globally
logging.configure({
  buffering = true,
  buffer_size = 100,             -- Buffer size (entries)
  buffer_flush_interval = 5000,  -- Auto-flush interval (ms)
  buffer_flush_on_exit = true    -- Flush buffer on program exit
})

-- Use buffered logging
local logger = logging.get_logger("high_volume")

for i = 1, 1000 do
  logger.debug("Processing item " .. i)  -- Not written immediately
end

-- Manually flush all buffers
logging.flush_buffers()
```

## Silent Mode for Testing

When testing output-dependent code, you can enable silent mode:

```lua
-- Enable silent mode (no output)
logging.configure({ silent_mode = true })

-- No output will be produced
local logger = logging.get_logger("test")
logger.info("This won't be output anywhere")

-- Re-enable output
logging.configure({ silent_mode = false })
```

## Performance Considerations

- Log messages at levels below the current threshold are discarded with minimal overhead
- When logging to files, the system checks if the file needs rotation on each write
- Use buffering for high-volume logging scenarios to reduce I/O overhead
- Structured parameter logging adds some overhead - use sparingly for DEBUG and TRACE levels
- The JSON structured log format has slightly higher overhead than plain text logging
- Consider using the filesystem module instead of direct io.* functions for improved error handling

## Examples

See the following examples for detailed usage:
- `examples/logging_example.lua` - Basic logging usage
- `examples/logging_config_example.lua` - Configuration options with JSON structured logging
- `examples/logging_rotation_example.lua` - Log rotation demonstration
- `examples/logging_rotation_test.lua` - Testing rotation functionality
- `examples/logging_search_example.lua` - Log search and analysis features
- `examples/logging_export_example.lua` - Exporting logs to external platforms
- `examples/logging_formatter_example.lua` - Test formatter integration
- `examples/logging_buffer_example.lua` - High-performance buffered logging