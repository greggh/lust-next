# Centralized Configuration System Guide

This guide explains the centralized configuration system in firmo, which provides a unified approach to managing configuration across all framework components.

## Overview

The centralized configuration system (`central_config`) replaces the legacy module-specific configuration approach, providing:

- Hierarchical configuration with dot notation access
- Schema validation for configuration values
- Change notification system for reactive updates
- Unified configuration loading from various sources
- Consistent API across all framework components

## Migrating from Legacy Config

If you're using the legacy config module, you should migrate to the centralized configuration system. The legacy system is deprecated and will be removed in a future version.

### Step 1: Update Imports

```lua
-- Legacy approach (deprecated)
local config = require("lib.core.config")

-- New approach
local central_config = require("lib.core.central_config")
```

### Step 2: Update Configuration Access

```lua
-- Legacy approach (deprecated)
local debug_mode = config.get("debug", false)
config.set("debug", true)

-- New approach
local debug_mode = central_config.get("debug", false)
central_config.set("debug", true)
```

### Step 3: Update Module-Specific Configuration

```lua
-- Legacy approach (deprecated)
local coverage_config = config.get_coverage_config()
config.set_coverage_config({ threshold = 90 })

-- New approach
local coverage_config = central_config.get("coverage")
central_config.set("coverage.threshold", 90)
```

## Configuration File Structure

The configuration file (`.firmo-config.lua`) should return a table with hierarchical configuration:

```lua
-- .firmo-config.lua
return {
  -- Core options
  debug = false,
  verbose = false,

  -- Coverage options
  coverage = {
    enabled = true,
    threshold = 90,
    include = { "lib/", "src/" },
    exclude = { "tests/", "examples/" }
  },

  -- Reporting options
  reporting = {
    report_dir = "./coverage-reports",
    formatters = {
      html = {
        theme = "dark"
      },
      json = {
        pretty = true
      }
    },
    validation = {
      validate_reports = true
    }
  }
}
```

## Using the Centralized Configuration System

### Loading Configuration

```lua
local central_config = require("lib.core.central_config")

-- Load from file
local success, err = central_config.load_from_file(".firmo-config.lua")
if not success then
  print("Failed to load config: " .. tostring(err))
end

-- Load from string
local config_str = [[
return {
  debug = true,
  coverage = {
    threshold = 90
  }
}
]]
central_config.load_from_string(config_str)

-- Load from table
central_config.load_from_table({
  debug = true,
  coverage = {
    threshold = 90
  }
})
```

### Getting Configuration Values

```lua
-- Get a value with fallback
local debug_mode = central_config.get("debug", false)

-- Get a nested value
local threshold = central_config.get("coverage.threshold", 80)

-- Get a whole section
local coverage_config = central_config.get("coverage")
```

### Setting Configuration Values

```lua
-- Set a value
central_config.set("debug", true)

-- Set a nested value
central_config.set("coverage.threshold", 90)

-- Set multiple values
central_config.set_multiple({
  debug = true,
  ["coverage.threshold"] = 90,
  ["reporting.report_dir"] = "./reports"
})

-- Set a whole section
central_config.set("coverage", {
  threshold = 90,
  include = { "lib/", "src/" }
})
```

### Registering for Change Notifications

```lua
-- Register for changes to a specific path
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  print("Coverage threshold changed from " .. old_value .. " to " .. new_value)
end)

-- Register for changes to a whole section
central_config.on_change("coverage", function(path, old_value, new_value)
  print("Coverage configuration changed")
end)
```

### Registering Module Schemas

Modules should register their configuration schema:

```lua
-- Register a module schema
central_config.register_module("my_module", {
  field_types = {
    enabled = "boolean",
    timeout = "number",
    patterns = "table"
  },
  validators = {
    timeout = function(value)
      return value > 0, "Timeout must be positive"
    }
  }
}, {
  -- Default values
  enabled = true,
  timeout = 30,
  patterns = { "*.lua" }
})
```

## Command Line Integration

You can work with configuration from the command line:

```bash
# Load a specific config file
lua run_tests.lua --config my_config.lua

# Create a template config file
lua run_tests.lua --create-config

# Override specific config values
lua run_tests.lua --coverage.threshold=90 --reporting.formatters.html.theme=light
```

## Configuration Priority

The configuration system follows this priority order (highest to lowest):

1. Command line options (`--key=value`)
2. Environment variables (`FIRMO_KEY=value`)
3. Project config file (`.firmo-config.lua`)
4. Programmatically set values (`central_config.set()`)
5. Default values from schema registration

## Accessing Configuration in Modules

Modules should access configuration using the centralized system:

```lua
local function configure_module(options)
  -- Try to load central_config (with pcall for safety)
  local has_central_config, central_config = pcall(require, "lib.core.central_config")

  -- Default configuration
  local config = {
    enabled = true,
    timeout = 30
  }

  -- If central_config is available, use it
  if has_central_config then
    -- Get module configuration
    local module_config = central_config.get("my_module")
    if module_config then
      -- Update local config with central config
      for k, v in pairs(module_config) do
        config[k] = v
      end
    end

    -- Register for changes
    central_config.on_change("my_module", function(path, old_value, new_value)
      -- Update local config when central config changes
      config = central_config.get("my_module") or config
    end)
  end

  -- Options override everything
  if options then
    for k, v in pairs(options) do
      config[k] = v
    end
  end

  return config
end
```

## Schema Validation

The centralized configuration system includes schema validation:

```lua
-- Register a schema
central_config.register_schema("user_profile", {
  field_types = {
    name = "string",
    age = "number",
    email = "string",
    preferences = "table"
  },
  validators = {
    name = function(value)
      return #value > 0, "Name cannot be empty"
    end,
    age = function(value)
      return value >= 18, "Age must be at least 18"
    end,
    email = function(value)
      return value:match("^[%w.]+@[%w.]+%.%w+$"), "Invalid email format"
    end
  }
})

-- Set values (will be validated)
local success, err = central_config.set("user_profile.name", "")
if not success then
  print("Validation error: " .. err) -- "Name cannot be empty"
end
```

## Best Practices

1. **Register Module Schema**: All modules should register their schema with default values.
2. **Use Dot Notation**: Access configuration using dot notation for consistency.
3. **Provide Fallbacks**: Always provide fallback values when getting configuration.
4. **Use Change Listeners**: Register for changes to react to configuration updates.
5. **Validate Input**: Use schema validation to ensure valid configuration.
6. **Document Configuration**: Document all configuration options with examples.
7. **Use Central Configuration**: Avoid module-specific configuration systems.

## Common Use Cases

### Configuration for Testing

```lua
-- Before tests
central_config.load_from_table({
  debug = true,
  coverage = {
    enabled = true,
    threshold = 90
  }
})

-- Run tests...

-- After tests
central_config.reset() -- Reset to defaults
```

### Configuration for CI/CD

```lua
-- CI/CD configuration file (.firmo-ci-config.lua)
return {
  debug = false,
  verbose = true,
  coverage = {
    enabled = true,
    threshold = 95, -- Stricter threshold for CI
    fail_on_threshold = true
  },
  reporting = {
    report_dir = "./ci-reports",
    validation = {
      strict_validation = true -- Fail on validation issues
    }
  }
}
```

### Environment-Specific Configuration

```lua
-- Determine environment
local env = os.getenv("ENV") or "development"

-- Load environment-specific config
local config_file = ".firmo-config." .. env .. ".lua"
central_config.load_from_file(config_file)
```

## Debugging Configuration

```lua
-- Print the entire configuration
local full_config = central_config.get_all()
print(require("lib.reporting.json").encode(full_config))

-- Check if a section exists
local has_section = central_config.has("reporting")
print("Has reporting section: " .. tostring(has_section))

-- Get current schema
local schema = central_config.get_schema()
```

## Next Steps

After understanding the centralized configuration system, explore these topics:

- [Report Validation Configuration](./report_validation.md)
- [HTML Formatter Configuration](./html_formatter.md)
- [Coverage Configuration](../guides/coverage_configuration.md)
- [Creating Custom Formatters](../guides/custom_formatters.md)
