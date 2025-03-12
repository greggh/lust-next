# lust-next Test Framework Guide

## Overview

This document provides a comprehensive guide to the lust-next testing framework, detailing its features, available functions, proper usage patterns, and best practices. It serves as the definitive reference for writing and maintaining tests in the lust-next project.

## How Testing Works in lust-next

### Test File Structure

A test file in lust-next follows this general structure:

```lua
-- Basic test file structure
local lust = require("lust-next")  -- or require("../lust-next") for relative paths
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Optional lifecycle hooks
local before, after = lust.before, lust.after

describe("Component Name", function()
  -- Setup code if needed
  before(function()
    -- Setup code that runs before each test in this block
  end)

  -- Test cases
  it("should do something specific", function()
    -- Test implementation
    local result = someFunction()
    expect(result).to.equal(expectedValue)
  end)

  it("should handle edge cases", function()
    -- Another test case
    expect(someFunction("edge case")).to_not.be.nil()
  end)

  -- Cleanup code if needed
  after(function()
    -- Cleanup code that runs after each test in this block
  end)
end)

-- NO explicit lust() or lust.run() call is needed
-- Tests are run by the test runner (run_all_tests.lua)
```

### Test Execution

There are two ways to run tests in the lust-next project:

1. **Individual Test Files** (using scripts/runner.lua):
   ```bash
   lua scripts/runner.lua tests/your_test_file.lua
   ```
   This method is preferred during development when you're working on a specific component and want quick feedback.

2. **Complete Test Suite** (using run_all_tests.lua):
   ```bash
   lua run_all_tests.lua
   ```
   This method runs all tests and is ideal for comprehensive verification before commits or during CI/CD.

Both runners work by:
1. Loading each test file using `loadfile()` or `dofile()`
2. Executing the file, which registers tests with the framework
3. Collecting and reporting test results

The actual execution of tests occurs when a test file is loaded and executed, not because of an explicit call to run tests within the file. Therefore, you should never include calls to `lust()` or `lust.run()` in your test files.

## Test API Reference

### Core Testing Functions

The primary functions for defining tests:

| Function | Description |
|----------|-------------|
| `describe(name, fn)` | Creates a test group with the given name |
| `it(name, fn)` | Defines a single test case within a describe block |
| `expect(value)` | Creates an assertion chain for validating values |
| `pending(message)` | Marks a test as pending/incomplete |

### Test Lifecycle Functions

Functions for setup and teardown:

| Function | Description |
|----------|-------------|
| `before(fn)` | Runs before each test in the current describe block |
| `after(fn)` | Runs after each test in the current describe block |
| `before_each(fn)` | Alias for before() |
| `after_each(fn)` | Alias for after() |

Note: While `before_all` and `after_all` are mentioned in some documentation, they are **not implemented** in the current version of lust-next. Use `before` and `after` instead.

### Focused and Excluded Tests

Functions for selectively running tests:

| Function | Description |
|----------|-------------|
| `fdescribe(name, fn)` | Focused describe - only run this and other focused tests |
| `fit(name, fn)` | Focused test - only run this and other focused tests |
| `xdescribe(name, fn)` | Excluded describe - skip this entire group |
| `xit(name, fn)` | Excluded test - skip this test case |

### Asynchronous Testing

Functions for async tests (requires async module):

| Function | Description |
|----------|-------------|
| `async(fn)` | Wraps a function for async execution |
| `await(ms)` | Waits for the specified time in milliseconds |
| `wait_until(condition, timeout)` | Waits until a condition is true or timeout |
| `parallel_async(fns)` | Runs multiple async functions in parallel |
| `it_async(name, fn)` | Defines an asynchronous test case |

### Common Assertions

Available assertion methods:

| Assertion | Description |
|-----------|-------------|
| `expect(value).to.equal(expected)` | Checks equality |
| `expect(value).to.be(expected)` | Alias for equal |
| `expect(value).to.exist()` | Checks that value is not nil |
| `expect(value).to.be.truthy()` | Checks for truthy value (not nil or false) |
| `expect(value).to.be.falsey()` | Checks for falsy value (nil or false) |
| `expect(fn).to.fail()` | Checks if a function raises an error |
| `expect(fn).to.fail.with(message)` | Checks if function fails with specific message |
| `expect(table).to.have(item)` | Checks if item is in table |
| `expect(value).to.be.a(type)` | Checks type (e.g., "string", "number") |
| `expect(string).to.match(pattern)` | Checks string against pattern |

All assertions can be negated with `to_not` instead of `to`:

```lua
expect(value).to_not.equal(unexpected)
```

## Common Testing Patterns

### Test File Organization

```lua
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Group tests by functionality
describe("Component", function()
  -- Subgroup for specific feature
  describe("Feature", function()
    -- Test cases for this feature
    it("should handle normal input", function() end)
    it("should handle edge cases", function() end)
  end)
  
  -- Another subgroup
  describe("Another Feature", function()
    it("should work correctly", function() end)
  end)
end)
```

### Temporary File Management

```lua
local test_files = {}

-- Create temporary files for testing
before(function()
  local temp_file = "test_file.tmp"
  local file = io.open(temp_file, "w")
  file:write("Test content")
  file:close()
  table.insert(test_files, temp_file)
end)

-- Clean up files after tests
after(function()
  for _, file_path in ipairs(test_files) do
    os.remove(file_path)
  end
end)
```

### Mocking and Isolation

```lua
-- Simple function mocking
local original_function = some_module.function_name
some_module.function_name = function() return mock_result end

-- Restore after test
after(function()
  some_module.function_name = original_function
end)
```

## Best Practices

1. **Test Independence**: Each test should be independent and not rely on state from other tests
2. **Descriptive Names**: Use descriptive names for describe blocks and test cases
3. **Test One Thing**: Each test should verify one specific behavior
4. **Cover Edge Cases**: Test normal conditions and edge cases
5. **Clean Up Resources**: Always clean up any resources created during tests
6. **Avoid Global State**: Don't rely on or modify global state in tests
7. **Test Public API**: Focus on testing the public API of modules
8. **Mock External Dependencies**: Use mocks for external systems and dependencies

## Troubleshooting Common Issues

1. **Test File Not Found**: Ensure the file path is correct relative to where tests are run
2. **Module Not Found**: Check require paths; use relative paths if needed
3. **Assertion Failures**: Check that expected and actual values match exactly (including type)
4. **Hanging Tests**: Async tests might hang; check for missing callbacks or timeouts
5. **State Leakage**: Tests affecting each other usually indicate incomplete cleanup
6. **Function Not Available**: Verify that the function exists in the version you're using

## Migration Guide for Older Tests

When updating older tests to work with the current lust-next version:

1. **Check Import Path**: Make sure require("lust-next") is correct
2. **Verify Test Functions**: Use local describe, it, expect = lust.describe, lust.it, lust.expect
3. **Use Local Variables**: Don't rely on global state
4. **Remove Direct Run Calls**: Remove any calls to lust() or lust.run()
5. **Check Lifecycle Functions**: Use before/after instead of before_all/after_all
6. **Update Assertions**: Make sure assertions use the current syntax

## Specific Module Testing Guides

### Testing Coverage Module

```lua
describe("Coverage Module", function()
  -- Reset before each test to avoid state leakage
  before(function()
    coverage.reset()
  end)
  
  it("should track executed lines", function()
    coverage.start()
    -- Code being tested
    coverage.stop()
    
    local report_data = coverage.get_report_data()
    -- Assertions about coverage data
  end)
end)
```

### Testing Instrumentation

```lua
describe("Instrumentation", function()
  it("should instrument code correctly", function()
    local instrumentation = require("lib.coverage.instrumentation")
    
    -- Create test file
    local test_file = create_test_file("local x = 1")
    
    -- Instrument it
    local result = instrumentation.instrument_file(test_file)
    
    -- Verify instrumentation added tracking code
    expect(result).to.contain("track_line")
    
    -- Clean up
    cleanup_test_file(test_file)
  end)
end)
```

## Test Runner Usage

### Individual Test Files (scripts/runner.lua)

To run a specific test file:

```bash
lua scripts/runner.lua tests/your_test_file.lua
```

Options for runner.lua:
| Option | Description |
|--------|-------------|
| `--json` | Output results in JSON format |
| `--verbose` | Show verbose output |

### Full Test Suite (run_all_tests.lua)

To run all tests:

```bash
lua run_all_tests.lua
```

To run specific test files with the full runner:

```bash
lua run_all_tests.lua tests/specific_test.lua
```

Options for run_all_tests.lua:
| Option | Description |
|--------|-------------|
| `--verbose` or `-v` | Enable verbose output |
| `--memory` or `-m` | Track memory usage |
| `--performance` or `-p` | Show performance statistics |
| `--coverage` or `-c` | Enable coverage analysis |
| `--quality` or `-q` | Enable quality validation |
| `--filter PATTERN` | Only run tests matching pattern |