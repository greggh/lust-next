# Standardized Error Handling Patterns

## Overview

This document outlines the standardized error handling patterns implemented across the Firmo codebase. These patterns ensure consistent handling of errors, proper resource cleanup, and detailed error reporting. Following these patterns will make tests more resilient and improve debugging capabilities.

## Core Error Handling Patterns

### 1. Logger Initialization with Error Handling

This pattern ensures that logging capabilities are available even if the logging module fails to load.

```lua
-- Initialize logger with error handling
local logging, logger
local logger_init_success, logger_init_error = pcall(function()
    logger = logging.get_logger("module_name")
    return true
end)

if not logger_init_success then
    print("Warning: Failed to initialize logger: " .. tostring(logger_init_error))
    -- Create a minimal logger as fallback
    logger = {
        debug = function() end,
        info = function() end,
        warn = function(msg) print("WARN: " .. msg) end,
        error = function(msg) print("ERROR: " .. msg) end
    }
end
```

**When to use**: In any test file that requires logging capabilities. This pattern ensures that tests can continue even if the logging module isn't available or fails to initialize.

### 2. Function Call Wrapping with test_helper.with_error_capture()

This pattern captures errors from function calls without crashing the test and returns them in a structured way for inspection.

```lua
local result, err = test_helper.with_error_capture(function()
    return some_function_that_might_error(arg1, arg2)
end)()

expect(err).to_not.exist("Failed to execute function: " .. tostring(err))
expect(result).to.exist()
```

**When to use**: For any function call that might throw an error, especially when:
- Testing API function calls
- Loading modules
- Performing file operations
- Executing operations that depend on external resources

### 3. Resource Creation and Cleanup with Error Handling

This pattern ensures that resources like temporary files are properly tracked and cleaned up even if tests fail.

```lua
-- For test setup
local test_resources = {}

before(function()
    -- Create resources with error handling
    local resource, create_err = test_helper.with_error_capture(function()
        return create_test_resource(args)
    end)()
    
    expect(create_err).to_not.exist("Failed to create test resource: " .. tostring(create_err))
    expect(resource).to.exist()
    
    -- Track the resource for cleanup
    table.insert(test_resources, resource)
end)

after(function()
    -- Clean up resources with error handling
    for _, resource in ipairs(test_resources) do
        local success, err = pcall(function()
            return cleanup_resource(resource)
        end)
        
        if not success then
            if logger then
                logger.warn("Failed to clean up resource: " .. tostring(err))
            end
        end
    end
    -- Clear the resources list
    test_resources = {}
end)
```

**When to use**: When tests require temporary resources like:
- Test files
- Mock objects that need cleanup
- Temporary directories
- Any stateful resources that should be reset after tests

### 4. Error Test Pattern for Testing Error Conditions

This pattern tests functions that are expected to fail, ensuring they fail correctly and with the right error information.

```lua
it("should handle invalid input", { expect_error = true }, function()
    -- Try an operation expected to fail
    local result, err = test_helper.with_error_capture(function()
        return function_that_should_error(invalid_input)
    end)()
    
    -- Verify proper error handling
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("expected pattern")
    
    -- For functions that might return false instead of nil+error
    if result ~= nil then
        expect(result).to.equal(false)
    else
        expect(err).to.exist()
        expect(err.category).to.exist()
    end
end)
```

**When to use**: When testing error conditions such as:
- Invalid parameters
- Missing resources
- Malformed input
- Resource access errors
- Any operation that should produce an error

## Specific Patterns for Common Scenarios

### File Operations with Error Handling

```lua
-- Opening and reading files
local file_content, read_err = test_helper.with_error_capture(function()
    return fs.read_file(file_path)
end)()

expect(read_err).to_not.exist("Failed to read file: " .. tostring(read_err))
expect(file_content).to.exist()

-- Writing files
local write_success, write_err = test_helper.with_error_capture(function()
    return fs.write_file(file_path, content)
end)()

expect(write_err).to_not.exist("Failed to write file: " .. tostring(write_err))
expect(write_success).to.be_truthy()
```

### Temporary File Management

```lua
-- Create a temporary file with error handling
local file_path, create_error = temp_file.create_with_content(content, "lua")
expect(create_error).to_not.exist("Failed to create test file: " .. tostring(create_error))
expect(file_path).to.exist()

-- Track the file for cleanup
table.insert(test_files, file_path)

-- Later cleanup in after() hook
for _, file_path in ipairs(test_files) do
    local success, err = pcall(function()
        return temp_file.remove(file_path)
    end)
    
    if not success then
        logger.warn("Failed to remove test file: " .. tostring(err))
    end
end
```

### Module Loading with Error Handling

```lua
-- Load a module with error handling
local module, load_error = test_helper.with_error_capture(function()
    return require("lib.module_name")
end)()

expect(load_error).to_not.exist("Failed to load module: " .. tostring(load_error))
expect(module).to.exist()
```

### Configuration Setting with Error Handling

```lua
-- Set configuration with error handling
if central_config and central_config.set then
    local config_result, config_error = test_helper.with_error_capture(function()
        return central_config.set("section", {
            key1 = value1,
            key2 = value2
        })
    end)()
    
    expect(config_error).to_not.exist("Failed to set configuration: " .. tostring(config_error))
}
```

### Testing Multiple Return Values

```lua
-- Function returning multiple values
local results, err = test_helper.with_error_capture(function()
    return function_with_multiple_returns()
end)()

expect(err).to_not.exist("Function failed: " .. tostring(err))
expect(results).to.be.a("table")
expect(results[1]).to.exist()  -- First return value
expect(results[2]).to.exist()  -- Second return value
```

## Best Practices

### 1. Error Message Construction

Error messages should be detailed and include context:

```lua
expect(result).to.exist("Failed to " .. operation .. " on " .. resource .. ": " .. tostring(err))
```

### 2. Conditional Functionality Testing

Test for feature availability before using:

```lua
if module.feature_name then
    -- Test the feature
    local result, err = test_helper.with_error_capture(function()
        return module.feature_name(args)
    end)()
    
    expect(err).to_not.exist()
    expect(result).to.exist()
else
    if logger then
        logger.warn("Test skipped - missing functionality", {
            missing_function = "module.feature_name",
            test = "should do something"
        })
    end
    firmo.pending("Feature not available")
end
```

### 3. Defensive Error Checking

Handle multiple error return patterns:

```lua
if result == nil then
    -- nil, error pattern
    expect(err).to.exist()
    expect(err.message).to.match(pattern)
elseif result == false then
    -- false pattern (no error object)
    expect(result).to.equal(false)
else
    -- No error occurred, check the result
    expect(result).to.exist()
end
```

### 4. Test Setup Verification

Verify that test prerequisites are met:

```lua
-- Verify file exists before testing
local file_exists, file_exists_error = test_helper.with_error_capture(function()
    return fs.file_exists(file_path)
end)()

expect(file_exists_error).to_not.exist("Error checking if file exists: " .. tostring(file_exists_error))
expect(file_exists).to.be_truthy("Test file does not exist: " .. file_path)
```

### 5. Resource Existence Validation

Always check if resources exist before using them:

```lua
-- Safe resource checking
if not resource then
    expect.fail("Required resource is missing")
    return
end

-- Proceed with test
```

## Error Handling Implementation Checklist

When implementing error handling in a test file, ensure you cover these aspects:

1. **Module Loading**
   - [ ] Add error handling for all module require statements
   - [ ] Create fallback behavior for missing modules where appropriate
   - [ ] Verify module existence before testing features

2. **Test Resources**
   - [ ] Add error handling for resource creation
   - [ ] Track resources for proper cleanup
   - [ ] Implement cleanup in after() blocks with error handling

3. **Function Calls**
   - [ ] Wrap all API/function calls with test_helper.with_error_capture()
   - [ ] Add detailed error messages with context
   - [ ] Check return values before using them

4. **Parameter Validation**
   - [ ] Add input parameter validation to functions
   - [ ] Provide detailed error messages for invalid inputs
   - [ ] Add error handling tests for input validation

5. **Error Handling Tests**
   - [ ] Add specific test cases for error conditions
   - [ ] Use the expect_error flag for tests that expect errors
   - [ ] Test different error return patterns (nil+error, false, etc.)

6. **Logging**
   - [ ] Add error handling for logger initialization
   - [ ] Create fallback loggers for when logging fails
   - [ ] Add conditional logging based on logger availability

7. **Cleanup**
   - [ ] Ensure all resources are tracked for cleanup
   - [ ] Add error handling in cleanup code
   - [ ] Implement cleanup that works even if tests fail

## Complete Example

Here's a complete example that demonstrates all the patterns together:

```lua
-- Test file for module XYZ
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Initialize logger with error handling
local logging, logger
local logger_init_success, logger_init_error = pcall(function()
    local log_module = require("lib.tools.logging")
    logging = log_module
    logger = logging.get_logger("test.module_xyz")
    return true
end)

if not logger_init_success then
    print("Warning: Failed to initialize logger: " .. tostring(logger_init_error))
    -- Create a minimal logger as fallback
    logger = {
        debug = function() end,
        info = function() end,
        warn = function(msg) print("WARN: " .. msg) end,
        error = function(msg) print("ERROR: " .. msg) end
    }
end

describe("Module XYZ", function()
    -- Test resources
    local test_files = {}
    
    -- Setup
    before(function()
        -- Load dependencies with error handling
        local fs, fs_error = test_helper.with_error_capture(function()
            return require("lib.tools.filesystem")
        end)()
        
        expect(fs_error).to_not.exist("Failed to load filesystem module: " .. tostring(fs_error))
        
        -- Create test file with error handling
        local file_path, create_error = test_helper.with_error_capture(function()
            return create_test_file("test_content", "lua")
        end)()
        
        expect(create_error).to_not.exist("Failed to create test file: " .. tostring(create_error))
        expect(file_path).to.exist()
        
        -- Track for cleanup
        table.insert(test_files, file_path)
    end)
    
    -- Teardown
    after(function()
        -- Cleanup resources with error handling
        for _, file_path in ipairs(test_files) do
            local success, err = pcall(function()
                return fs.delete_file(file_path)
            end)
            
            if not success then
                if logger then
                    logger.warn("Failed to remove test file", {
                        file_path = file_path,
                        error = tostring(err)
                    })
                end
            end
        end
        
        -- Clear the resources list
        test_files = {}
    end)
    
    -- Basic functionality test
    it("should perform core functionality", function()
        -- Load the module with error handling
        local xyz, load_error = test_helper.with_error_capture(function()
            return require("lib.xyz")
        end)()
        
        expect(load_error).to_not.exist("Failed to load XYZ module: " .. tostring(load_error))
        expect(xyz).to.exist()
        
        -- Execute functionality with error handling
        local result, exec_error = test_helper.with_error_capture(function()
            return xyz.process(test_files[1])
        end)()
        
        expect(exec_error).to_not.exist("Failed to process file: " .. tostring(exec_error))
        expect(result).to.exist()
        expect(result.status).to.equal("success")
    end)
    
    -- Error handling test
    it("should handle invalid input", { expect_error = true }, function()
        -- Load the module with error handling
        local xyz, load_error = test_helper.with_error_capture(function()
            return require("lib.xyz")
        end)()
        
        expect(load_error).to_not.exist("Failed to load XYZ module: " .. tostring(load_error))
        
        -- Try invalid operation
        local result, err = test_helper.with_error_capture(function()
            return xyz.process(nil)  -- Invalid: nil instead of file path
        end)()
        
        -- Verify proper error handling
        expect(result).to_not.exist()
        expect(err).to.exist()
        expect(err.message).to.match("invalid input")
    end)
end)
```

## Conclusion

Following these standardized error handling patterns ensures consistent and robust test behavior across the codebase. These patterns improve test reliability, simplify debugging, and ensure proper resource management even when errors occur.

Remember that well-handled errors lead to more maintainable and robust code. Take the time to implement these patterns consistently in all test files.