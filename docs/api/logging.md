# Logging API

The logging system in lust-next provides a centralized way to handle log messages with different severity levels, module-specific configuration, and output options.

## Basic Usage

```lua
-- Import the logging module
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")

-- Use various logging levels
logger.error("Critical error: database connection failed")
logger.warn("Warning: configuration file missing, using defaults")
logger.info("Server started on port 8080")
logger.debug("Request parameters: " .. json.encode(params))
logger.verbose("Function called with arguments: " .. table.concat(args, ", "))
```

## Log Levels

The logging system supports 5 severity levels:

| Level   | Constant          | Description                                        |
|---------|-------------------|----------------------------------------------------|
| ERROR   | logging.LEVELS.ERROR   | Critical errors that prevent normal operation     |
| WARN    | logging.LEVELS.WARN    | Unexpected conditions that don't stop execution   |
| INFO    | logging.LEVELS.INFO    | Normal operational messages                       |
| DEBUG   | logging.LEVELS.DEBUG   | Detailed information useful for debugging         |
| VERBOSE | logging.LEVELS.VERBOSE | Extremely detailed diagnostic information         |

## Configuration

### Basic Configuration

You can configure the logging system with various options:

```lua
logging.configure({
  level = logging.LEVELS.INFO,   -- Global default level
  timestamps = true,             -- Include timestamps in log messages
  use_colors = true,             -- Use ANSI colors in console output
  output_file = "lust-next.log", -- Log to file (nil = console only)
  log_dir = "logs",              -- Directory for log files
  max_file_size = 1024 * 1024,   -- 1MB max file size before rotation
  max_log_files = 5,             -- Keep 5 rotated log files
  format = "text",               -- Log format: "text" or "json"
  json_file = "lust-next.json"   -- Separate JSON structured log file
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
{"timestamp":"2025-03-10T14:32:46","level":"ERROR","module":"database","message":"Connection failed"}
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

The logging system integrates with lust-next's global configuration system:

```lua
-- In your .lust-next-config.lua file:
return {
  -- Test configuration
  filter = ".*test",
  verbose = true,
  
  -- Logging configuration
  logging = {
    level = 3,  -- INFO level
    timestamps = true,
    output_file = "lust-next.log",
    log_dir = "logs",
    module_levels = {
      coverage = 4,  -- DEBUG level for coverage module
      reporting = 2  -- WARN level for reporting module
    },
    format = "text",
    json_file = "lust-next.json",
    module_filter = {"coverage", "reporting", "test*"}
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

## Performance Considerations

- Log messages at levels below the current threshold are discarded with minimal overhead
- When logging to files, the system checks if the file needs rotation on each write
- For high-volume logging, consider setting appropriate log levels to avoid I/O bottlenecks
- The JSON structured log format has slightly higher overhead than plain text logging

## Examples

See the following examples for detailed usage:
- `examples/logging_example.lua` - Basic logging usage
- `examples/logging_config_example.lua` - Configuration options with JSON structured logging
- `examples/logging_rotation_example.lua` - Log rotation demonstration
- `examples/logging_filtering_example.lua` - Module filtering capabilities