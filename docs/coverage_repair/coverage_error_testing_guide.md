# Coverage Module Error Testing Guide

## Overview

This guide provides specific patterns and approaches for testing error conditions in the Firmo coverage module. The coverage module has several components with unique error handling needs, including static analysis, instrumentation, and runtime coverage tracking.

## Coverage Module Components

The coverage module consists of several key components, each with specific error handling requirements:

1. **Coverage Controller** (`lib/coverage/init.lua`)
   - Manages coverage lifecycle (start, stop, reset)
   - Handles file tracking and reporting

2. **Static Analyzer** (`lib/coverage/static_analyzer.lua`)
   - Parses Lua code for analysis
   - Identifies executable lines and blocks
   - Requires error handling for malformed or invalid code

3. **Debug Hook** (`lib/coverage/debug_hook.lua`)
   - Handles runtime execution tracking
   - Tracks line coverage during test execution

4. **Instrumentation** (`lib/coverage/instrumentation.lua`)
   - Transforms Lua code to track coverage
   - Hooks into module loading system

5. **Patchup** (`lib/coverage/patchup.lua`)
   - Corrects coverage data post-execution
   - Handles discrepancies between static and runtime analysis

## Component-Specific Error Testing Patterns

### 1. Coverage Controller (init.lua)

**Common Error Scenarios**:
- Invalid configuration
- Missing files
- Files with syntax errors
- Invalid report formats

**Testing Pattern**:

```lua
-- Testing invalid configuration
it("should handle invalid configuration", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
        return coverage.init({
            enabled = "not_a_boolean"  -- Invalid: should be true/false
        })
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("configuration")
end)

-- Testing missing files
it("should handle non-existent files gracefully", { expect_error = true }, function()
    -- Initialize coverage
    coverage.init({ enabled = true })
    coverage.start()
    
    -- Try to track a non-existent file
    local result, err = test_helper.with_error_capture(function()
        return coverage.track_file("/path/to/non_existent_file.lua")
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("file")
    
    -- Stop coverage
    coverage.stop()
end)
```

### 2. Static Analyzer (static_analyzer.lua)

**Common Error Scenarios**:
- Syntax errors in code
- Unterminated strings or comments
- Malformed block structures
- Missing source code

**Testing Pattern**:

```lua
-- Testing malformed code
it("should handle syntax errors gracefully", { expect_error = true }, function()
    local malformed_code = [[
        function missing_end(
        local x = "unclosed string
        if true then
    ]]
    
    local ast, code_map, err = test_helper.with_error_capture(function()
        return static_analyzer.parse_content(malformed_code, "malformed_code")
    end)()
    
    expect(ast).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
end)

-- Testing missing code map
it("should handle missing code map", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
        return static_analyzer.is_line_executable(nil, 1)
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("code_map")
end)
```

### 3. Debug Hook (debug_hook.lua)

**Common Error Scenarios**:
- Invalid hook configuration
- Hook collision with other modules
- Memory/performance issues with large files

**Testing Pattern**:

```lua
-- Testing invalid hook configuration
it("should handle invalid hook configuration", { expect_error = true }, function()
    local debug_hook = require("lib.coverage.debug_hook")
    
    local result, err = test_helper.with_error_capture(function()
        return debug_hook.init({
            -- Missing required configuration
            hook_type = nil
        })
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("configuration")
end)

-- Testing hook collision
it("should handle hook collision", { expect_error = true }, function()
    local debug_hook = require("lib.coverage.debug_hook")
    
    -- Set up a fake existing hook
    local original_hook = debug.gethook()
    debug.sethook(function() end, "c")
    
    -- Try to initialize with strict_mode = true
    local result, err = test_helper.with_error_capture(function()
        return debug_hook.init({
            strict_mode = true  -- Will fail if hooks already exist
        })
    end)()
    
    -- Restore original hook
    debug.sethook(original_hook)
    
    -- May either fail or handle gracefully depending on implementation
    if result == nil then
        expect(err).to.exist()
        expect(err.message).to.match("hook")
    else
        -- Successful but should warn about existing hook
        expect(result.warnings).to.exist()
    end
end)
```

### 4. Instrumentation (instrumentation.lua)

**Common Error Scenarios**:
- Syntax errors in instrumented code
- Loader hooks not working
- Transformation errors
- Module require errors

**Testing Pattern**:

```lua
-- Testing syntax errors in instrumentation
it("should handle syntax errors in instrumentation", { expect_error = true }, function()
    local instrumentation = require("lib.coverage.instrumentation")
    
    -- Create malformed code that would break instrumentation
    local malformed_code = [[
        local x = function() 
            return "test"
        -- Missing end
    ]]
    
    local result, err = test_helper.with_error_capture(function()
        return instrumentation.instrument_code(malformed_code, "test")
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("transform")
end)

-- Testing loader hook errors
it("should handle loader hook errors", { expect_error = true }, function()
    local instrumentation = require("lib.coverage.instrumentation")
    
    -- Mock package.loaders to simulate error
    local original_loaders = package.loaders
    package.loaders = "not_a_table"
    
    local result, err = test_helper.with_error_capture(function()
        return instrumentation.hook_loaders()
    end)()
    
    -- Restore original loaders
    package.loaders = original_loaders
    
    -- Check for proper error handling
    expect(err).to.exist()
    expect(err.message).to.match("loader")
end)
```

### 5. Patchup (patchup.lua)

**Common Error Scenarios**:
- Inconsistent coverage data
- Missing coverage data
- Invalid file references

**Testing Pattern**:

```lua
-- Testing missing coverage data
it("should handle missing coverage data", { expect_error = true }, function()
    local patchup = require("lib.coverage.patchup")
    
    local result, err = test_helper.with_error_capture(function()
        return patchup.fix_coverage_data(nil)
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("coverage data")
end)

-- Testing invalid file references
it("should handle invalid file references in coverage data", { expect_error = true }, function()
    local patchup = require("lib.coverage.patchup")
    
    -- Create coverage data with invalid file reference
    local invalid_data = {
        files = {
            ["/non/existent/file.lua"] = {
                lines = { [1] = true }
            }
        }
    }
    
    local result, err = test_helper.with_error_capture(function()
        return patchup.fix_coverage_data(invalid_data)
    end)()
    
    -- May either return patched data or error based on implementation
    if result then
        -- Should have warnings about missing file
        expect(result.warnings).to.exist()
    else
        expect(err).to.exist()
        expect(err.message).to.match("file")
    end
end)
```

## Creating Robust Coverage Module Tests

When creating tests for the coverage module, follow these steps to ensure robust error handling:

### 1. Identify Error Boundaries

Identify where errors might occur in the component you're testing:

```lua
-- Major error boundaries in coverage tracking
local error_boundaries = {
    "initialization", -- Coverage module initialization
    "file_loading",   -- Loading/accessing source files
    "tracking",       -- Coverage tracking during execution
    "reporting",      -- Generating reports from coverage data
    "instrumentation" -- Code transformation for coverage
}

for _, boundary in ipairs(error_boundaries) do
    it("should handle errors in " .. boundary, { expect_error = true }, function()
        -- Test specific error condition based on the boundary
        -- ...
    end)
end
```

### 2. Use Temporary Resources

Create temporary test files that can be easily managed and cleaned up:

```lua
-- For coverage tests
local test_files = {}

-- Create a test file with specific code
local function create_test_file(content)
    local file_path, create_err = temp_file.create_with_content(content, "lua")
    expect(create_err).to_not.exist("Failed to create test file: " .. tostring(create_err))
    table.insert(test_files, file_path)
    return file_path
end

-- Clean up after tests
after(function()
    for _, file_path in ipairs(test_files) do
        pcall(function() temp_file.remove(file_path) end)
    end
end)
```

### 3. Test Complete Coverage Lifecycle

Test all phases of the coverage lifecycle with error handling:

```lua
it("should handle errors throughout coverage lifecycle", { expect_error = true }, function()
    -- Create a deliberately invalid test file
    local file_path = create_test_file("function invalid_syntax(")
    
    -- 1. Init with error handling
    local init_result, init_err = test_helper.with_error_capture(function()
        return coverage.init({ enabled = true })
    end)()
    
    expect(init_err).to_not.exist("Failed to initialize coverage: " .. tostring(init_err))
    
    -- 2. Start with error handling
    local start_result, start_err = test_helper.with_error_capture(function()
        return coverage.start()
    end)()
    
    expect(start_err).to_not.exist("Failed to start coverage: " .. tostring(start_err))
    
    -- 3. Track file with error handling (should fail due to syntax error)
    local track_result, track_err = test_helper.with_error_capture(function()
        return coverage.track_file(file_path)
    end)()
    
    -- This should error due to the invalid syntax
    expect(track_result).to_not.exist()
    expect(track_err).to.exist()
    expect(track_err.message).to.match("syntax")
    
    -- 4. Stop with error handling
    local stop_result, stop_err = test_helper.with_error_capture(function()
        return coverage.stop()
    end)()
    
    expect(stop_err).to_not.exist("Failed to stop coverage: " .. tostring(stop_err))
    
    -- 5. Get report with error handling
    local report_result, report_err = test_helper.with_error_capture(function()
        return coverage.get_report_data()
    end)()
    
    expect(report_err).to_not.exist("Failed to get report: " .. tostring(report_err))
    expect(report_result).to.exist()
end)
```

### 4. Test Error Recovery

Test that the system can recover from errors:

```lua
it("should recover from errors", function()
    -- First cause an error
    local error_file = create_test_file("function invalid_syntax(")
    
    -- Try to track the invalid file (should fail)
    local track_result, track_err = test_helper.with_error_capture(function()
        return coverage.track_file(error_file)
    end)()
    
    -- Now try with a valid file (should succeed)
    local valid_file = create_test_file("function valid_function() return true end")
    
    local valid_result, valid_err = test_helper.with_error_capture(function()
        return coverage.track_file(valid_file)
    end)()
    
    expect(valid_err).to_not.exist("Failed to track valid file after error: " .. tostring(valid_err))
    expect(valid_result).to.exist()
end)
```

### 5. Test Resource Limits

Test how the system handles resource constraints:

```lua
it("should handle large files gracefully", { expect_error = true }, function()
    -- Create a very large file
    local large_content = string.rep("local x = 1\n", 10000)
    local large_file = create_test_file(large_content)
    
    -- Time the operation to check for performance issues
    local start_time = os.clock()
    
    local result, err = test_helper.with_error_capture(function()
        return coverage.track_file(large_file)
    end)()
    
    local elapsed = os.clock() - start_time
    
    -- Should either succeed or fail gracefully with a clear error
    if result == nil then
        expect(err).to.exist()
        expect(err.message).to.match("memory") -- Should mention memory or size
    else
        expect(elapsed).to.be_less_than(5) -- Should complete in reasonable time
    end
end)
```

## Testing Coverage Module Integration

Test how different coverage components work together:

```lua
it("should handle errors across component boundaries", { expect_error = true }, function()
    -- Set up test with error-prone conditions
    local debug_hook = require("lib.coverage.debug_hook")
    local static_analyzer = require("lib.coverage.static_analyzer")
    
    -- Mock components to simulate errors
    local orig_parse = static_analyzer.parse_content
    static_analyzer.parse_content = function(content, name)
        if string.match(content, "trigger_error") then
            return nil, error_handler.syntax_error(
                "Simulated syntax error",
                {file = name, line = 1, operation = "parse"}
            )
        end
        return orig_parse(content, name)
    end
    
    -- Create a file that will trigger the error
    local file_path = create_test_file("local trigger_error = true")
    
    -- Try to track the file with coverage
    local result, err = test_helper.with_error_capture(function()
        return coverage.track_file(file_path)
    end)()
    
    -- Restore original function
    static_analyzer.parse_content = orig_parse
    
    -- Should handle the error from the static analyzer
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
end)
```

## Special Considerations for Coverage Module

### 1. Handling Line Execution vs. Coverage Distinction

```lua
it("should distinguish between execution and coverage", function()
    -- Create a test file with both executed and covered lines
    local test_code = [[
        local function test()
            local a = 1       -- This line is executed
            if a > 0 then     -- This line is executed and covered (condition is tested)
                return true   -- This line is executed
            else
                return false  -- This line is not executed
            end
        end
        return test()
    ]]
    
    local file_path = create_test_file(test_code)
    
    -- Initialize and start coverage
    coverage.init({ enabled = true })
    coverage.reset()
    coverage.start()
    
    -- Load and execute with error handling
    local load_result, load_err = test_helper.with_error_capture(function()
        return loadfile(file_path)
    end)()
    
    expect(load_err).to_not.exist("Failed to load file: " .. tostring(load_err))
    
    local exec_result, exec_err = pcall(load_result)
    expect(exec_result).to.be_truthy("Failed to execute file: " .. tostring(exec_err))
    
    coverage.stop()
    
    -- Verify execution vs. coverage distinction
    local report_data = coverage.get_report_data()
    
    local normalized_path = fs.normalize_path(file_path)
    local file_data = report_data.files[normalized_path]
    
    expect(file_data).to.exist()
    expect(file_data.lines[2]).to.exist() -- Line with 'local a = 1'
    expect(file_data.lines[3]).to.exist() -- Line with if condition
    expect(file_data.lines[4]).to.exist() -- Line with return true
    expect(file_data.lines[6]).to_not.exist() -- Line with return false (not executed)
end)
```

### 2. Handling Instrumentation vs. Debug Hook Approaches

```lua
it("should handle errors in both instrumentation and debug hook modes", { expect_error = true }, function()
    -- Create a test file
    local file_path = create_test_file("local x = 1")
    
    -- Test debug hook mode
    coverage.init({ enabled = true, use_instrumentation = false })
    coverage.reset()
    coverage.start()
    
    local hook_result, hook_err = test_helper.with_error_capture(function()
        return coverage.track_file(file_path)
    end)()
    
    coverage.stop()
    
    expect(hook_err).to_not.exist("Failed in debug hook mode: " .. tostring(hook_err))
    
    -- Test instrumentation mode
    coverage.init({ enabled = true, use_instrumentation = true })
    coverage.reset()
    coverage.start()
    
    local instr_result, instr_err = test_helper.with_error_capture(function()
        return coverage.track_file(file_path)
    end)()
    
    coverage.stop()
    
    -- Check the appropriate outcome based on implementation
    if instr_result == nil then
        -- If instrumentation is not supported, it should provide a clear error
        expect(instr_err).to.exist()
        expect(instr_err.message).to.match("instrumentation")
    else
        expect(instr_err).to_not.exist("Failed in instrumentation mode: " .. tostring(instr_err))
    end
end)
```

## Conclusion

Testing error conditions in the coverage module requires careful consideration of various components, their interactions, and potential failure modes. By following these patterns and creating comprehensive tests that handle errors appropriately, you can ensure that the coverage module remains robust and maintainable.

Remember that thorough error testing is essential for components like coverage tracking, which operate throughout the test lifecycle and can impact overall test reliability. Proper error handling not only improves user experience but also simplifies debugging and maintenance.