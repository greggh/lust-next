# Testing Guide for Coverage Module Repair

This document provides comprehensive guidance for testing components during the coverage module repair project.

## Purpose

The purpose of this guide is to ensure consistent, thorough testing practices throughout the coverage module repair project. It outlines test methodology, available testing functions, and best practices for writing effective tests.

## Testing Framework Overview

The lust-next project uses a behavior-driven development (BDD) testing framework that provides a descriptive syntax for organizing and running tests.

### Core Testing Functions

The following functions are available in the lust-next testing framework:

```lua
local describe, it, expect = lust.describe, lust.it, lust.expect
```

- `describe(name, function)`: Groups related tests together
- `it(name, function)`: Defines an individual test case
- `expect(value)`: Creates an assertion chain for testing values

### Test Lifecycle Functions

For test setup and teardown, use the following functions:

```lua
local before, after = lust.before, lust.after
```

- `before(function)`: Runs before each test in the current describe block
- `after(function)`: Runs after each test in the current describe block

**IMPORTANT:** The functions `before_all` and `after_all` DO NOT EXIST in lust-next. Do not use them in your tests or they will cause runtime errors.

### Running Tests

Tests are automatically executed by the test runners. There are two main ways to run tests:

1. **Individual Test Files** (during development):
   ```bash
   lua scripts/runner.lua tests/your_test_file.lua
   ```

2. **All Tests** (for comprehensive verification):
   ```bash
   lua scripts/runner.lua tests/
   ```

> **Note:** Based on our test system reorganization plan (2025-03-13), we are moving to a more standardized approach where all test running goes through the enhanced `scripts/runner.lua` utility. The older test runners in the project root (run_all_tests.lua, run-instrumentation-tests.lua, etc.) will be removed in favor of this universal approach.

No explicit function call is needed at the end of your test files:

```lua
-- Tests are run by external test runners, NOT through a function call in the test file
-- Do not add lust() or lust.run() at the end of your test files
```

## Test Structure Best Practices

### 1. Basic Test Structure

```lua
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

describe("Component Name", function()
  it("should perform expected behavior", function()
    -- Test implementation
    expect(result).to.equal(expected)
  end)
end)

-- No explicit test runner call needed
```

### 2. Test Structure with Setup/Teardown

```lua
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

describe("Component with setup/teardown", function()
  local test_context = {}
  
  before(function()
    -- Setup code that runs before each test
    test_context.resource = create_resource()
  end)
  
  after(function()
    -- Teardown code that runs after each test
    cleanup_resource(test_context.resource)
  end)
  
  it("should test something with the setup resource", function()
    expect(test_context.resource).to.exist()
    -- More test code
  end)
end)

-- No explicit test runner call needed
```

## Test Isolation and Independence

Each test should be independent and not rely on the state from previous tests. Use the following practices:

1. **Reset State**: Always reset relevant state at the beginning of tests
2. **Use Local Variables**: Don't rely on shared variables between tests
3. **Mock External Dependencies**: Use mocking to isolate components from external systems
4. **Clean Up Resources**: Always clean up resources created during tests

## Testing Coverage Module Components

### Testing Configuration

```lua
describe("Coverage configuration", function()
  it("should apply default configuration", function()
    local coverage = require("lib.coverage")
    coverage.init()
    
    -- Test default configuration values
    expect(coverage.config.enabled).to.equal(true)
    expect(coverage.config.threshold).to.equal(80)
  end)
  
  it("should override defaults with user configuration", function()
    local coverage = require("lib.coverage")
    coverage.init({
      enabled = false,
      threshold = 90
    })
    
    -- Test overridden configuration
    expect(coverage.config.enabled).to.equal(false)
    expect(coverage.config.threshold).to.equal(90)
  end)
end)
```

### Testing Instrumentation

```lua
describe("Instrumentation module", function()
  local instrumentation = require("lib.coverage.instrumentation")
  local test_file = create_test_file() -- Helper to create a temp file
  
  it("should transform source code correctly", function()
    local result = instrumentation.instrument_file(test_file)
    expect(result).to.contain("track_line")
    -- More assertions about the transformed code
  end)
  
  it("should generate valid sourcemaps", function()
    instrumentation.instrument_file(test_file)
    local sourcemap = instrumentation.get_sourcemap(test_file)
    expect(sourcemap).to.exist()
    expect(sourcemap.original_lines).to.be.a("table")
  end)
  
  after(function()
    cleanup_test_file(test_file) -- Helper to clean up temp file
  end)
end)
```

## Testing Debug Hook

```lua
describe("Debug hook", function()
  local debug_hook = require("lib.coverage.debug_hook")
  
  before(function()
    debug_hook.reset()
  end)
  
  it("should track executed lines", function()
    debug_hook.initialize_file("test_file.lua")
    debug_hook.set_line_executed("test_file.lua", 10, true)
    
    expect(debug_hook.was_line_executed("test_file.lua", 10)).to.be.truthy()
  end)
end)
```

## Testing Static Analyzer

```lua
describe("Static analyzer", function()
  local static_analyzer = require("lib.coverage.static_analyzer")
  
  it("should correctly identify executable lines", function()
    local ast, code_map = static_analyzer.parse_content("local x = 1\n-- Comment\nprint(x)")
    
    expect(static_analyzer.is_line_executable(code_map, 1)).to.be.truthy()
    expect(static_analyzer.is_line_executable(code_map, 2)).to.be.falsy()
    expect(static_analyzer.is_line_executable(code_map, 3)).to.be.truthy()
  end)
end)
```

## Error Handling in Tests

Always verify that error conditions are handled correctly:

```lua
describe("Error handling", function()
  it("should handle missing files gracefully", function()
    local result, err = instrumentation.instrument_file("non_existent_file.lua")
    expect(result).to.be.falsy()
    expect(err.message).to.contain("file not found")
    expect(err.category).to.equal("IO")
  end)
end)
```

## Test Performance Considerations

For performance-sensitive code:

```lua
describe("Performance", function()
  it("should be efficient with large files", function()
    local large_file = create_large_test_file(10000) -- Helper to create a large file
    
    local start_time = os.clock()
    instrumentation.instrument_file(large_file)
    local end_time = os.clock()
    
    expect(end_time - start_time).to.be.below(1.0) -- Should complete in under 1 second
    
    cleanup_test_file(large_file)
  end)
end)
```

## Troubleshooting Common Test Issues

### Issue: Test Failures Due to Timing

If tests fail due to timing issues, consider adding small delays or using more robust synchronization mechanisms.

### Issue: State Leakage Between Tests

Ensure each test properly cleans up its state and doesn't rely on global variables.

### Issue: Mocking External Dependencies

Use the mocking system to isolate the component under test:

```lua
local mock = require("lib.mocking.mock")

-- Mock the filesystem module
local fs_mock = mock.create(fs)
fs_mock.stub("file_exists", function() return true end)

-- Test with the mock
expect(fs_mock.file_exists("any_file.lua")).to.be.truthy()
```

## Error Handler Testing (Added 2025-03-11)

When testing error handling functionality, follow these best practices:

1. **Use Proper Error Handler Functions**:
   - Use error_handler.try instead of pcall for all operations that might fail
   - Verify error objects have the correct category and severity
   - Check that context information is included in errors
   - Test both success and failure paths
   - Verify that errors are properly propagated up the call stack

2. **Handle Non-Error Conditions Correctly**:
   - Ensure that non-error negative results (like file doesn't exist) aren't treated as errors
   - Use appropriate log levels for different types of conditions:
     - ERROR: For true error conditions
     - INFO: For informational messages about normal conditions
     - DEBUG: For detailed diagnostic information

3. **Use Assertions Correctly**:
   - Never use assertion functions from error_handler.lua
   - Always use lust-next.assert functions for assertions
   - For temporary workarounds in cases of circular dependencies, use minimal validation functions

## Assertion Usage Guidelines (Added 2025-03-11)

As we've discovered circular dependency issues between modules, follow these guidelines for assertions:

1. **Use lust-next Assertions When Possible**:
   ```lua
   local lust = require("lust-next")
   -- Use assertions from lust-next.assert
   lust.lust_next.assert.is_exact_type(value, "string", "Value must be a string")
   ```

2. **If Circular Dependencies Prevent Using lust-next**:
   - Create minimal validation functions in your module
   - Keep these functions simple and focused on validation only
   - Document that these are temporary until the assertions module is extracted

3. **Future Direction**:
   - We are planning to extract all assertions to a standalone lib/core/assertions.lua module
   - Once completed, all modules should use this assertions module directly
   - This will eliminate circular dependencies and ensure consistent assertion behavior

## Conclusion

This testing guide provides a foundation for implementing robust, consistent tests throughout the coverage module repair project. Following these practices will ensure high-quality, maintainable code with thorough test coverage.

## Documentation Status

This document was created on 2025-03-11 to improve testing methodology for the coverage module repair project.