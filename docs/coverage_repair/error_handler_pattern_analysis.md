# Error Handler Pattern Analysis

## Overview

This document provides a detailed analysis of the error handling patterns in the lust-next codebase. We initially identified approximately 38 instances of conditional error handler checking (`if error_handler then`) and 32 fallback blocks in coverage/init.lua, which have now been fixed.

## Key Issues Addressed

1. **Conditional Error Handler Availability**: The code incorrectly assumed that the error_handler module might not be available and included fallback code. This was fundamentally flawed as error_handler is a core module.

2. **Inconsistent Error Object Creation**: The fallback code returned simple strings instead of structured error objects, leading to inconsistent error handling downstream.

3. **Duplicated Logic**: Each conditional block contained duplicated logic, making the code harder to maintain and more prone to bugs.

4. **Inconsistent Error Propagation**: Different branches propagated errors differently, making error handling unpredictable for callers.

## Implementation Status

- ✅ Fixed in coverage/init.lua (2025-03-11)
- ✅ Fixed in static_analyzer.lua (2025-03-11)
- ✅ Fixed in patchup.lua (2025-03-11)
- 🔄 In progress for other coverage module components
- 📝 Documentation updated with consistent patterns

## Implemented Error Handling Patterns

The following patterns are now consistently implemented in coverage/init.lua and should be used throughout the codebase:

### 1. Direct Error Handler Requirement

```lua
-- Error handler is a required module for proper error handling throughout the codebase
local error_handler = require("lib.tools.error_handler")
```

### 2. Function Try/Catch Pattern

```lua
local success, result, err = error_handler.try(function()
  -- function body
end)

if not success then
  logger.error("Error message: " .. error_handler.format_error(result), {
    operation = "function_name"
  })
  return nil, result
end
```

### 3. Validation Error Pattern

```lua
if options ~= nil and type(options) ~= "table" then
  local err = error_handler.validation_error(
    "Options must be a table or nil",
    {
      provided_type = type(options),
      operation = "coverage.init"
    }
  )
  logger.error("Invalid options: " .. error_handler.format_error(err))
  return nil, err
end
```

### 4. I/O Operation Pattern

```lua
local source, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  {operation = "process_module_structure"}
)

if not source then
  logger.error("Failed to read file: " .. error_handler.format_error(err))
  return nil, err
end
```

### 5. Configuration Access Pattern

```lua
local success, result, err = error_handler.try(function()
  return central_config.get("coverage")
end)

if not success then
  logger.warn("Failed to get values from central configuration: " .. error_handler.format_error(result), {
    operation = "coverage.init"
  })
else
  central_values = result
end
```

## Original Pattern Categories

The following patterns were identified in the original code and have been fixed:

### 1. Error Handler Initialization (1 instance)

```lua
-- Initialize error handler
local error_handler = get_error_handler()
if error_handler then
  error_handler.configure_from_config()
end
```

This should be replaced with:

```lua
-- Initialize error handler
local error_handler = get_error_handler()
error_handler.configure_from_config()
```

### 2. Function Try/Catch Patterns (20+ instances)

```lua
if error_handler then
  local success, result, err = error_handler.try(function()
    -- function body
  end)
  
  if not success then
    logger.error("Error message: " .. error_handler.format_error(result), {
      operation = "function_name"
    })
    return nil, result
  end
else
  -- Fallback without error handler
  local success, result = pcall(function()
    -- function body
  end)
  
  if not success then
    logger.error("Error message: " .. tostring(result), {
      operation = "function_name"
    })
    return nil, "Error description: " .. tostring(result)
  end
end
```

This should be replaced with:

```lua
local success, result, err = error_handler.try(function()
  -- function body
end)

if not success then
  logger.error("Error message: " .. error_handler.format_error(result), {
    operation = "function_name"
  })
  return nil, result
end
```

### 3. Validation Error Patterns (5+ instances)

```lua
if options ~= nil and type(options) ~= "table" then
  if error_handler then
    local err = error_handler.validation_error(
      "Options must be a table or nil",
      {
        provided_type = type(options),
        operation = "coverage.init"
      }
    )
    logger.error("Invalid options: " .. error_handler.format_error(err))
    return nil, err
  else
    logger.error("Invalid options: expected table, got " .. type(options))
    return nil, "Invalid options type"
  end
end
```

This should be replaced with:

```lua
if options ~= nil and type(options) ~= "table" then
  local err = error_handler.validation_error(
    "Options must be a table or nil",
    {
      provided_type = type(options),
      operation = "coverage.init"
    }
  )
  logger.error("Invalid options: " .. error_handler.format_error(err))
  return nil, err
end
```

### 4. I/O Operation Patterns (5+ instances)

```lua
local source, err
if error_handler then
  source, err = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    {operation = "process_module_structure"}
  )
  
  if not source then
    logger.error("Failed to read file: " .. error_handler.format_error(err))
    return nil, err
  end
else
  -- Fallback without error handler
  source = fs.read_file(file_path)
  if not source then
    logger.error("Failed to read file: " .. file_path)
    return nil, "File read error"
  end
end
```

This should be replaced with:

```lua
local source, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  {operation = "process_module_structure"}
)

if not source then
  logger.error("Failed to read file: " .. error_handler.format_error(err))
  return nil, err
end
```

### 5. Configuration Access Patterns (3+ instances)

```lua
if central_config then
  local central_values
  
  if error_handler then
    local success, result, err = error_handler.try(function()
      return central_config.get("coverage")
    end)
    
    if not success then
      logger.warn("Failed to get values from central configuration: " .. error_handler.format_error(result), {
        operation = "coverage.init"
      })
    else
      central_values = result
    end
  else
    -- Fallback without error handler
    local success, result = pcall(function()
      return central_config.get("coverage")
    end)
    
    if not success then
      logger.warn("Failed to get values from central configuration: " .. tostring(result), {
        operation = "coverage.init"
      })
    else
      central_values = result
    end
  end
  
  -- More code...
end
```

This should be replaced with:

```lua
if central_config then
  local central_values
  
  local success, result, err = error_handler.try(function()
    return central_config.get("coverage")
  end)
  
  if not success then
    logger.warn("Failed to get values from central configuration: " .. error_handler.format_error(result), {
      operation = "coverage.init"
    })
  else
    central_values = result
  end
  
  -- More code...
end
```

## Implementation Strategy

1. **Systematic Search and Replace**: Use regular expressions or text search to identify all instances of conditional error handler patterns.

2. **Replace with Standard Pattern**: Apply the standard error handling pattern to each instance.

3. **Remove Lazy Loading**: Since error_handler is now required, the lazy loading approach can be simplified.

4. **Verify Error Propagation**: Ensure all error objects are properly propagated.

5. **Test**: After each major set of changes, run the tests to verify functionality.

## Additional Recommendations

1. **Remove Lazy Loading Logic**: Since error_handler is a core requirement, we should simplify the lazy loading approach:

```lua
-- BEFORE
local _error_handler
local function get_error_handler()
  if not _error_handler then
    local success, error_handler = pcall(require, "lib.tools.error_handler")
    _error_handler = success and error_handler or nil
  end
  return _error_handler
end

-- AFTER
local error_handler = require("lib.tools.error_handler")
```

2. **Update Lazy Loading Function Calls**: Replace all uses of `get_error_handler()` with the direct variable reference:

```lua
-- BEFORE
local error_handler = get_error_handler()
if error_handler then
  -- Use error_handler
end

-- AFTER
-- Direct use of error_handler variable
error_handler.function_name()
```

3. **Document Requirement**: Add a comment to clarify that error_handler is a required module:

```lua
-- Error handler is a required module for proper error handling throughout the codebase
local error_handler = require("lib.tools.error_handler")
```