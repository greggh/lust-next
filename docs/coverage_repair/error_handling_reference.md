# Error Handling Reference Guide

This document consolidates key information about error handling implementation across the firmo framework. It serves as a reference for implementing consistent error handling patterns.

## Test Error Handling

When testing error conditions, we have specific patterns to ensure expected errors don't cause test failures.

### 1. Using the expect_error Flag

When a test is specifically validating error behavior, add the `expect_error` flag:

```lua
it("should handle invalid input", { expect_error = true }, function()
  -- This error won't cause the test to fail
  local result, err = function_that_returns_error()
  
  -- Make assertions about the error
  expect(result).to_not.exist()
  expect(err).to.exist()
  expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
end)
```

### 2. Using the test_helper Module

For more complex error testing scenarios, use the test_helper module:

```lua
local test_helper = require("lib.tools.test_helper")

-- Capturing errors safely
local result, err = test_helper.with_error_capture(function()
  -- Any error thrown here will be captured, not cause test failure
  error("Expected error")
end)()

-- Verifying functions throw specific errors
local err = test_helper.expect_error(
  function_that_should_throw, 
  "expected error message pattern"
)
```

For comprehensive guidance on testing error conditions, see:
- [Standardized Error Handling Patterns](error_handling_patterns.md) - Complete guide to all error handling patterns
- [Coverage Error Testing Guide](coverage_error_testing_guide.md) - Specialized patterns for coverage module testing
- [Test Timeout Optimization Guide](test_timeout_optimization_guide.md) - Solutions for tests with timeout issues
- [Test Error Handling Example](../../examples/test_error_handling_example.lua) - Basic examples
- [Enhanced Error Testing Example](../../examples/enhanced_error_testing_example.lua) - Advanced patterns

## Standard Error Handling Patterns

### 1. Input Validation

```lua
function module.function_name(required_param, optional_param)
  -- Validate required parameters
  if not required_param then
    local err = error_handler.validation_error(
      "Missing required parameter",
      {
        parameter_name = "required_param",
        operation = "module.function_name"
      }
    )
    logger.warn(err.message, err.context)
    return nil, err
  end
  
  -- Validate parameter types
  if optional_param ~= nil and type(optional_param) ~= "table" then
    local err = error_handler.validation_error(
      "Optional parameter must be a table or nil",
      {
        parameter_name = "optional_param",
        provided_type = type(optional_param),
        operation = "module.function_name"
      }
    )
    logger.warn(err.message, err.context)
    return nil, err
  end
  
  -- Continue with function implementation...
end
```

### 2. I/O Operations

```lua
-- Reading files
local content, err = error_handler.safe_io_operation(
  function() return fs.read_file(file_path) end,
  file_path,
  {operation = "read_file"}
)

if not content then
  logger.error("Failed to read file", {
    file_path = file_path,
    error = err.message
  })
  return nil, err
end

-- Writing files
local success, err = error_handler.safe_io_operation(
  function() return fs.write_file(file_path, content) end,
  file_path,
  {operation = "write_file"}
)

if not success then
  logger.error("Failed to write file", {
    file_path = file_path,
    error = err.message
  })
  return nil, err
end
```

### 3. Error Propagation

```lua
-- Call another function and propagate errors
local result, err = another_function()
if not result then
  -- Add context and propagate
  logger.error("Operation failed", {
    operation = "current_function",
    error = err.message
  })
  return nil, err
end

-- Use the result
return process_result(result)
```

### 4. Function Try/Catch Pattern

```lua
local success, result, err = error_handler.try(function()
  -- Potentially risky code here
  return some_operation()
end)

if success then
  -- Important: return the actual result, not the success flag
  return result
else
  -- Log the error if needed
  logger.error("Operation failed", {
    operation = "function_name",
    error = error_handler.format_error(result), -- Note: result contains the error object on failure
    category = result.category
  })
  
  -- Return nil and the error object
  return nil, result -- Note: on failure, result contains the error object
end
```

## Error Categories

- `VALIDATION`: Parameter validation errors
- `IO`: File system and I/O errors
- `RUNTIME`: Runtime errors during execution
- `ASSERTION`: Assertion failures
- `EXTERNAL`: Errors from external dependencies
- `CONFIGURATION`: Configuration-related errors
- `TIMEOUT`: Operation timeout errors

## Severity Levels

- `FATAL`: Application cannot continue
- `ERROR`: Operation failed but application can continue
- `WARNING`: Potential issue that did not cause immediate failure
- `INFO`: Informational message about error handling

## Best Practices

1. **Always validate input parameters** at the beginning of functions
2. **Use structured error objects** with proper categorization
3. **Add detailed context** to error objects for better diagnostics
4. **Log errors** with appropriate severity levels
5. **Implement graceful fallbacks** where appropriate
6. **Use try/catch for risky operations** (especially external calls)
7. **Propagate errors with additional context** rather than absorbing them
8. **Handle all error cases** explicitly rather than assuming success

## Module-Specific Patterns

### Coverage Module

When implementing error handling in coverage components:

1. **File paths**: Always normalize and validate file paths
2. **Source code analysis**: Use try/catch for parser operations
3. **Data flow**: Validate data structures before processing
4. **Report generation**: Implement fallbacks for invalid data

### Assertions

For assertion-related error handling:

1. **Clear error messages**: Include expected and actual values
2. **Source location**: Include file and line information when available
3. **Failure isolation**: Prevent assertion failures from affecting other tests
4. **Custom formatting**: Use formatted messages for complex values

## Testing Error Handling

When testing error handling:

1. **Test input validation** with invalid parameters
2. **Test error propagation** across module boundaries
3. **Test recovery mechanisms** for critical operations
4. **Verify error objects** have proper structure and information
5. **Test edge cases** and boundary conditions