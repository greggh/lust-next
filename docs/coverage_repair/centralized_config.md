# Centralized Configuration System

This document provides comprehensive documentation for the centralized configuration system implemented in the lust-next framework.

## Overview

The centralized configuration system provides a global configuration store with standardized access patterns for all components in the lust-next framework. It replaces the previous approach of passing configuration separately to each component and allows for consistent configuration access, validation, and notification across the codebase.

## Key Features

- **Hierarchical Configuration**: Access config values using dot notation paths (`coverage.include_patterns`)
- **Schema Validation**: Register schemas for modules to validate configuration structure and values
- **Change Notification**: Register listeners for configuration changes at specific paths
- **Default Values**: Define default values for modules that are applied automatically
- **File I/O**: Load and save configuration from/to files
- **Type Safety**: Proper validation of configuration values
- **Path-based Access**: Get, set, or delete values at specific paths
- **Module Registration**: Modules can register their configuration requirements
- **Dependency Management**: Uses lazy loading to avoid circular dependencies

## API Reference

### Core Functions

#### Configuration Access

```lua
-- Get a value at a specific path
local value = central_config.get("coverage.include_patterns", default_value)

-- Set a value at a specific path
central_config.set("coverage.include_patterns", {"*.lua"})

-- Delete a value at a specific path
central_config.delete("coverage.temp_setting")
```

#### Module Registration

```lua
-- Register a module's configuration schema and defaults
central_config.register_module("coverage", {
  -- Schema definition
  required_fields = {"include_patterns"},
  field_types = {
    threshold = "number",
    include_patterns = "table"
  },
  field_ranges = {
    threshold = {min = 0, max = 100}
  }
}, {
  -- Default values
  threshold = 80,
  include_patterns = {"*.lua"}
})
```

#### Change Notification

```lua
-- Register a change listener for a specific path
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  print("Coverage threshold changed from " .. tostring(old_value) .. " to " .. tostring(new_value))
end)
```

#### Configuration Validation

```lua
-- Validate all configuration against registered schemas
local valid, error = central_config.validate()

-- Validate specific module's configuration
local valid = central_config.validate("coverage")
```

#### File Operations

```lua
-- Load configuration from a file
local config, error = central_config.load_from_file(".lust-next-config.lua")

-- Save current configuration to a file
local success, error = central_config.save_to_file(".lust-next-config.lua")
```

#### Reset Configuration

```lua
-- Reset all configuration to defaults
central_config.reset()

-- Reset specific module's configuration
central_config.reset("coverage")
```

#### Integration Functions

```lua
-- Configure from options table (typically from CLI)
central_config.configure_from_options(options)

-- Configure from global config
central_config.configure_from_config(global_config)
```

### Constants

```lua
-- Default configuration file path
central_config.DEFAULT_CONFIG_PATH -- ".lust-next-config.lua"

-- Error categories
central_config.ERROR_TYPES.VALIDATION -- "validation"
central_config.ERROR_TYPES.ACCESS -- "access"
central_config.ERROR_TYPES.IO -- "io"
central_config.ERROR_TYPES.PARSE -- "parse"
```

### Utility Functions

```lua
-- Deep copy a table
local copy = central_config.serialize(table)

-- Deep merge two tables
local merged = central_config.merge(target, source)
```

## Schema Definition

Schemas are used to validate configuration structure and values. A schema is a table with the following fields:

```lua
{
  -- Required fields that must be present
  required_fields = {"field1", "field2"},
  
  -- Expected types for fields
  field_types = {
    field1 = "string",
    field2 = "table",
    field3 = "number"
  },
  
  -- Numeric ranges for fields
  field_ranges = {
    field3 = {min = 0, max = 100}
  },
  
  -- Pattern matching for string fields
  field_patterns = {
    field1 = "^%a+$" -- Only letters
  },
  
  -- Enum-like values for fields
  field_values = {
    field4 = {"value1", "value2", "value3"}
  },
  
  -- Custom validators for fields
  validators = {
    field5 = function(value, config)
      if some_condition then
        return true
      else
        return false, "Custom error message"
      end
    end
  }
}
```

## Integration with Other Modules

The centralized configuration system integrates with other modules in the following ways:

1. **Error Handler**: Uses the error handler module for creating structured error objects
2. **Logging**: Uses the logging module for diagnostic messages
3. **Filesystem**: Uses the filesystem module for file I/O operations

## Usage Examples

### Basic Usage

```lua
local central_config = require("lib.core.central_config")

-- Get a configuration value
local threshold = central_config.get("coverage.threshold", 80)

-- Set a configuration value
central_config.set("coverage.include_patterns", {"*.lua"})

-- Reset to defaults
central_config.reset()
```

### Module Registration

```lua
local central_config = require("lib.core.central_config")

-- Register module configuration
central_config.register_module("my_module", {
  required_fields = {"api_key"},
  field_types = {
    api_key = "string",
    timeout = "number"
  }
}, {
  timeout = 5000
})
```

### Change Notifications

```lua
local central_config = require("lib.core.central_config")

-- Listen for changes to specific path
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  print("Coverage threshold changed from " .. tostring(old_value) .. " to " .. tostring(new_value))
end)

-- Listen for changes to any path
central_config.on_change("", function(path, old_value, new_value)
  print("Configuration changed at " .. path)
end)
```

### Loading and Saving

```lua
local central_config = require("lib.core.central_config")

-- Load from custom path
local config, err = central_config.load_from_file("my-config.lua")
if not config then
  print("Failed to load config: " .. err.message)
end

-- Save to default path
local success, err = central_config.save_to_file()
if not success then
  print("Failed to save config: " .. err.message)
end
```

## Best Practices

1. **Always Register Modules**: Register your module's schema and defaults before using the configuration system
2. **Use Dot Notation**: Access configuration using dot notation for consistency
3. **Provide Default Values**: Always provide default values when getting configuration to handle missing values
4. **Validate Configuration**: Validate configuration after loading to catch errors early
5. **Handle Errors**: Always check for errors when loading or validating configuration
6. **Use Change Notifications**: Register change listeners to update module behavior when configuration changes
7. **Avoid Direct Access**: Use the provided API rather than direct access to configuration values

## Migration from Previous Configuration System

### Before

```lua
-- Module-specific configuration
local my_module = {}
my_module.configure = function(options)
  my_module.options = my_module.options or {}
  for k, v in pairs(options) do
    my_module.options[k] = v
  end
end

-- In lust-next.lua
lust_next.my_module_options = {
  timeout = 5000
}

-- Applying configuration
my_module.configure(lust_next.my_module_options)
```

### After

```lua
-- Module registration
local central_config = require("lib.core.central_config")
local my_module = {}

-- Register module with the central configuration system
central_config.register_module("my_module", {
  field_types = {
    timeout = "number"
  },
  field_ranges = {
    timeout = {min = 0}
  }
}, {
  timeout = 5000
})

-- Access configuration
local timeout = central_config.get("my_module.timeout")
```

## Implementation Details

The centralized configuration system is implemented in `lib/core/central_config.lua` and follows these design principles:

1. **Singleton Pattern**: The module maintains a single global configuration store
2. **Lazy Loading**: Dependencies are loaded on-demand to avoid circular dependencies
3. **Immutability**: Values returned by `get()` are deep-copied to prevent unintended modifications
4. **Validation**: Configuration is validated against registered schemas
5. **Notification**: Change listeners are notified when configuration changes
6. **Error Handling**: Errors are structured and include context about the error

The implementation follows the same patterns as the error handler and logging modules, providing a consistent experience for developers.