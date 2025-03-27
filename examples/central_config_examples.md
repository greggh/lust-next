# Central Configuration Examples

This document provides practical examples for using the central configuration system in the firmo framework.

## Basic Usage Examples

### Setting and Getting Configuration Values

```lua
local central_config = require("lib.core.central_config")

-- Set some configuration values
central_config.set("debug", true)
central_config.set("coverage.threshold", 90)
central_config.set("reporting.format", "html")

-- Get configuration values
local debug_mode = central_config.get("debug")
print("Debug mode: " .. tostring(debug_mode))  -- Output: Debug mode: true

local threshold = central_config.get("coverage.threshold")
print("Coverage threshold: " .. threshold)  -- Output: Coverage threshold: 90

-- Get with default value (recommended pattern)
local unknown = central_config.get("unknown.value", "default")
print("Unknown value: " .. unknown)  -- Output: Unknown value: default

-- Get an entire section
local coverage = central_config.get("coverage")
print("Coverage config: threshold = " .. coverage.threshold)
```

### Setting Nested Configuration Values

```lua
local central_config = require("lib.core.central_config")

-- Set nested configuration values
central_config.set("database.connection", {
  host = "localhost",
  port = 5432,
  username = "app_user",
  password = "secret",
  pool = {
    min = 5,
    max = 20,
    timeout = 30
  }
})

-- Access nested values
local db_host = central_config.get("database.connection.host")
print("Database host: " .. db_host)  -- Output: Database host: localhost

local pool_timeout = central_config.get("database.connection.pool.timeout")
print("Connection pool timeout: " .. pool_timeout)  -- Output: Connection pool timeout: 30
```

### Method Chaining

```lua
local central_config = require("lib.core.central_config")

-- Chain multiple set operations
central_config
  .set("log.level", "debug")
  .set("log.file", "/var/log/app.log")
  .set("log.format", "json")

-- Get configuration
local log_level = central_config.get("log.level")
print("Log level: " .. log_level)  -- Output: Log level: debug
```

### Deleting Configuration Values

```lua
local central_config = require("lib.core.central_config")

-- Set some initial values
central_config.set("temporary.value", "This will be deleted")
central_config.set("permanent.value", "This will stay")

-- Delete a value
local success, err = central_config.delete("temporary.value")
if success then
  print("Value deleted successfully")
else
  print("Failed to delete value: " .. err.message)
end

-- Verify it's gone
local temp_value = central_config.get("temporary.value", "Not found")
print("Temporary value: " .. temp_value)  -- Output: Temporary value: Not found

-- Permanent value should still be there
local perm_value = central_config.get("permanent.value")
print("Permanent value: " .. perm_value)  -- Output: Permanent value: This will stay
```

## Configuration File Examples

### Creating a Configuration File

```lua
local fs = require("lib.tools.filesystem")

-- Create a configuration file with comprehensive settings
local config_content = [[
-- firmo Configuration File
return {
  -- Core settings
  debug = false,
  verbose = true,
  
  -- Coverage settings
  coverage = {
    enabled = true,
    threshold = 90,
    include = {
      "lib/**/*.lua",
      "src/**/*.lua"
    },
    exclude = {
      "tests/**/*.lua",
      "examples/**/*.lua"
    }
  },
  
  -- Reporting settings
  reporting = {
    format = {"html", "json", "lcov"}, -- Use multiple formats
    output_path = "./coverage-reports/",
    formatters = {
      html = {
        output_path = "coverage-reports/coverage-report.html",
        show_line_numbers = true,
        syntax_highlighting = true,
        theme = "dark",
        max_lines_display = 200,
        simplified_large_files = true
      },
      json = {
        output_path = "coverage-reports/coverage-report.json",
        pretty = true,
        truncate_content = true
      },
      lcov = {
        output_path = "coverage-reports/coverage-report.lcov"
      },
      cobertura = {
        output_path = "coverage-reports/coverage-report.cobertura"
      }
    }
  },
  
  -- Test runner settings
  test_runner = {
    parallel = true,
    workers = 4,
    timeout = 5000
  }
}
]]

-- Write the config file
fs.write_file(".firmo-config.lua", config_content)
print("Configuration file created")
```

For more detailed information about all formatter options, see [Coverage Report Formatters](../docs/guides/configuration-details/formatters.md).

### Loading a Configuration File

```lua
local central_config = require("lib.core.central_config")

-- Load from the default path (.firmo-config.lua)
local config, err = central_config.load_from_file()
if not config then
  if err.message:match("not found") then
    print("No configuration file found, using defaults")
  else
    print("Error loading configuration: " .. err.message)
  end
else
  print("Configuration loaded successfully")
  print("Coverage threshold: " .. central_config.get("coverage.threshold", 0))
end

-- Load from a custom path
local custom_config, custom_err = central_config.load_from_file("/path/to/custom-config.lua")
if custom_config then
  print("Custom configuration loaded")
end
```

### Saving a Configuration File

```lua
local central_config = require("lib.core.central_config")

-- Set some configuration values
central_config.set("app.name", "My Application")
central_config.set("app.version", "1.0.0")
central_config.set("app.settings", {
  cache_enabled = true,
  cache_ttl = 3600,
  debug = false
})

-- Save to the default path
local success, err = central_config.save_to_file()
if success then
  print("Configuration saved to .firmo-config.lua")
else
  print("Failed to save configuration: " .. err.message)
end

-- Save to a custom path
local custom_success, custom_err = central_config.save_to_file("/path/to/saved-config.lua")
if custom_success then
  print("Configuration saved to custom path")
end
```

## Module Registration Examples

### Registering a Simple Module

```lua
local central_config = require("lib.core.central_config")

-- Register a module with basic schema and defaults
central_config.register_module("http_client", {
  -- Schema definition
  field_types = {
    timeout = "number",
    base_url = "string",
    retry_count = "number"
  }
}, {
  -- Default values
  timeout = 30000,
  retry_count = 3
})

-- Access the configuration
local timeout = central_config.get("http_client.timeout")
print("HTTP timeout: " .. timeout)  -- Output: HTTP timeout: 30000
```

### Registering a Module with Comprehensive Schema

```lua
local central_config = require("lib.core.central_config")

-- Register a module with comprehensive schema validation
central_config.register_module("database", {
  -- Required fields
  required_fields = {"host", "username", "password"},
  
  -- Field types
  field_types = {
    host = "string",
    port = "number",
    username = "string",
    password = "string",
    pool_size = "number",
    timeout = "number",
    ssl = "boolean"
  },
  
  -- Value ranges
  field_ranges = {
    port = {min = 1, max = 65535},
    pool_size = {min = 1, max = 100},
    timeout = {min = 1000, max = 60000}
  },
  
  -- Pattern validation
  field_patterns = {
    host = "^[%w%.%-]+$" -- Only allow letters, numbers, dots and hyphens
  },
  
  -- Allowed values (enum-like)
  field_values = {
    dialect = {"mysql", "postgresql", "sqlite"}
  },
  
  -- Custom validators
  validators = {
    connection_string = function(value, config)
      -- Custom validation logic
      if value and not value:match("^%w+://.+$") then
        return false, "Connection string must be in format protocol://details"
      end
      return true
    end
  }
}, {
  -- Default values
  port = 5432,
  pool_size = 10,
  timeout = 5000,
  ssl = true,
  dialect = "postgresql"
})

-- Set values
central_config.set("database.host", "db.example.com")
central_config.set("database.username", "app_user")
central_config.set("database.password", "secret")

-- Validate the configuration
local valid, err = central_config.validate("database")
if valid then
  print("Database configuration is valid")
else
  print("Invalid database configuration:")
  for _, field_err in ipairs(err.context.errors) do
    print("  - " .. field_err.field .. ": " .. field_err.message)
  end
end
```

## Change Notification Examples

### Simple Change Listener

```lua
local central_config = require("lib.core.central_config")

-- Set an initial value
central_config.set("app.timeout", 5000)

-- Register a change listener
central_config.on_change("app.timeout", function(path, old_value, new_value)
  print("Timeout changed from " .. old_value .. " to " .. new_value)
  -- Update application behavior based on new timeout
end)

-- Change the value to trigger the listener
central_config.set("app.timeout", 10000)
-- Output: Timeout changed from 5000 to 10000
```

### Section-Level Change Listener

```lua
local central_config = require("lib.core.central_config")

-- Set initial values
central_config.set("logging", {
  level = "info",
  file = "/var/log/app.log",
  console = true
})

-- Register a change listener for the entire section
central_config.on_change("logging", function(path, old_value, new_value)
  print("Logging config changed at " .. path)
  
  -- The path parameter tells us exactly what changed
  if path == "logging.level" then
    print("Log level changed from " .. tostring(old_value) .. " to " .. tostring(new_value))
    -- Update logger level
  elseif path == "logging.file" then
    print("Log file changed from " .. tostring(old_value) .. " to " .. tostring(new_value))
    -- Reopen log file
  end
})

-- Change values to trigger the listener
central_config.set("logging.level", "debug")
-- Output: 
-- Logging config changed at logging.level
-- Log level changed from info to debug

central_config.set("logging.file", "/tmp/debug.log")
-- Output:
-- Logging config changed at logging.file
-- Log file changed from /var/log/app.log to /tmp/debug.log
```

### Global Change Listener

```lua
local central_config = require("lib.core.central_config")

-- Register a global change listener
central_config.on_change("", function(path, old_value, new_value)
  print("Configuration changed at " .. path)
  print("  Old value: " .. tostring(old_value))
  print("  New value: " .. tostring(new_value))
end)

-- Change various values to trigger the listener
central_config.set("app.name", "My App")
-- Output:
-- Configuration changed at app.name
--   Old value: nil
--   New value: My App

central_config.set("debug", true)
-- Output:
-- Configuration changed at debug
--   Old value: nil
--   New value: true
```

### Change Listener with Tables

```lua
local central_config = require("lib.core.central_config")
local json = require("lib.tools.json") -- Assume JSON module is available

-- Set an initial complex value
central_config.set("server.options", {
  port = 8080,
  host = "0.0.0.0",
  ssl = false
})

-- Register a change listener
central_config.on_change("server.options", function(path, old_value, new_value)
  print("Server options changed at " .. path)
  
  -- For complex values, JSON encoding helps visualization
  if type(old_value) == "table" then
    old_value = json.encode(old_value)
  end
  
  if type(new_value) == "table" then
    new_value = json.encode(new_value)
  end
  
  print("  Old value: " .. tostring(old_value))
  print("  New value: " .. tostring(new_value))
  
  -- Restart server with new options
  print("Restarting server with new options...")
end)

-- Change the value to trigger the listener
central_config.set("server.options", {
  port = 8443,
  host = "0.0.0.0",
  ssl = true,
  cert_file = "/etc/certs/server.crt"
})
-- Output:
-- Server options changed at server.options
--   Old value: {"port":8080,"host":"0.0.0.0","ssl":false}
--   New value: {"port":8443,"host":"0.0.0.0","ssl":true,"cert_file":"/etc/certs/server.crt"}
-- Restarting server with new options...
```

## Validation Examples

### Basic Validation

```lua
local central_config = require("lib.core.central_config")

-- Register a module with validation schema
central_config.register_module("email", {
  required_fields = {"smtp_server", "from_address"},
  field_types = {
    smtp_server = "string",
    port = "number",
    username = "string",
    password = "string",
    from_address = "string",
    use_ssl = "boolean"
  },
  field_patterns = {
    from_address = "^[%w%.%-]+@[%w%.%-]+%.%w+$" -- Basic email pattern
  }
}, {
  port = 25,
  use_ssl = false
})

-- Set some values
central_config.set("email.smtp_server", "smtp.example.com")
central_config.set("email.from_address", "app@example.com")

-- Validate the module configuration
local valid, err = central_config.validate("email")
if valid then
  print("Email configuration is valid")
else
  print("Invalid email configuration:")
  for _, field_err in ipairs(err.context.errors) do
    print("  - " .. field_err.field .. ": " .. field_err.message)
  end
end
```

### Validating All Configuration

```lua
local central_config = require("lib.core.central_config")

-- Register multiple modules with validation schemas
central_config.register_module("database", {
  required_fields = {"host", "username", "password"},
  field_types = {
    host = "string",
    port = "number",
    username = "string",
    password = "string"
  }
}, {
  port = 5432
})

central_config.register_module("cache", {
  field_types = {
    enabled = "boolean",
    ttl = "number"
  }
}, {
  enabled = true,
  ttl = 3600
})

-- Set some values
central_config.set("database.host", "db.example.com")
central_config.set("database.username", "app_user")
central_config.set("database.password", "secret")

-- Deliberately leave out a required field for one module
-- central_config.set("database.host", "db.example.com")

-- Validate all modules
local valid, err = central_config.validate()
if valid then
  print("All configuration is valid")
else
  print("Configuration validation failed:")
  for module_name, module_errors in pairs(err.context.modules) do
    print("Module: " .. module_name)
    for _, field_err in ipairs(module_errors) do
      print("  - " .. field_err.field .. ": " .. field_err.message)
    end
  end
end
```

### Custom Validators

```lua
local central_config = require("lib.core.central_config")

-- Register a module with custom validators
central_config.register_module("api", {
  field_types = {
    url = "string",
    timeout = "number",
    rate_limit = "number",
    version = "string"
  },
  validators = {
    url = function(value)
      if not value:match("^https?://") then
        return false, "URL must start with http:// or https://"
      end
      return true
    end,
    version = function(value)
      if not value:match("^%d+%.%d+%.%d+$") then
        return false, "Version must be in format x.y.z"
      end
      return true
    end,
    -- Complex validator that depends on other fields
    rate_limit = function(value, config)
      if config.timeout and value > config.timeout then
        return false, "Rate limit must be less than timeout"
      end
      return true
    end
  }
}, {
  timeout = 30000,
  rate_limit = 10,
  version = "1.0.0"
})

-- Set values
central_config.set("api.url", "http://api.example.com")
central_config.set("api.version", "1.2.3")
central_config.set("api.rate_limit", 20)

-- Invalid URL
central_config.set("api.url", "ftp://api.example.com")
local valid1, err1 = central_config.validate("api")
if not valid1 then
  print("API validation failed: " .. err1.context.errors[1].message)
  -- Output: API validation failed: URL must start with http:// or https://
end

-- Invalid version format
central_config.set("api.url", "http://api.example.com") -- Fix URL
central_config.set("api.version", "1.2.x")
local valid2, err2 = central_config.validate("api")
if not valid2 then
  print("API validation failed: " .. err2.context.errors[1].message)
  -- Output: API validation failed: Version must be in format x.y.z
end

-- Rate limit higher than timeout
central_config.set("api.version", "1.2.3") -- Fix version
central_config.set("api.timeout", 10000)
central_config.set("api.rate_limit", 15000)
local valid3, err3 = central_config.validate("api")
if not valid3 then
  print("API validation failed: " .. err3.context.errors[1].message)
  -- Output: API validation failed: Rate limit must be less than timeout
end

-- Fix all issues
central_config.set("api.rate_limit", 5000)
local valid4 = central_config.validate("api")
if valid4 then
  print("API configuration is now valid")
  -- Output: API configuration is now valid
end
```

## Reset Examples

### Resetting a Specific Module

```lua
local central_config = require("lib.core.central_config")

-- Register a module with defaults
central_config.register_module("logger", {
  field_types = {
    level = "string",
    file = "string",
    console = "boolean"
  }
}, {
  level = "info",
  console = true
})

-- Check initial values
print("Initial log level: " .. central_config.get("logger.level"))
-- Output: Initial log level: info

-- Change values
central_config.set("logger.level", "debug")
central_config.set("logger.file", "/var/log/app.log")

-- Check changed values
print("Changed log level: " .. central_config.get("logger.level"))
-- Output: Changed log level: debug
print("Log file: " .. tostring(central_config.get("logger.file")))
-- Output: Log file: /var/log/app.log

-- Reset just this module
central_config.reset("logger")

-- Check values after reset
print("Log level after reset: " .. central_config.get("logger.level"))
-- Output: Log level after reset: info
print("Log file after reset: " .. tostring(central_config.get("logger.file")))
-- Output: Log file after reset: nil
```

### Resetting All Configuration

```lua
local central_config = require("lib.core.central_config")

-- Register multiple modules with defaults
central_config.register_module("module1", nil, {value = "default1"})
central_config.register_module("module2", nil, {value = "default2"})

-- Set various values
central_config.set("module1.value", "changed1")
central_config.set("module2.value", "changed2")
central_config.set("other.value", "other")

-- Check values
print("Module1: " .. central_config.get("module1.value"))
-- Output: Module1: changed1
print("Module2: " .. central_config.get("module2.value"))
-- Output: Module2: changed2
print("Other: " .. tostring(central_config.get("other.value")))
-- Output: Other: other

-- Reset all configuration
central_config.reset()

-- Check values after reset
print("Module1 after reset: " .. central_config.get("module1.value", "not found"))
-- Output: Module1 after reset: default1
print("Module2 after reset: " .. central_config.get("module2.value", "not found"))
-- Output: Module2 after reset: default2
print("Other after reset: " .. central_config.get("other.value", "not found"))
-- Output: Other after reset: not found
```

## CLI Integration Examples

### Parsing Command Line Arguments

```lua
local central_config = require("lib.core.central_config")

-- Function to parse command line arguments into configuration options
local function parse_cli_args()
  local options = {}
  
  for i = 1, #arg do
    -- Parse --key=value options
    local key, value = arg[i]:match("^%-%-([%w%.]+)=(.+)$")
    if key and value then
      -- Convert value types
      if value == "true" then 
        value = true
      elseif value == "false" then 
        value = false
      elseif tonumber(value) then 
        value = tonumber(value)
      end
      
      options[key] = value
    end
    
    -- Parse --flag options (boolean true)
    local flag = arg[i]:match("^%-%-([%w%.]+)$")
    if flag and not key then
      options[flag] = true
    end
  end
  
  return options
end

-- Apply command-line options to configuration
local options = parse_cli_args()
central_config.configure_from_options(options)

-- Example configuration workflow
central_config.register_module("app", nil, {
  debug = false,
  log_level = "info",
  port = 8080
})

-- Show applied configuration
print("Debug mode: " .. tostring(central_config.get("app.debug")))
print("Log level: " .. central_config.get("app.log_level"))
print("Port: " .. central_config.get("app.port"))
```

### Environment-Specific Configuration

```lua
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")

-- Determine environment from command line or environment variable
local function get_environment()
  -- Check command line for --env=value
  for i = 1, #arg do
    local _, env = arg[i]:match("^%-%-env=(.+)$")
    if env then return env end
  end
  
  -- Check environment variable
  local env = os.getenv("ENV")
  if env then return env end
  
  -- Default to development
  return "development"
end

local environment = get_environment()
print("Using environment: " .. environment)

-- Try to load environment-specific config file
local env_config_path = ".firmo-config." .. environment .. ".lua"
if fs.file_exists(env_config_path) then
  local config, err = central_config.load_from_file(env_config_path)
  if config then
    print("Loaded environment-specific config: " .. env_config_path)
  else
    print("Failed to load environment config: " .. err.message)
  end
else
  print("No environment-specific config found, using defaults")
  -- Load default config instead
  central_config.load_from_file()
end

-- Apply environment-specific defaults
if environment == "production" then
  central_config.set_multiple({
    ["app.debug"] = false,
    ["logging.level"] = "warn",
    ["cache.enabled"] = true
  })
elseif environment == "testing" then
  central_config.set_multiple({
    ["app.debug"] = true,
    ["logging.level"] = "debug",
    ["cache.enabled"] = false
  })
end

-- Show applied configuration
print("Debug mode: " .. tostring(central_config.get("app.debug")))
print("Log level: " .. central_config.get("logging.level"))
print("Cache enabled: " .. tostring(central_config.get("cache.enabled")))
```

## Integration Examples

### Integration with Error Handler

```lua
local central_config = require("lib.core.central_config")
local error_handler = require("lib.tools.error_handler")

-- Set up error handler configuration with centralized config
central_config.register_module("error_handler", {
  field_types = {
    log_errors = "boolean",
    include_stacktrace = "boolean",
    error_file = "string"
  }
}, {
  log_errors = true,
  include_stacktrace = true
})

-- Safe configuration loading with error handling
local function load_config_safely()
  local success, result, err = error_handler.try(function()
    return central_config.load_from_file()
  end)
  
  if not success then
    print("Error loading configuration: " .. result.message)
    
    -- Check error type
    if result.category == error_handler.CATEGORY.IO then
      print("IO error: File not found or permission denied")
    elseif result.category == error_handler.CATEGORY.PARSE then
      print("Parse error: Invalid configuration file syntax")
      print("Line: " .. (result.context.line or "unknown"))
    end
    
    -- Continue with defaults
    return false
  end
  
  return true
end

-- Try to load configuration
if load_config_safely() then
  print("Configuration loaded successfully")
else
  print("Using default configuration")
end

-- Validate with error handling
local function validate_config_safely()
  local success, result, err = error_handler.try(function()
    return central_config.validate()
  end)
  
  if not success then
    print("Error during validation: " .. result.message)
    return false, result
  end
  
  if not result then
    print("Configuration invalid: " .. err.message)
    return false, err
  end
  
  return true
end

-- Validate configuration
if validate_config_safely() then
  print("Configuration is valid")
else
  print("Using default configuration due to validation errors")
end
```

### Integration with Logging

```lua
local central_config = require("lib.core.central_config")
local logging = require("lib.tools.logging")

-- Register logging configuration
central_config.register_module("logging", {
  field_types = {
    level = "string",
    file = "string",
    format = "string",
    include_timestamp = "boolean"
  },
  field_values = {
    level = {"debug", "info", "warn", "error"},
    format = {"text", "json"}
  }
}, {
  level = "info",
  format = "text",
  include_timestamp = true
})

-- Configure logging from central config
local function configure_logging()
  local log_config = central_config.get("logging")
  
  -- Apply configuration to logging system
  logging.configure({
    level = log_config.level,
    file = log_config.file,
    format = log_config.format,
    include_timestamp = log_config.include_timestamp
  })
  
  -- Get a logger instance
  local logger = logging.get_logger("app")
  
  -- Log the configuration
  logger.info("Logging configured", {
    level = log_config.level,
    file = log_config.file,
    format = log_config.format
  })
  
  return logger
end

-- Set up a change listener to reconfigure logging when settings change
central_config.on_change("logging", function(path, old_value, new_value)
  local logger = logging.get_logger("config")
  logger.info("Logging configuration changed", {
    path = path,
    old_value = type(old_value) == "table" and "table" or old_value,
    new_value = type(new_value) == "table" and "table" or new_value
  })
  
  -- Reconfigure logging system
  configure_logging()
})

-- Initial configuration
local logger = configure_logging()
logger.info("Application started")

-- Change configuration to trigger listener
central_config.set("logging.level", "debug")
logger.debug("This debug message should now appear")
```

### Integration with Coverage Module

```lua
local central_config = require("lib.core.central_config")
local coverage = require("lib.coverage")

-- Register coverage configuration
central_config.register_module("coverage", {
  field_types = {
    enabled = "boolean",
    threshold = "number",
    include = "table",
    exclude = "table",
    report_format = "string"
  },
  field_ranges = {
    threshold = {min = 0, max = 100}
  },
  field_values = {
    report_format = {"html", "json", "lcov", "cobertura"}
  }
}, {
  enabled = true,
  threshold = 90,
  include = {"lib/**/*.lua"},
  exclude = {"tests/**/*.lua"},
  report_format = "html"
})

-- Configure coverage from central config
local function configure_coverage()
  local coverage_config = central_config.get("coverage")
  
  -- Apply configuration to coverage module
  if coverage.configure then
    coverage.configure({
      enabled = coverage_config.enabled,
      threshold = coverage_config.threshold,
      include = coverage_config.include,
      exclude = coverage_config.exclude,
      report_format = coverage_config.report_format
    })
    
    print("Coverage module configured:")
    print("  Enabled: " .. tostring(coverage_config.enabled))
    print("  Threshold: " .. coverage_config.threshold .. "%")
    print("  Report Format: " .. coverage_config.report_format)
  else
    print("Coverage module doesn't support configuration")
  end
end

-- Set up a change listener to reconfigure coverage when settings change
central_config.on_change("coverage", function(path, old_value, new_value)
  print("Coverage configuration changed at " .. path)
  configure_coverage()
})

-- Initial configuration
configure_coverage()

-- Change configuration to trigger listener
central_config.set("coverage.threshold", 95)
central_config.set("coverage.report_format", "json")
```

## Utility Function Examples

### Using serialize() for Deep Copying

```lua
local central_config = require("lib.core.central_config")

-- Set a complex configuration object
central_config.set("app.config", {
  server = {
    port = 8080,
    host = "0.0.0.0",
    ssl = false
  },
  database = {
    host = "localhost",
    port = 5432,
    username = "app_user"
  }
})

-- Get the configuration
local app_config = central_config.get("app.config")
print("Original port: " .. app_config.server.port)
-- Output: Original port: 8080

-- Modify the returned object (this won't affect the stored config)
app_config.server.port = 9000
print("Modified port in local copy: " .. app_config.server.port)
-- Output: Modified port in local copy: 9000

-- Get the config again - it's unchanged because get() returns a deep copy
local unchanged_config = central_config.get("app.config")
print("Stored port is still: " .. unchanged_config.server.port)
-- Output: Stored port is still: 8080

-- Create your own deep copy with serialize
local config_copy = central_config.serialize(central_config.get("app.config"))
config_copy.server.host = "127.0.0.1"

-- Original config remains unchanged
print("Original host: " .. central_config.get("app.config.server.host"))
-- Output: Original host: 0.0.0.0
print("Modified host in copy: " .. config_copy.server.host)
-- Output: Modified host in copy: 127.0.0.1
```

### Using merge() for Combining Configurations

```lua
local central_config = require("lib.core.central_config")

-- Create base configuration
local base_config = {
  logging = {
    level = "info",
    file = "/var/log/app.log"
  },
  server = {
    port = 8080,
    host = "0.0.0.0"
  }
}

-- Create environment-specific overrides
local prod_overrides = {
  logging = {
    level = "warn"  -- Override just the log level
  },
  server = {
    port = 80,      -- Override just the port
    ssl = true,     -- Add new field
    cert_file = "/etc/certs/server.crt"  -- Add new field
  }
}

-- Merge configurations
local merged = central_config.merge(base_config, prod_overrides)

-- Check the merged results
print("Logging level: " .. merged.logging.level)
-- Output: Logging level: warn
print("Logging file: " .. merged.logging.file)
-- Output: Logging file: /var/log/app.log
print("Server port: " .. merged.server.port)
-- Output: Server port: 80
print("Server host: " .. merged.server.host)
-- Output: Server host: 0.0.0.0
print("SSL enabled: " .. tostring(merged.server.ssl))
-- Output: SSL enabled: true
print("Cert file: " .. merged.server.cert_file)
-- Output: Cert file: /etc/certs/server.crt

-- Original configs are unchanged
print("Base config logging level: " .. base_config.logging.level)
-- Output: Base config logging level: info
```

## Complete Application Example

```lua
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local logging

-- Function to set up configuration
local function setup_configuration()
  -- Define configuration hierarchically
  central_config.register_module("app", {
    field_types = {
      name = "string",
      version = "string",
      debug = "boolean"
    }
  }, {
    name = "Example App",
    version = "1.0.0",
    debug = false
  })
  
  central_config.register_module("logging", {
    field_types = {
      level = "string",
      file = "string",
      console = "boolean"
    },
    field_values = {
      level = {"debug", "info", "warn", "error"}
    }
  }, {
    level = "info",
    console = true
  })
  
  central_config.register_module("database", {
    required_fields = {"host", "database"},
    field_types = {
      host = "string",
      port = "number",
      database = "string",
      username = "string",
      password = "string",
      pool_size = "number"
    }
  }, {
    host = "localhost",
    port = 5432,
    pool_size = 10
  })
  
  -- Determine environment
  local env = os.getenv("ENV") or "development"
  
  -- Try to load configuration from file
  local config_file = ".firmo-config." .. env .. ".lua"
  if not fs.file_exists(config_file) then
    config_file = ".firmo-config.lua"
  end
  
  -- Load configuration with error handling
  local config_success, config_result, config_err = error_handler.try(function()
    return central_config.load_from_file(config_file)
  end)
  
  if not config_success then
    -- Handle error safely
    print("Error loading configuration: " .. config_result.message)
    -- Continue with defaults
  else
    print("Loaded configuration from: " .. config_file)
  end
  
  -- Parse command line arguments (highest priority)
  local function parse_cli_args()
    local options = {}
    for i = 1, #arg do
      local key, value = arg[i]:match("^%-%-([%w%.]+)=(.+)$")
      if key and value then
        -- Convert value types
        if value == "true" then value = true
        elseif value == "false" then value = false
        elseif tonumber(value) then value = tonumber(value)
        end
        options[key] = value
      end
    end
    return options
  end
  
  -- Apply command-line options
  central_config.configure_from_options(parse_cli_args())
  
  -- Validate configuration
  local valid, validate_err = central_config.validate()
  if not valid then
    print("Configuration validation failed:")
    for module_name, module_errors in pairs(validate_err.context.modules) do
      print("Module: " .. module_name)
      for _, field_err in ipairs(module_errors) do
        print("  - " .. field_err.field .. ": " .. field_err.message)
      end
    end
    -- Continue despite validation errors, using what we have
  end
  
  return true
end

-- Function to set up logging
local function setup_logging()
  -- Try to load logging module
  local logging_success, logging_module = pcall(function()
    return require("lib.tools.logging")
  end)
  
  if not logging_success then
    print("Failed to load logging module")
    return false
  end
  
  logging = logging_module
  
  -- Configure logging from central config
  local log_config = central_config.get("logging")
  
  -- Apply configuration to logging system
  logging.configure({
    level = log_config.level,
    file = log_config.file,
    console = log_config.console
  })
  
  -- Set up logging change listener
  central_config.on_change("logging", function(path, old_value, new_value)
    print("Logging configuration changed at " .. path)
    -- Reconfigure logging
    local updated_config = central_config.get("logging")
    logging.configure(updated_config)
  end)
  
  -- Get a logger instance
  local logger = logging.get_logger("app")
  logger.info("Logging initialized", {
    level = log_config.level,
    file = log_config.file,
    console = log_config.console
  })
  
  return true
end

-- Function to set up database connection
local function setup_database()
  -- Get database configuration
  local db_config = central_config.get("database")
  
  -- Check if we have required fields
  if not db_config.database then
    print("Missing required database configuration")
    return false
  end
  
  -- In a real app, we would connect to the database here
  print("Connecting to database:")
  print("  Host: " .. db_config.host)
  print("  Port: " .. db_config.port)
  print("  Database: " .. db_config.database)
  if db_config.username then
    print("  Username: " .. db_config.username)
  end
  print("  Pool size: " .. db_config.pool_size)
  
  -- Set up database change listener
  central_config.on_change("database", function(path, old_value, new_value)
    if path:match("^database%.host") or path:match("^database%.port") or
       path:match("^database%.username") or path:match("^database%.password") then
      print("Database connection parameters changed - reconnecting...")
      -- In a real app, we would reconnect to the database here
    end
  end)
  
  return true
end

-- Function to run the application
local function run_app()
  -- Get application configuration
  local app_config = central_config.get("app")
  
  print("Starting " .. app_config.name .. " v" .. app_config.version)
  if app_config.debug then
    print("DEBUG MODE ENABLED")
  end
  
  -- In a real app, we would run the application logic here
  print("Application running...")
  
  -- Simulate a configuration change during runtime
  print("\nChanging log level to debug...")
  central_config.set("logging.level", "debug")
  
  if logging then
    local logger = logging.get_logger("app")
    -- This debug message should now appear due to the changed log level
    logger.debug("This is a debug message that should be visible now")
  end
end

-- Main function
local function main()
  -- Initialize all components
  if not setup_configuration() then
    print("Failed to set up configuration")
    return 1
  end
  
  if not setup_logging() then
    print("Failed to set up logging")
    -- Continue without logging
  end
  
  if not setup_database() then
    print("Failed to set up database")
    return 1
  }
  
  -- Run the application
  run_app()
  
  -- Save final configuration
  local success, err = central_config.save_to_file("config-saved.lua")
  if success then
    print("Configuration saved to config-saved.lua")
  else
    print("Failed to save configuration: " .. err.message)
  end
  
  return 0
end

-- Run the main function
os.exit(main())
```

This document demonstrates practical examples of how to use the central configuration system in various scenarios. From basic usage to advanced integration patterns, these examples should help you understand how to effectively use the configuration system in your projects.