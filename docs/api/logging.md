# Logging System

The lust-next testing framework includes a comprehensive logging system that provides centralized logging capabilities throughout the framework. This document explains how to configure and use the logging system in your test code.

## Overview

The logging system provides:

- Multiple log levels (ERROR, WARN, INFO, DEBUG, VERBOSE)
- Module-specific logging configuration
- Colorized console output
- File output with log rotation
- Integration with the global configuration system
- Timestamp support

## Basic Usage

### Importing the Logging Module

```lua
local logging = require("lib.tools.logging")
```

### Creating a Logger

```lua
-- Create a logger for a specific module
local logger = logging.get_logger("my_module")

-- Use the logger
logger.info("This is an informational message")
logger.debug("This is a debug message")
logger.error("An error occurred: " .. err)
logger.warn("Warning: something unexpected happened")
logger.verbose("Detailed execution information")
```

### Direct Logging

```lua
-- Log directly without a module name
logging.info("This is a general info message")
logging.error("A global error occurred")
```

## Log Levels

The logging system supports the following log levels:

| Level | Value | Description |
|-------|-------|-------------|
| ERROR | 1 | Critical errors that prevent normal operation |
| WARN | 2 | Warnings about potential issues |
| INFO | 3 | General information about operation (default) |
| DEBUG | 4 | Detailed information for debugging |
| VERBOSE | 5 | Maximum detail for in-depth troubleshooting |

## Configuration

### Direct Configuration

```lua
logging.configure({
  level = logging.LEVELS.DEBUG,       -- Global log level
  timestamps = true,                  -- Include timestamps in log messages
  use_colors = true,                  -- Use ANSI colors in console output
  output_file = "lust-next.log",      -- Log file name
  log_dir = "logs",                   -- Directory for log files
  max_file_size = 50 * 1024,          -- Max size before rotation (50KB)
  max_log_files = 5,                  -- Number of rotated files to keep
  date_pattern = "%Y-%m-%d",          -- Date pattern for timestamps
  silent = false                      -- Set to true to suppress all output
})
```

### Module-Specific Levels

```lua
-- Set different log levels for different modules
logging.set_module_level("coverage", logging.LEVELS.DEBUG)
logging.set_module_level("reporting", logging.LEVELS.INFO)
```

### Configuration from Options

```lua
-- Configure log level based on debug/verbose flags
-- Commonly used when parsing command-line options
local options = { debug = true }
logging.configure_from_options("my_module", options)
```

### Integration with Global Config

In your `.lust-next-config.lua` file:

```lua
return {
  -- Other configuration...
  
  logging = {
    level = 3,  -- INFO level
    modules = {
      coverage = 4,  -- DEBUG level for coverage module
      reporting = 2  -- WARN level for reporting module
    },
    timestamps = true,
    use_colors = true,
    output_file = "lust-next.log",
    log_dir = "logs",
    max_file_size = 50 * 1024,          -- 50KB
    max_log_files = 5
  }
}
```

In your module:

```lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("my_module")
logging.configure_from_config("my_module")
```

## Log Rotation

The logging system automatically rotates log files when they reach the configured size limit:

- When a log file reaches `max_file_size`, it is renamed to `filename.1`
- Existing rotated files are shifted (e.g., `filename.1` becomes `filename.2`)
- The system keeps up to `max_log_files` rotated files

## Checking Log Level Status

```lua
-- Check if debug logging is enabled
if logger.is_debug_enabled() then
  -- Perform expensive debug operations only if debug logging is enabled
  local details = gather_expensive_debug_details()
  logger.debug("Debug details: " .. details)
end
```

## Best Practices

1. **Create Module-Specific Loggers**
   ```lua
   local logger = logging.get_logger("my_module")
   ```

2. **Configure from Global Config**
   ```lua
   logging.configure_from_config("my_module")
   ```

3. **Use Appropriate Log Levels**
   - ERROR: Only for critical errors that prevent normal operation
   - WARN: For concerning but non-critical issues
   - INFO: For important state changes and normal operation
   - DEBUG: For developer information useful for troubleshooting
   - VERBOSE: For extremely detailed execution information

4. **Check Level Before Expensive Operations**
   ```lua
   if logger.is_debug_enabled() then
     -- Expensive debug operations here
   end
   ```

5. **Include Context Information**
   ```lua
   logger.info("Processing file: " .. filename)
   ```

## Examples

See the example scripts in the `examples` directory:

- `logging_example.lua` - Basic logging usage
- `logging_config_example.lua` - Configuration through global config
- `logging_rotation_example.lua` - Log file rotation demonstration