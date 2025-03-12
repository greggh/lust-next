# Error Handling Guide

This document provides guidelines for standardized error handling throughout the lust-next project using the `error_handler` module.

## Overview

The `error_handler` module provides a comprehensive error handling system with the following features:

- Standardized error object creation
- Categorized and severity-based error handling
- Integration with the logging system
- Stack trace capture and formatting
- Assertion utilities for validation
- Safe operation wrappers for error-prone functions

> **CRITICAL UPDATE (2025-03-11)**: The error_handler module is a core module that MUST always be available. No fallback mechanisms should be implemented to handle cases where error_handler is not available. All modules should directly use the error_handler without checking its availability.

## Basic Principles

1. **Be explicit about errors**: All functions should either handle errors or clearly document how they propagate errors.
2. **Use structured error objects**: Use the error_handler module to create structured error objects instead of simple strings.
3. **Categorize errors**: Assign appropriate categories and severity levels to errors for better handling.
4. **Include context**: Provide contextual information with errors to help with debugging.
5. **Log errors**: Ensure errors are properly logged for troubleshooting.
6. **Handle errors at the right level**: Errors should be handled at the appropriate level in the call stack.

## Error Objects

The `error_handler` module creates standardized error objects with the following structure:

```lua
{
  message = "Error message", -- Human-readable error message
  category = "CATEGORY",     -- Error category (VALIDATION, IO, PARSE, etc.)
  severity = "SEVERITY",     -- Error severity (FATAL, ERROR, WARNING, INFO)
  timestamp = 1614556800,    -- Timestamp when the error occurred
  traceback = "...",         -- Stack trace (if enabled)
  context = {                -- Additional contextual information
    key1 = "value1",
    key2 = "value2"
  },
  source_file = "file.lua",  -- Source file where the error occurred
  source_line = 42,          -- Line number where the error occurred
  cause = err                -- Original error that caused this one
}
```

## Using the Error Handler

### Basic Error Creation

```lua
local error_handler = require("lib.tools.error_handler")

-- Create an error object
local err = error_handler.create(
  "Failed to parse JSON data", -- Error message
  error_handler.CATEGORY.PARSE, -- Error category
  error_handler.SEVERITY.ERROR, -- Error severity
  { file_path = "data.json" } -- Context
)

-- Return error from a function
return nil, err
```

### Assertions

```lua
local error_handler = require("lib.tools.error_handler")

-- Assert a condition
error_handler.assert(
  type(value) == "string", 
  "Value must be a string", 
  error_handler.CATEGORY.VALIDATION,
  { value = value }
)

-- Assert a value is not nil
error_handler.assert_not_nil(file_handle, "File handle")

-- Assert a value is of a specific type
error_handler.assert_type(options, "table", "Options")
```

### Safe Function Execution

```lua
local error_handler = require("lib.tools.error_handler")

-- Safely call a function that might throw an error
local success, result = error_handler.try(function()
  -- Function that might throw an error
  return json.parse(data)
end)

if not success then
  -- Handle error
  logger.error("Failed to parse JSON: " .. error_handler.format_error(result))
  return nil
end

-- Use the result
return result
```

### I/O Operations

```lua
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

-- Safely perform an I/O operation
local content, err = error_handler.safe_io_operation(
  function() 
    return fs.read_file(file_path)
  },
  file_path,
  { operation = "read_file" }
)

if not content then
  -- Handle error
  logger.error("Failed to read file: " .. error_handler.format_error(err))
  return nil
end

-- Use the content
return content
```

## Error Categories

The error handler defines the following error categories:

- `VALIDATION`: Input validation errors
- `IO`: File I/O errors
- `PARSE`: Parsing errors
- `RUNTIME`: Runtime errors
- `TIMEOUT`: Timeout errors
- `MEMORY`: Memory-related errors
- `CONFIGURATION`: Configuration errors
- `UNKNOWN`: Unknown errors

## Error Severity Levels

The error handler defines the following severity levels:

- `FATAL`: Unrecoverable errors that require process termination
- `ERROR`: Serious errors that might allow the process to continue
- `WARNING`: Warnings that need attention but don't stop execution
- `INFO`: Informational messages about error conditions

## Function Error Handling Patterns

### Standard Error Handling Pattern

The standard pattern for all error-prone operations is:

```lua
function do_something(arg1, arg2)
  -- Validate inputs
  error_handler.assert_type(arg1, "string", "arg1")
  
  -- Perform operation that might fail using error_handler.try
  local success, result, err = error_handler.try(function()
    return some_operation(arg1, arg2)
  end)
  
  if not success then
    logger.error("Operation failed: " .. error_handler.format_error(result), {
      operation = "do_something",
      arg1 = arg1,
      arg2 = type(arg2) -- Don't log potentially sensitive values
    })
    return nil, result -- Return the error object
  end
  
  -- Success
  return result
end
```

### Return-Based Error Handling

For functions that return results, use this pattern:

```lua
function do_something(arg1, arg2)
  -- Validate inputs
  error_handler.assert_type(arg1, "string", "arg1")
  
  -- Perform operation
  local success, result, err = error_handler.try(function()
    return some_operation(arg1, arg2)
  end)
  
  if not success then
    return nil, result -- Return the error object
  end
  
  -- Success
  return result
end
```

### Exception-Based Error Handling

For critical errors where execution cannot continue:

```lua
function critical_operation(arg1)
  -- Check preconditions
  if not arg1 then
    error_handler.throw(
      "arg1 is required", 
      error_handler.CATEGORY.VALIDATION,
      error_handler.SEVERITY.ERROR
    )
    -- Execution stops here
  end
  
  -- Continue with operation
end
```

## Best Practices

1. **Always Use error_handler**: The error_handler module is a core requirement for all code in the lust-next project. Never include fallback mechanisms for cases where it might not be available.

2. **Be Consistent**: Use the error handler consistently throughout the codebase, following the standard patterns.

3. **Prefer Return-Based Errors**: Use return-based error handling for most functions to allow callers to handle errors.

4. **Use Assertions for Validation**: Use error_handler.assert_* functions for input validation at the start of functions.

5. **Include Context**: Always include relevant contextual information with errors using the context parameter.

6. **Categorize Properly**: Use appropriate error categories and severity levels from error_handler.CATEGORY and error_handler.SEVERITY.

7. **Handle at the Right Level**: Handle errors at the level where they can be properly addressed.

8. **Log Once**: Errors should typically be logged only once, usually at the point of handling.

9. **Wrap External Errors**: Wrap errors from external libraries with additional context using error_handler.try.

10. **Document Error Behavior**: Document how a function handles or propagates errors.

11. **Don't Swallow Errors**: Don't discard errors without proper handling or logging.

12. **Use error_handler.try**: Always use error_handler.try for operations that might fail, rather than direct pcall.

## Integration with Existing Modules

### Coverage Module Example

```lua
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local logger = require("lib.tools.logging").get_logger("CoverageModule")

-- INCORRECT PATTERN (DO NOT USE)
local function parse_file_incorrect(file_path)
  local content = fs.read_file(file_path)
  if not content then
    logger.error("Failed to read file: " .. file_path)
    return nil
  end
  
  local result = pcall(function() return parse_content(content) end)
  if not result then
    logger.error("Failed to parse file: " .. file_path)
    return nil
  end
  
  return result
end

-- INCORRECT PATTERN WITH FALLBACK (DO NOT USE)
local function parse_file_incorrect_fallback(file_path)
  -- Using incorrect pattern with error_handler fallback
  if error_handler then
    -- With error_handler
    local content, err = error_handler.safe_io_operation(
      function() return fs.read_file(file_path) end,
      file_path,
      { operation = "read_file" }
    )
    
    if not content then
      return nil, err
    end
  else
    -- Fallback without error_handler (NEVER DO THIS)
    local content = fs.read_file(file_path)
    if not content then
      logger.error("Failed to read file: " .. file_path)
      return nil, "Failed to read file"
    end
  end
  
  -- More code...
}

-- CORRECT PATTERN
local function parse_file(file_path)
  -- Validate input
  error_handler.assert_not_nil(file_path, "file_path")
  
  -- Read file safely
  local content, err = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    { operation = "read_file" }
  )
  
  if not content then
    logger.error("Failed to read file: " .. error_handler.format_error(err), {
      operation = "parse_file",
      file_path = file_path
    })
    return nil, err
  end
  
  -- Parse content safely
  local success, result, parse_err = error_handler.try(function()
    return parse_content(content)
  end)
  
  if not success then
    local error_obj = error_handler.parse_error(
      "Failed to parse file content", 
      { file_path = file_path, operation = "parse_file" },
      result  -- The error from try() is in the result parameter
    )
    
    logger.error("Parse error: " .. error_handler.format_error(error_obj), {
      operation = "parse_file",
      file_path = file_path
    })
    
    return nil, error_obj
  end
  
  return result
end
```

## Migration Strategy

When migrating existing code to use the error handler:

1. Identify functions that need error handling
2. Remove any fallback code that assumes error_handler might not be available
3. Determine the appropriate error handling pattern (return-based vs exception-based)
4. Replace error strings with structured error objects
5. Add assertions for input validation
6. Wrap error-prone operations with error_handler.try
7. Use error_handler.safe_io_operation for file operations
8. Update callers to handle the new error objects
9. Ensure proper error propagation and logging

## Configuration

The error handler can be configured globally or per-module:

```lua
-- Global configuration
local error_handler = require("lib.tools.error_handler")
error_handler.configure({
  use_assertions = true,      -- Use Lua assertions for validation errors
  verbose = false,            -- Verbose error messages
  trace_errors = true,        -- Include traceback information
  log_all_errors = true,      -- Log all errors through the logging system
  exit_on_fatal = false,      -- Exit the process on fatal errors
  capture_backtraces = true,  -- Capture stack traces for errors
})

-- Configuration from global config
error_handler.configure_from_config()
```

## Conclusion

Following these error handling guidelines will lead to more robust, maintainable, and debuggable code throughout the lust-next project. The standardized approach ensures that errors are handled consistently and provides rich information for troubleshooting.