# Logging Guide

This guide explains how to use the lust-next logging system in your projects.

## Overview

The lust-next testing framework includes a comprehensive centralized logging system that provides:

- Multiple log levels (ERROR, WARN, INFO, DEBUG, VERBOSE)
- Module-specific log configuration
- Formatted console output with timestamps and colors
- File output with automatic log rotation
- Integration with the global configuration system
- Convenient API for module authors

## Getting Started

### Basic Usage

To use the logging system in your module:

```lua
-- Import the logging module
local logging = require("lib.tools.logging")

-- Create a logger for your module
local logger = logging.get_logger("my_module")

-- Configure logging from global config (recommended)
logging.configure_from_config("my_module")

-- Use the logger
logger.info("Initializing my_module...")
logger.debug("Configuration loaded with 5 options")
logger.error("Failed to load file: my_file.lua")
```

### Log Levels

The logging system supports five log levels, ordered by priority:

| Level | Value | Description | Usage |
|-------|-------|-------------|-------|
| ERROR | 1 | Critical errors | Report issues that prevent normal operation |
| WARN | 2 | Warnings | Report concerning but non-critical issues |
| INFO | 3 | Information | Report important state changes |
| DEBUG | 4 | Debug information | Detailed information for debugging |
| VERBOSE | 5 | Verbose | Extremely detailed execution information |

Messages are only displayed if their level is less than or equal to the configured level. For example, if the log level is set to INFO (3), then ERROR, WARN, and INFO messages will be displayed, but DEBUG and VERBOSE messages will be hidden.

## Configuration Methods

The logging system can be configured in several ways:

### 1. Global Configuration File

The recommended approach is to use the global configuration file (`.lust-next-config.lua`). This allows centralized control of logging behavior across your project.

```lua
-- In .lust-next-config.lua
return {
  -- Other configuration...
  
  logging = {
    level = 3,  -- Global log level (INFO)
    timestamps = true,
    use_colors = true,
    output_file = "my_project.log",
    log_dir = "logs",
    max_file_size = 10 * 1024 * 1024,  -- 10MB
    max_log_files = 5,
    
    -- Module-specific log levels
    modules = {
      coverage = 4,   -- DEBUG level for coverage module
      parser = 2,     -- WARN level for parser
      my_module = 3   -- INFO level for my_module
    }
  }
}
```

Then in your module:

```lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("my_module")
logging.configure_from_config("my_module")
```

### 2. Command-Line Options

You can configure log levels based on command-line options:

```lua
local logging = require("lib.tools.logging")
local logger = logging.get_logger("my_module")

-- Parse command-line options
local options = parse_args(arg)

-- Configure logging based on options
logging.configure_from_options("my_module", options)
```

This is useful for temporary debugging:

```bash
lua my_script.lua --debug    # Sets DEBUG level
lua my_script.lua --verbose  # Sets VERBOSE level
```

### 3. Direct Configuration

You can also configure the logging system directly:

```lua
local logging = require("lib.tools.logging")

-- Global configuration
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "my_log.log",
  log_dir = "logs"
})

-- Module-specific configuration
logging.set_module_level("my_module", logging.LEVELS.VERBOSE)
```

## Log File Management

### Log Directory

By default, log files are stored in the `logs` directory. This directory is automatically created if it doesn't exist.

### Log Rotation

The logging system automatically rotates log files when they reach a specified size:

1. When `my_log.log` reaches `max_file_size`, it's renamed to `my_log.log.1`
2. If `my_log.log.1` already exists, it's renamed to `my_log.log.2`, and so on
3. The system keeps up to `max_log_files` rotated logs

This prevents log files from growing too large while preserving history.

Configuration options:

```lua
logging.configure({
  output_file = "my_log.log",
  log_dir = "logs",
  max_file_size = 10 * 1024 * 1024,  -- 10MB
  max_log_files = 5                  -- Keep 5 rotated files
})
```

## Performance Optimization

### Check Level Before Expensive Operations

To avoid performance overhead when generating complex debug messages:

```lua
if logger.is_debug_enabled() then
  -- Only perform expensive operations if debug logging is enabled
  local details = gather_expensive_debug_details()
  logger.debug("Debug details: " .. details)
end
```

### Practical Example

```lua
function process_file(file_path)
  logger.info("Processing file: " .. file_path)
  
  -- Only gather detailed stats if debug logging is enabled
  if logger.is_debug_enabled() then
    local stats = fs.get_file_stats(file_path)
    logger.debug("File stats: size=" .. stats.size .. ", modified=" .. stats.mtime)
  end
  
  -- Do processing...
  
  logger.info("Finished processing file: " .. file_path)
end
```

## Integration with lust-next Modules

The logging system is integrated with all core lust-next modules. Each module configures logging automatically based on the global configuration:

- Coverage module
- Reporting module
- Parser module
- Watcher module
- Interactive CLI
- Filesystem utilities

You can control the verbosity of each module independently through the `logging.modules` configuration.

## Best Practices

1. **Use module-specific loggers**: Create a separate logger for each module
   ```lua
   local logger = logging.get_logger("module_name")
   ```

2. **Use configure_from_config**: Let global config control log levels
   ```lua
   logging.configure_from_config("module_name")
   ```

3. **Include context in messages**: Provide enough information to understand logs
   ```lua
   logger.info("Processing file: " .. file_path)
   ```

4. **Choose appropriate log levels**:
   - ERROR: Only for critical errors that prevent operation
   - WARN: For concerning but non-critical issues
   - INFO: For important state changes visible to users
   - DEBUG: For developer information useful for troubleshooting
   - VERBOSE: For extremely detailed execution information

5. **Check level before expensive operations**:
   ```lua
   if logger.is_debug_enabled() then
     -- Expensive operations here
   end
   ```

## Examples

Check these example files to see the logging system in action:

- `examples/logging_example.lua`: Basic logging usage
- `examples/logging_config_example.lua`: Configuration through global config
- `examples/logging_rotation_test.lua`: Log file rotation

## Reference

For complete API documentation, see the [Logging API Reference](../api/logging.md).